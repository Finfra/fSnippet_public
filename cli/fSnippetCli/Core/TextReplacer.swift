import ApplicationServices
import Cocoa
import Foundation

// MARK: - CGEvent 객체 풀링 시스템

/// CGEvent 객체 풀 - 메모리 효율성 향상
class CGEventPool {
    private let queue = DispatchQueue(label: "cgevent.pool", attributes: .concurrent)
    private var backspaceEventPool: [CGEvent] = []
    private var cmdEventPool: [CGEvent] = []
    private var vEventPool: [CGEvent] = []
    private let maxPoolSize = 10

    func getBackspaceEvent(keyDown: Bool) -> CGEvent? {
        return queue.sync {
            if let reusableEvent = backspaceEventPool.popLast() {
                // 기존 이벤트 재구성
                configureBackspaceEvent(reusableEvent, keyDown: keyDown)
                return reusableEvent
            } else {
                // 새 이벤트 생성
                return CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: keyDown)
            }
        }
    }

    func getCmdEvent(keyDown: Bool) -> CGEvent? {
        return queue.sync {
            if let reusableEvent = cmdEventPool.popLast() {
                configureCmdEvent(reusableEvent, keyDown: keyDown)
                return reusableEvent
            } else {
                return CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: keyDown)
            }
        }
    }

    func getVEvent(keyDown: Bool) -> CGEvent? {
        return queue.sync {
            if let reusableEvent = vEventPool.popLast() {
                configureVEvent(reusableEvent, keyDown: keyDown)
                return reusableEvent
            } else {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: keyDown)
                event?.flags = .maskCommand
                return event
            }
        }
    }

    func returnBackspaceEvent(_ event: CGEvent) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.backspaceEventPool.count < self.maxPoolSize else { return }
            self.backspaceEventPool.append(event)
        }
    }

    func returnCmdEvent(_ event: CGEvent) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.cmdEventPool.count < self.maxPoolSize else { return }
            self.cmdEventPool.append(event)
        }
    }

    func returnVEvent(_ event: CGEvent) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.vEventPool.count < self.maxPoolSize else { return }
            self.vEventPool.append(event)
        }
    }

    private func configureBackspaceEvent(_ event: CGEvent, keyDown: Bool) {
        event.setIntegerValueField(.keyboardEventKeycode, value: 51)
        event.type = keyDown ? .keyDown : .keyUp
        event.flags = []
    }

    private func configureCmdEvent(_ event: CGEvent, keyDown: Bool) {
        event.setIntegerValueField(.keyboardEventKeycode, value: 55)
        event.type = keyDown ? .keyDown : .keyUp
        event.flags = []
    }

    private func configureVEvent(_ event: CGEvent, keyDown: Bool) {
        event.setIntegerValueField(.keyboardEventKeycode, value: 9)
        event.type = keyDown ? .keyDown : .keyUp
        event.flags = .maskCommand
    }
}

// MARK: - Delegate Protocol

protocol TextReplacerDelegate: AnyObject {
    // Issue 568_1: Event Tap Control for Shortcuts
    func requestEventMonitoringSuspension()
    func requestEventMonitoringResumption()
    // Issue797: Placeholder 창 표시 시 replacement 상태 일시 해제/복원
    func requestReplacementSuspension()
    func requestReplacementResumption()
}

/// 완전 동기식 텍스트 대체 시스템 (메모리 최적화)
class TextReplacer: TextReplacerProtocol {

    // MARK: - Properties

    static let shared = TextReplacer()

    // ✅ Delegate for Coordinator Interaction
    weak var delegate: TextReplacerDelegate?

    private let pasteboard = NSPasteboard.general
    private let eventPool = CGEventPool()  // CGEvent 객체 풀
    private let placeholderWindow = PlaceholderInputWindow()  // 새로운 플레이스홀더 시스템

    // Issue793: 클립보드 조작 로직 분리
    private lazy var clipboardHandler = ClipboardReplacementHandler(eventPool: eventPool)

    // ✅ 비동기 처리를 위한 전용 큐 (User Interactive QoS)
    private let workQueue = DispatchQueue(label: "com.fsnippet.textReplacer", qos: .userInteractive)

    // MARK: - Lifecycle

    private init() {
    }

    // 동기 처리용 상태 추적 (Legacy & Async 통계)
    private var operationCount = 0
    private var lastError: TextReplacerError?

    deinit {
    }

    // MARK: - Public API

    /// 비동기식 텍스트 대체 (메인 API) - 플레이스홀더 처리 포함
    /// - Parameters:
    ///   - abbreviation: 삭제할 약어 (또는 길이만큼의 더미 문자열)
    ///   - snippetContent: 삽입할 스니펫 내용
    ///   - referenceFrame: 팝업 위치 기준 프레임 (플레이스홀더 창 위치용)
    ///   - snippetPath: 스니펫 파일 경로 (상대 경로 해석용)
    ///   - completion: 완료 콜백 (성공 여부, 에러)
    func replaceTextAsync(
        abbreviation: String,
        with snippetContent: String,
        referenceFrame: NSRect? = nil,
        snippetPath: String? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        operationCount += 1
        lastError = nil

        logV("🖊️ [Async] 텍스트 대체 요청 시작 - 원본 길이: \(snippetContent.count)")

        // 1. 입력 검증
        if snippetContent.isEmpty {
            let error = TextReplacerError.invalidInput("Snippet content is empty")
            lastError = error
            logE("🖊️ [Async] 입력 검증 실패: Snippet content is empty")
            completion(false, error)
            return
        }

        // 2. 접근성 권한 확인
        guard isAccessibilityPermissionGranted() else {
            let error = TextReplacerError.accessibilityPermissionDenied
            lastError = error
            completion(false, error)
            return
        }

        // 3. 플레이스홀더 검사 및 처리
        if containsPlaceholders(snippetContent) {
            logV("🖊️ [Async] 플레이스홀더 발견 - 프로세스 위임")
            processPlaceholders(
                abbreviation: abbreviation,
                content: snippetContent,
                referenceFrame: referenceFrame,
                snippetPath: snippetPath,
                completion: completion
            )
            return
        }

        // 4. 일반 비동기 텍스트 대체 (Background Queue)
        // Main Thread를 차단하지 않기 위해 작업 큐에서 실행
        workQueue.async { [weak self] in
            guard let self = self else { return }

            logV("🖊️ [Async] 일반 텍스트 대체 작업 시작 (Background)")

            let deleteCount = abbreviation.count

            // 동기 메서드 재사용 (이제 백그라운드에서 실행됨)
            let success = self.performSyncTextReplacement(
                deleteCount: deleteCount,
                insertText: snippetContent,
                snippetPath: snippetPath
            )

            if success {
                logV("🖊️ [Async] 텍스트 대체 성공")
            } else {
                logE("🖊️ [Async] 텍스트 대체 실패")
            }

            // 완료 콜백은 Main Thread에서 호출 (UI 업데이트 안전성 보장)
            DispatchQueue.main.async {
                completion(success, self.lastError)
            }
        }
    }

    /// 동기식 텍스트 대체 (Legacy Support) - 내부적으로 비동기 로직 호출하고 대기
    @discardableResult
    func replaceTextSync(
        abbreviation: String, with snippetContent: String, referenceFrame: NSRect? = nil,
        snippetPath: String? = nil
    ) -> Bool {
        // 하위 호환성을 위해 세마포어를 사용하여 비동기 작업을 동기로 래핑
        // ⚠️ 주의: 메인 스레드에서 호출 시 데드락 위험이 있으므로 가능한 replaceTextAsync 사용 권장
        assert(!Thread.isMainThread, "replaceTextSync는 메인 스레드에서 호출 불가 - 데드락 위험. replaceTextAsync 사용할 것.")

        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        replaceTextAsync(
            abbreviation: abbreviation,
            with: snippetContent,
            referenceFrame: referenceFrame,
            snippetPath: snippetPath
        ) { success, _ in
            result = success
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 10.0)  // 최대 10초 대기
        return result
    }

    /// 삭제 없이 텍스트만 동기식 삽입 (Issue793: ClipboardReplacementHandler에 위임)
    func insertOnlyTextSync(_ content: String) -> Bool {

        guard !content.isEmpty else {
            return false
        }

        guard isAccessibilityPermissionGranted() else {
            return false
        }

        return clipboardHandler.insertTextSync(content)
    }

    /// 마지막 오류 정보
    var lastErrorInfo: TextReplacerError? {
        return lastError
    }

    /// 통계 정보
    var operationStatistics: (count: Int, lastError: TextReplacerError?) {
        return (operationCount, lastError)
    }

    // MARK: - Placeholder Processing

    /// 플레이스홀더 포함 여부 확인
    private func containsPlaceholders(_ content: String) -> Bool {
        // Issue 549: Broaden regex to include ./, /, ~, etc.
        // Old: `\{\{[\w\s]*(?::[\w\s]*)?\}\}`
        // New: `\{\{.*?\}\}` - simpler and covers all cases including file paths and nested snippets.
        // But we want to avoid matching standard handlebars if used for other things?
        // fSnippet uses {{}} for all dynamic content.
        // Updated for Issue 568: Include {(...)} for Shortcuts
        let pattern = #"\{\{.*?\}\}|\{\(.*?\)\}"#
        return content.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Issue78: Dynamic Placeholder Replacement

    /// 동적 플레이스홀더를 실제 값으로 치환
    /// - Parameter content: 동적 플레이스홀더가 포함된 원본 텍스트
    /// - Returns: 치환된 텍스트
    private func replaceDynamicPlaceholders(_ content: String, snippetPath: String? = nil) -> String
    {
        // ✅ Issue 568_1: Shortcuts 실행 중 키보드 입력이 가능하도록 Event Tap 일시 중지
        // Shortcuts가 포함되어 있을 가능성이 있는 경우에만 수행 (성능 최적화)
        // {(...)} 구문이 있는 경우에만 중지
        let hasShortcuts = content.contains("{(")

        if hasShortcuts {
            logV("🖊️ [Placeholders] Shortcuts syntax detected. Suspending Event Tap for input...")
            delegate?.requestEventMonitoringSuspension()
        }

        // 작업 완료 후 반드시 재개 보장
        defer {
            if hasShortcuts {
                logV("🖊️ [Placeholders] Shortcuts execution finished. Resuming Event Tap.")
                delegate?.requestEventMonitoringResumption()
            }
        }

        // ✅ 전략 패턴(DynamicContentManager)을 통한 통합 처리
        let result = DynamicContentManager.shared.process(content, snippetPath: snippetPath)

        logV("🖊️ [TextReplacer] 동적 플레이스홀더 및 중첩 스니펫/파일 참조 치환 완료")
        return result
    }

    // MARK: - Issue 539: Nested Snippets logic moved to SnippetExpansionManager

    /// 플레이스홀더 추출 (중복 제거)
    private func extractPlaceholders(from content: String) -> [PlaceholderData] {
        let pattern = #"\{\{([\w\s]+)(?::([\w\s]*))?\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            logE("🖊️ ❌ 플레이스홀더 정규식 생성 실패")
            return []
        }

        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        var placeholderDict: [String: PlaceholderData] = [:]

        for (index, match) in matches.enumerated() {
            let nameRange = Range(match.range(at: 1), in: content)
            let defaultRange =
                match.numberOfRanges > 2 ? Range(match.range(at: 2), in: content) : nil

            if let nameRange = nameRange {
                let name = String(content[nameRange]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let defaultValue =
                    defaultRange != nil
                    ? String(content[defaultRange!]).trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil

                // 중복 제거: 이미 존재하는 이름이면 건너뜀
                if placeholderDict[name] == nil {
                    placeholderDict[name] = PlaceholderData(
                        name: name,
                        defaultValue: defaultValue?.isEmpty == false ? defaultValue : nil,
                        index: index
                    )
                }
            }
        }

        // Dictionary를 Array로 변환하고 index 순으로 정렬
        let placeholders = Array(placeholderDict.values).sorted { $0.index < $1.index }

        logV("🖊️ 플레이스홀더 추출 완료 (중복 제거): \(placeholders.count)개")
        for placeholder in placeholders {
            logV("🖊️     - \(placeholder.name): \(placeholder.defaultValue ?? "(기본값 없음)")")
        }

        return placeholders
    }

    /// 플레이스홀더 처리
    private func processPlaceholders(
        abbreviation: String,
        content: String,
        referenceFrame: NSRect? = nil,
        snippetPath: String? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // 플레이스홀더 처리 시작 logic...

        // Background Queue에서 초기 작업 수행 (텍스트 삭제 등)
        workQueue.async { [weak self] in
            guard let self = self else { return }

            // 0. 기존 텍스트 즉시 삭제 (먼저 수행하여 UX 개선 및 타이밍 이슈 방지)
            // Issue 568 Fix: Shortcuts 등 느린 작업 전에 텍스트를 먼저 삭제해야 함
            let deleteCount = abbreviation.count
            if deleteCount > 0 {
                // Background thread에서 동기 삭제 실행
                if !self.clipboardHandler.deleteCharactersSync(count: deleteCount) {
                    logE("🖊️ ❌ [Async] 플레이스홀더 처리 전 텍스트 삭제 실패")
                    DispatchQueue.main.async { completion(false, self.lastError) }
                    return
                }
                // ✅ Issue 568 Verification Fix
                usleep(50000)  // 50ms 대기 (Background에서 대기하므로 UI 프리징 없음)
            }

            // ✅ Issue78: 동적 플레이스홀더 치환 (Shortcuts 실행 포함 - 느릴 수 있음)
            let dynamicProcessedContent = self.replaceDynamicPlaceholders(
                content, snippetPath: snippetPath)

            // [Issue350 개선] 작업을 수행하기 전에 @cursor 유효성 검사 실패 사전 확인
            do {
                _ = try self.validateCursorRules(in: dynamicProcessedContent)
            } catch {
                logW(
                    "🖊️ ⚠️ [TextReplacer] @cursor 사전 확인 실패: \(error.localizedDescription) -> 경고 표시 및 계속 진행"
                )
                // UI 관련 작업은 Main Thread
                DispatchQueue.main.async {
                    self.showErrorAlert(error, timeout: 2.0)
                }
            }

            // 1. 플레이스홀더 추출 (동적 플레이스홀더 치환 후)
            let placeholders = self.extractPlaceholders(from: dynamicProcessedContent)
            guard !placeholders.isEmpty else {
                logW("🖊️ ⚠️ 플레이스홀더가 발견되지 않음 - 일반 텍스트 대체로 처리")
                // 이미 삭제했으므로 deleteCount는 0으로 전달
                let success = self.performSyncTextReplacement(
                    deleteCount: 0, insertText: dynamicProcessedContent, snippetPath: snippetPath)
                DispatchQueue.main.async { completion(success, self.lastError) }
                return
            }

            logV("🖊️ [TextReplacer] processPlaceholders 진입")
            logV("🖊️     - Placeholders Count: \(placeholders.count)")

            // 3. 비동기 플레이스홀더 입력 요청 (UI 표시)
            DispatchQueue.main.async {
                // AppActivationMonitor에 스니펫 팝업창 표시 상태 알림
                AppActivationMonitor.shared.setPopupVisible(true)

                // Issue797: Placeholder 창 표시 전 replacement 상태 일시 해제
                // CGEventTapManager에서 isReplacing && isAppActive 조건으로 키 이벤트를 차단하므로,
                // Placeholder 입력 중에는 replacement 상태를 해제하여 키보드 입력을 허용해야 함
                self.delegate?.requestReplacementSuspension()

                // ✅ Issue656: 플레이스홀더 창 열리기 직전에 원래 앱+윈도우 정보 캡처
                let sourceApp = NSWorkspace.shared.frontmostApplication
                let sourceWindowID = self.getFrontmostWindowID()
                logI(
                    "🖊️ [Issue656] 플레이스홀더 창 열림 - 원래 앱: \(sourceApp?.bundleIdentifier ?? "nil"), 윈도우: \(String(describing: sourceWindowID))"
                )

                self.placeholderWindow.showInput(
                    with: placeholders, templateContent: dynamicProcessedContent,
                    referenceFrame: referenceFrame
                ) { results in
                    // Issue797: Placeholder 입력 완료 — replacement 상태 복원
                    self.delegate?.requestReplacementResumption()
                    // 플레이스홀더 입력 완료 시 팝업 상태 해제
                    AppActivationMonitor.shared.setPopupVisible(false)

                    if results.isEmpty {
                        // 취소된 경우 - 복원 여부 결정
                        // ✅ Issue656 수정: 플레이스홀더 창(fSnippet)에서 직접 ESC로 취소하면
                        //   currentApp == fSnippet 이 되므로, fSnippet 자신도 복원 허용
                        let currentApp = NSWorkspace.shared.frontmostApplication
                        let currentBundleID = currentApp?.bundleIdentifier ?? ""
                        let fSnippetBundleID = Bundle.main.bundleIdentifier ?? "com.nowage.fSnippet"

                        // 복원 허용 조건:
                        //   1. fSnippet이 active = 플레이스홀더 창에서 직접 취소한 것
                        //   2. sourceApp이 active = 원래 앱으로 이미 복귀한 것
                        // 스킵 조건:
                        //   제3의 앱(sourceApp도 아니고 fSnippet도 아닌 앱)이 active인 경우
                        let canceledFromPlaceholder = currentBundleID == fSnippetBundleID
                        let returnedToSource =
                            currentBundleID == (sourceApp?.bundleIdentifier ?? "")
                        let shouldRestore = canceledFromPlaceholder || returnedToSource

                        if shouldRestore {
                            logV(
                                "🖊️ [Issue656] 복원 허용 - currentApp: \(currentBundleID), 트리거 텍스트: '\(abbreviation)'"
                            )
                            self.restoreOriginalText(abbreviation, completion: completion)
                        } else {
                            logI(
                                "🖊️ [Issue656] 제3의 앱으로 이동 감지 - abbreviation 복원 스킵 (currentApp: \(currentBundleID), sourceApp: \(sourceApp?.bundleIdentifier ?? "nil"))"
                            )
                            completion(false, nil)
                        }
                        return
                    }

                    // 결과 처리 및 텍스트 삽입 (Background Queue)
                    self.workQueue.async {
                        do {
                            let (finalText, cursorOffset) = try self.replacePlaceholders(
                                in: dynamicProcessedContent, with: results)

                            // UI 포커스 복원 등은 Main에서 해야 할 수도 있지만,
                            // insertTextSync 전에 포커스를 복원해야 함.

                            DispatchQueue.main.async {
                                // 원래 입력하던 앱으로 포커스 복원 시도
                                if let inputApp = AppActivationMonitor.shared.getInputApp() {
                                    inputApp.activate()
                                    logV("🖊️ 원래 앱으로 포커스 복원: \(inputApp.localizedName ?? "unknown")")
                                }

                                // 포커스 전환 대기 후 텍스트 삽입 (Background로 다시 넘김)
                                // UI 반응성을 위해 약간의 딜레이
                                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                                    self.workQueue.async {
                                        _ = self.clipboardHandler.insertTextSync(finalText)

                                        // ✅ Issue28 해결: @cursor 위치로 이동 추가
                                        if cursorOffset != 0 {
                                            _ = CursorTracker.shared.moveCursorByCharacters(cursorOffset)
                                            logV("🖊️ 플레이스홀더 처리 후 커서 이동: \(cursorOffset)자")
                                        }

                                        logV("🖊️ 플레이스홀더 텍스트 삽입 완료")
                                        DispatchQueue.main.async { completion(true, nil) }
                                    }
                                }
                            }
                        } catch {
                            logE("🖊️ [TextReplacer] 플레이스홀더 후 처리 실패: \(error)")
                            DispatchQueue.main.async {
                                self.showErrorAlert(error)
                                completion(false, error)
                            }
                        }
                    }
                }
            }
        }
    }

    private func restoreOriginalText(
        _ content: String, completion: @escaping (Bool, Error?) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 원래 입력하던 앱으로 포커스 복원
            if let inputApp = AppActivationMonitor.shared.getInputApp() {
                inputApp.activate()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                self.workQueue.async {
                    _ = self.clipboardHandler.insertTextSync(content)
                    logV("🖊️ 플레이스홀더 취소 - 원본 텍스트 복원 완료")
                    DispatchQueue.main.async { completion(false, nil) }  // 취소는 성공/실패 애매함, 일단 false
                }
            }
        }
    }

    /// 플레이스홀더를 실제 값으로 치환 (마커 처리 포함)
    private func replacePlaceholders(in content: String, with results: [PlaceholderResult]) throws
        -> (text: String, cursorOffset: Int)
    {
        var finalContent = content

        // 1. 플레이스홀더 치환
        for result in results {
            let placeholder = "{{\(result.name)}}"
            let placeholderWithDefault = "\\{\\{\(result.name):[^}]*\\}\\}"

            // 기본값이 있는 플레이스홀더 먼저 치환
            if let regex = try? NSRegularExpression(pattern: placeholderWithDefault) {
                finalContent = regex.stringByReplacingMatches(
                    in: finalContent,
                    range: NSRange(finalContent.startIndex..., in: finalContent),
                    withTemplate: result.value
                )
            }

            // 기본값이 없는 플레이스홀더 치환
            finalContent = finalContent.replacingOccurrences(of: placeholder, with: result.value)
        }

        logV("🖊️ 플레이스홀더 치환 완료: '\(finalContent.prefix(50))...'")

        // 2. ✅ Issue28 해결: @clipboard 마커 처리 추가
        finalContent = processClipboardMarker(in: finalContent)

        // 3. ✅ Issue28 해결: @cursor 마커 처리 추가 (커서 오프셋 반환)
        // [Issue350] 예외 전파 (Propagate throws)
        let (cleanedContent, cursorOffset) = try processCursorMarker(in: finalContent)

        logV("🖊️ 마커 처리 완료: '\(cleanedContent.prefix(50))...', 커서 오프셋: \(cursorOffset)")
        return (text: cleanedContent, cursorOffset: cursorOffset)
    }

    // MARK: - Private Synchronous Implementation (Issue793: ClipboardReplacementHandler에 위임)

    /// 동기식 텍스트 대체 실행 (Background Queue에서 실행 권장)
    private func performSyncTextReplacement(
        deleteCount: Int, insertText: String, snippetPath: String? = nil
    ) -> Bool {
        return clipboardHandler.performSyncTextReplacement(
            deleteCount: deleteCount,
            insertText: insertText,
            snippetPath: snippetPath,
            replaceDynamicPlaceholders: { [weak self] content, path in
                self?.replaceDynamicPlaceholders(content, snippetPath: path) ?? content
            },
            processClipboardMarker: { [weak self] content in
                self?.processClipboardMarker(in: content) ?? content
            },
            processCursorMarker: { [weak self] content in
                try self?.processCursorMarker(in: content) ?? (content, 0)
            },
            showErrorAlert: { [weak self] error, timeout in
                self?.showErrorAlert(error, timeout: timeout)
            }
        )
    }

    /// 동기식 Cmd+V 실행 (Issue793: ClipboardReplacementHandler에 위임)
    func sendCmdVSync() -> Bool {
        return clipboardHandler.sendCmdVSync()
    }

    /// 접근성 권한 확인
    private func isAccessibilityPermissionGranted() -> Bool {
        return clipboardHandler.isAccessibilityPermissionGranted()
    }

    /// 앱 종료 시 정리
    func cleanup() {
        // 플레이스홀더 윈도우가 표시 중이면 숨김
        if placeholderWindow.isVisible() {
            // 윈도우 정리는 내부적으로 처리됨
        }
    }

    // MARK: - Issue656: Window Identity Helper

    /// 현재 화면 최상위(포커스된) 일반 앱 윈도우의 CGWindowID를 반환합니다.
    /// CGWindowListCopyWindowInfo는 z-order 내림차순(최상위 먼저)으로 반환합니다.
    /// 레이어 0(일반 앱 창)의 첫 번째 항목이 현재 포커스된 윈도우입니다.
    private func getFrontmostWindowID() -> CGWindowID? {
        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[CFString: Any]]
        else {
            return nil
        }
        // 레이어 0 = 일반 앱 창, CGWindowListCopyWindowInfo는 최상위 창이 앞에 옴
        for entry in windowList {
            let layer = entry[kCGWindowLayer] as? Int32 ?? 999
            if layer == 0,
                let windowID = entry[kCGWindowNumber] as? CGWindowID
            {
                return windowID
            }
        }
        return nil
    }
}

// MARK: - TextReplacerError (변경 없음)

enum TextReplacerError: LocalizedError {
    case invalidInput(String)
    case accessibilityPermissionDenied
    case clipboardOperationFailed
    case operationFailed(String)
    case systemError(String)
    // Issue350: Cursor Validation Errors
    case multipleCursorMarkers(count: Int)
    case cursorDistanceExceeded(current: Int, max: Int)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for text replacement"
        case .clipboardOperationFailed:
            return "Clipboard operation failed"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .systemError(let message):
            return "System error: \(message)"
        case .multipleCursorMarkers(let count):
            return "Multiple @cursor markers found: \(count). Only one allowed."
        case .cursorDistanceExceeded(let current, let max):
            return "@cursor is too far from end: \(current) chars (Limit: \(max))."
        }
    }
}

// MARK: - Legacy Support (기존 코드 호환성)

extension TextReplacer {
    /// 기존 async 메서드 래퍼 (호환성 유지)
    @available(*, deprecated, message: "Use replaceTextSync instead")
    func replaceText(
        abbreviation: String, with snippetContent: String,
        completion: @escaping (Result<Void, TextReplacerError>) -> Void
    ) {
        let success = replaceTextSync(abbreviation: abbreviation, with: snippetContent)
        if success {
            completion(.success(()))
        } else {
            completion(.failure(lastError ?? .operationFailed("Unknown error")))
        }
    }
}

// MARK: - @clipboard Support

extension TextReplacer {

    /// @clipboard 마커를 현재 클립보드 내용으로 대체 - 클립보드 누수 방지
    /// - Parameter content: @clipboard 마커가 포함된 원본 텍스트
    /// - Returns: @clipboard가 클립보드 내용으로 대체된 텍스트
    private func processClipboardMarker(in content: String) -> String {
        let clipboardMarker = "@clipboard"

        // @clipboard 마커가 없으면 원본 반환
        guard content.contains(clipboardMarker) else {
            logV("🖊️ [@clipboard] 마커가 없음 - 원본 텍스트 사용")
            return content
        }

        // ⚠️ 클립보드 백업이 필요한 상황임을 경고
        logW("🖊️ [@clipboard] 마커 감지 - 클립보드 중복 사용 위험 있음")

        // 클립보드 내용 획득 (insertTextSync에서 백업한 내용 사용 불가)
        let pasteboard = NSPasteboard.general
        guard let clipboardContent = pasteboard.string(forType: .string) else {
            logE("🖊️ [@clipboard] 클립보드에서 문자열 내용을 찾을 수 없음 - 마커 제거")
            logE("🖊️ [@clipboard] 이는 스니펫 처리 과정에서 클립보드가 변경되었기 때문일 수 있음")
            return content.replacingOccurrences(of: clipboardMarker, with: "[클립보드 없음]")
        }

        // 현재 클립보드가 스니펫 내용인지 확인 (무한 루프 방지)
        if clipboardContent == content {
            logE("🖊️ [@clipboard] 무한 루프 감지 - 클립보드 내용이 현재 스니펫과 동일")
            return content.replacingOccurrences(of: clipboardMarker, with: "[순환 참조 방지]")
        }

        // @clipboard를 실제 클립보드 내용으로 대체
        let processedText = content.replacingOccurrences(
            of: clipboardMarker, with: clipboardContent)

        logV("🖊️ [@clipboard] 마커 대체 완료:")
        logV("🖊️     - 원본 텍스트: '\(content)'")
        logV("🖊️     - 클립보드 내용: '\(clipboardContent.prefix(50))...'")
        logV("🖊️     - 대체된 텍스트: '\(processedText.prefix(100))...'")

        return processedText
    }
}

// MARK: - @cursor Support

extension TextReplacer {

    // [Issue350] Separate validation logic for reusable pre-check
    /// @cursor 규칙 위반 여부만 검사 (Validation Only)
    private func validateCursorRules(in content: String) throws {
        let cursorMarker = "@cursor"
        let cursorRanges = content.ranges(of: cursorMarker)

        // 1. Check Count
        if cursorRanges.count > 1 {
            throw TextReplacerError.multipleCursorMarkers(count: cursorRanges.count)
        }

        // 2. Check Distance (Only if 1 exists)
        if let lastRange = cursorRanges.last {
            // Note: This logic mimics processCursorMarker's simple removal logic for distance estimation
            // let cleanedText = content.replacingOccurrences(of: cursorMarker, with: "")

            // "After Cursor" text estimation
            // Ideally we need exact offset, but simple estimation is enough for pre-check
            // Actually, we should calculate distance from END of string.
            // processCursorMarker does: afterCursorText = String(content[lastCursorRange.upperBound...])
            // But content includes markers.

            // Re-logic:
            // The constraint is about distance from END of FINAL expanded string.
            // But processCursorMarker runs on logic: `let afterCursorText = String(content[lastCursorRange.upperBound...])`, `let afterCursorLength = afterCursorText.count`
            // Wait, processCursorMarker calculates offset based on CONTENT WITH MARKER REMOVED?
            // Let's check processCursorMarker Implementation below.

            // processCursorMarker:
            // let cleanedText = content.replacingOccurrences(of: cursorMarker, with: "")
            // let afterCursorText = String(content[lastCursorRange.upperBound...]) -> This uses indices from ORIGINAL content?
            // If we remove markers, indices shift.
            // The current processCursorMarker implementation (lines 953+) calculates `afterCursorText` using ORIGINAL indices on ORIGINAL content.
            // Then it returns `cursorOffset = -afterCursorLength`.
            // So `afterCursorLength` includes any characters AFTER the marker in the ORIGINAL string.

            // So `validateCursorRules` should do the same to be consistent.
            let afterCursorText = String(content[lastRange.upperBound...])
            let afterCursorLength = afterCursorText.count

            let maxDistance = PreferencesManager.shared.cursorMaxDistance
            if afterCursorLength > maxDistance {
                // Issue354: Relaxed Validation - Do not throw, just warn
                logW(
                    "🖊️ ⚠️ [@cursor] Pre-check: Limit exceeded (\(afterCursorLength) > \(maxDistance)) - Will strip & paste without movement"
                )
                // Issue798: 즉시 표시하면 makeKeyAndOrderFront 포커스 탈취로 Cmd+V 실패
                // 텍스트 삽입 완료 후 알림이 표시되도록 지연
                let msg = "@cursor is too far from end: \(afterCursorLength) chars (Limit: \(maxDistance))."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    FloatingAlertManager.shared.show(
                        title: "Snippet Expansion Alert", message: msg, timeout: 2.0)
                }
            }
        }
    }

    /// @cursor 마커를 처리하여 텍스트를 정제하고 커서 이동 오프셋을 계산
    /// - Parameter content: @cursor 마커가 포함된 원본 텍스트
    /// - Returns: (정제된 텍스트, 커서 이동 오프셋)
    private func processCursorMarker(in content: String) throws -> (
        cleanedText: String, cursorOffset: Int
    ) {
        let cursorMarker = "@cursor"

        // @cursor 마커 찾기
        let cursorRanges = content.ranges(of: cursorMarker)

        guard !cursorRanges.isEmpty else {
            // @cursor 마커가 없으면 원본 텍스트 그대로 반환
            logV("🖊️ [@cursor] 마커가 없음 - 원본 텍스트 사용")
            return (content, 0)
        }

        // [Issue350] 여러 @cursor 마커가 있는 경우 Error 발생
        if cursorRanges.count > 1 {
            logE("🖊️ [@cursor] 여러 개의 @cursor 마커 발견 (\(cursorRanges.count)개) - 처리 중단")
            throw TextReplacerError.multipleCursorMarkers(count: cursorRanges.count)
        }

        logV("🖊️ [@cursor] @cursor 마커 발견 - 커서 위치 처리 진행")

        // Issue653: 'last!'(강제 언래핑) 대신 guard let 패턴 사용. L979 guard, L986 throw로 count==1 논리적 보장됨.
        guard let lastCursorRange = cursorRanges.last else {
            return (content, 0)
        }

        // @cursor 마커 제거
        let cleanedText = content.replacingOccurrences(of: cursorMarker, with: "")

        // 마지막 @cursor 위치 이후의 텍스트 길이 계산 (커서가 이동해야 할 거리)
        let afterCursorText = String(content[lastCursorRange.upperBound...])
        // [Issue350] 마커 제거 후 실제 텍스트 길이 기준 (마커 뒤에 다른 텍스트가 있을 수 있음)
        // 주의: content에서 잘라낸 후 cleanedText 내에서의 위치를 찾아야 정확하지만,
        // @cursor가 하나뿐이고 단순 제거이므로 '마커 뒤의 텍스트 길이'가 곧 '이동 거리'임.
        // 단, replaceOccurrences로 제거했으므로 @cursor 오프셋은 변하지 않음 (단 content 내 다른 @cursor가 없다면).
        // 여기서는 @cursor가 1개뿐이므로 `afterCursorText`의 길이가 정확한 오프셋이 됨.

        let afterCursorLength = afterCursorText.count

        // [Issue350] 거리 제한 검사
        let maxDistance = PreferencesManager.shared.cursorMaxDistance
        if afterCursorLength > maxDistance {
            logW(
                "🖊️ ⚠️ [@cursor] 커서 이동 거리가 너무 멉니다: \(afterCursorLength) > \(maxDistance). 이동을 취소하고 텍스트만 입력합니다."
            )
            // Issue798: 즉시 표시하면 makeKeyAndOrderFront 포커스 탈취로 Cmd+V 실패
            // 텍스트 삽입 완료 후 알림이 표시되도록 지연
            let msg = "@cursor is too far from end: \(afterCursorLength) chars (Limit: \(maxDistance))."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                FloatingAlertManager.shared.show(
                    title: "Snippet Expansion Alert", message: msg, timeout: 2.0)
            }
            return (cleanedText, 0)
        }

        // 커서는 왼쪽으로 이동해야 하므로 음수로 반환
        let cursorOffset = -afterCursorLength

        logV("🖊️ [@cursor] 처리 완료:")
        logV("🖊️     - 원본 텍스트: '\(content)'")
        logV("🖊️     - 정제된 텍스트: '\(cleanedText)'")
        logV("🖊️     - 커서 오프셋: \(cursorOffset)")

        return (cleanedText, cursorOffset)
    }

    /// Error Alert 표시 (Floating Alert 사용)
    private func showErrorAlert(_ error: Error, timeout: TimeInterval? = nil) {
        // [Issue350 Refinement] Use FloatingAlertManager for better positioning and auto-close
        // [Issue354] Add auto-dismiss timeout
        FloatingAlertManager.shared.show(
            title: "Snippet Expansion Alert", message: error.localizedDescription, timeout: timeout)
    }
}

/// macOS Shortcuts 앱의 단축어를 실행하는 러너
class ShortcutRunner {
    static let shared = ShortcutRunner()

    // 타임아웃 설정 (기본 5초)
    private let defaultTimeout: TimeInterval = 5.0

    private init() {}

    /// 단축어를 실행하고 결과를 반환합니다.
    /// - Parameters:
    ///   - name: 실행할 단축어 이름
    ///   - input: 단축어에 전달할 입력 텍스트 (Optional)
    /// - Returns: 단축어 실행 결과 (String) 또는 에러 메시지
    func runShortcut(name: String, input: String?) -> String {
        logV("⚡️ [Shortcut] Running shortcut: '\(name)' with input: '\(input ?? "nil")'")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")

        let arguments = ["run", name]

        // 입력이 있으면 stdin으로 전달하지 않고, shortcuts 커맨드는 stdin을 받음
        // "shortcuts run 'Name'" 실행 후 stdin에 데이터 기록

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let inputText = input, !inputText.isEmpty {
            process.standardInput = inputPipe
        }

        do {
            try process.run()

            // 입력값 전달
            if let inputText = input, !inputText.isEmpty, let data = inputText.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
                inputPipe.fileHandleForWriting.closeFile()
            }

            // Issue788: DispatchSemaphore 기반 5초 타임아웃으로 무한 대기 방지
            let semaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in semaphore.signal() }
            let timeout = DispatchTime.now() + .seconds(5)
            if semaphore.wait(timeout: timeout) == .timedOut {
                logW("⚡️ [Shortcut] 프로세스 5초 타임아웃 - 강제 종료: \(name)")
                process.terminate()
                return "[Error: Shortcut '\(name)' timed out after 5 seconds]"
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if process.terminationStatus == 0 {
                let output =
                    String(data: outputData, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    ?? ""
                logV("⚡️ [Shortcut] Execution success. Output length: \(output.count)")
                return output
            } else {
                let errorMsg =
                    String(data: errorData, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    ?? "Unknown Error"
                logE(
                    "⚡️ [Shortcut] Execution failed (Code \(process.terminationStatus)): \(errorMsg)"
                )
                return "[Error: Shortcut '\(name)' failed - \(errorMsg)]"
            }

        } catch {
            logE("⚡️ [Shortcut] Process launch failed: \(error)")
            return "[Error: Failed to launch shortcut '\(name)']"
        }
    }
}

// MARK: - Placeholder Strategy Pattern Implementation

/// 플레이스홀더 치환 로직을 수행하는 전략(Strategy) 프로토콜
protocol PlaceholderExpander {
    /// 해당 Expander가 처리할 수 있는 패턴인지 확인 (빠른 필터링용)
    func canExpand(_ content: String) -> Bool

    /// 실제 치환 로직 수행
    func expand(_ content: String) -> String
}

class DynamicContentManager {
    static let shared = DynamicContentManager()

    // 처리 순서대로 등록
    private let expanders: [PlaceholderExpander]

    private init() {
        self.expanders = [
            ClipboardExpander(),
            DateExpander(),
            UUIDExpander(),
            SnippetReferenceExpander(),
            ShortcutExpander(),
            TextPastryExpander(),
        ]
    }

    func process(_ content: String, snippetPath: String? = nil) -> String {
        var result = content

        // 0. 커서 플레이스홀더 처리 ({{cursor}} -> @cursor)
        result = result.replacingOccurrences(of: "{{cursor}}", with: "@cursor")

        // 1. 등록된 Expander 순차 실행
        for expander in expanders {
            if expander.canExpand(result) {
                result = expander.expand(result)
            }
        }

        // 2. [Issue539] 중첩 스니펫 처리 ({{Folder/File}}) 및 파일 참조 ({{~/path}})
        result = SnippetExpansionManager.shared.expand(result, basePath: snippetPath)

        return result
    }
}

class ClipboardExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{{clipboard")
    }

    func expand(_ content: String) -> String {
        var result = content
        let pasteboard = NSPasteboard.general

        guard let clipboardContent = pasteboard.string(forType: .string) else {
            logV("🖊️ [ClipboardExpander] 클립보드 내용 없음 - 건너뜀")
            return result
        }

        // {{clipboard}} - 기본 클립보드
        result = result.replacingOccurrences(of: "{{clipboard}}", with: clipboardContent)

        // {{clipboard:trim}} - 공백 제거
        let trimmed = clipboardContent.trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: "{{clipboard:trim}}", with: trimmed)

        // {{clipboard:uppercase}} - 대문자 변환
        result = result.replacingOccurrences(
            of: "{{clipboard:uppercase}}", with: clipboardContent.uppercased())

        // {{clipboard:lowercase}} - 소문자 변환
        result = result.replacingOccurrences(
            of: "{{clipboard:lowercase}}", with: clipboardContent.lowercased())

        // {{clipboard:capitals}} - 단어 첫 글자 대문자
        let capitalized = clipboardContent.capitalized
        result = result.replacingOccurrences(of: "{{clipboard:capitals}}", with: capitalized)

        // {{clipboard:N}} - 클립보드 히스토리 (1-9)
        for i in 1...9 {
            if result.contains("{{clipboard:\(i)}}") {
                let targetIndex = i + 1
                let dbValue = ClipboardDB.shared.fetchPlainTextAt(historyIndex: targetIndex)
                let fallback = ClipboardManager.shared.getHistory(at: targetIndex)
                let historyContent = dbValue ?? fallback ?? ""
                result = result.replacingOccurrences(of: "{{clipboard:\(i)}}", with: historyContent)
            }
        }

        return result
    }
}

class DateExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{{date") || content.contains("{{time}}")
            || content.contains("{{isodate:")
    }

    func expand(_ content: String) -> String {
        var result = content
        let now = Date()
        let dateFormatter = DateFormatter()

        // {{date}} - 기본 날짜 (yyyy.MM.dd)
        dateFormatter.dateFormat = "yyyy.MM.dd"
        let dateString = dateFormatter.string(from: now)
        result = result.replacingOccurrences(of: "{{date}}", with: dateString)

        // {{time}} - 기본 시간 (HH:mm:ss)
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeString = dateFormatter.string(from: now)
        result = result.replacingOccurrences(of: "{{time}}", with: timeString)

        // {{date:short}} - 짧은 날짜 (MM/dd/yy)
        dateFormatter.dateFormat = "MM/dd/yy"
        let shortDateString = dateFormatter.string(from: now)
        result = result.replacingOccurrences(of: "{{date:short}}", with: shortDateString)

        // {{isodate:format}} - 커스텀 날짜 형식
        let isodatePattern = #"\{\{isodate:([^}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: isodatePattern) {
            let matches = regex.matches(
                in: result, range: NSRange(result.startIndex..., in: result))

            for match in matches.reversed() {
                if let formatRange = Range(match.range(at: 1), in: result) {
                    let format = String(result[formatRange])
                    dateFormatter.dateFormat = format
                    let customDateString = dateFormatter.string(from: now)

                    if let fullRange = Range(match.range(at: 0), in: result) {
                        result.replaceSubrange(fullRange, with: customDateString)
                    }
                }
            }
        }

        return result
    }
}

class UUIDExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{{random:UUID}}")
    }

    func expand(_ content: String) -> String {
        var result = content
        while result.contains("{{random:UUID}}") {
            let uuid = UUID().uuidString
            if let range = result.range(of: "{{random:UUID}}") {
                result.replaceSubrange(range, with: uuid)
            }
        }
        return result
    }
}

class SnippetReferenceExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{{snippet:")
    }

    func expand(_ content: String) -> String {
        var result = content
        let snippetPattern = #"\{\{snippet:([^}]+)\}\}"#

        guard let regex = try? NSRegularExpression(pattern: snippetPattern) else { return result }

        let matches = regex.matches(
            in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            if let nameRange = Range(match.range(at: 1), in: result),
                let fullRange = Range(match.range(at: 0), in: result)
            {
                let snippetName = String(result[nameRange])

                // 스니펫 검색 및 내용 가져오기 (SnippetIndexManager 사용)
                let searchResults = SnippetIndexManager.shared.search(
                    term: snippetName, maxResults: 1)

                if let referencedSnippet = searchResults.first(where: {
                    $0.abbreviation == snippetName
                }) {
                    do {
                        let snippetContent = try String(
                            contentsOf: referencedSnippet.filePath, encoding: .utf8)

                        // 순환 참조 방지
                        if snippetContent.contains("{{snippet:") {
                            logW(
                                "🖊️ [SnippetReferenceExpander] 순환 참조 방지 - {{snippet:\(snippetName)}} 건너뜀"
                            )
                        } else {
                            result.replaceSubrange(fullRange, with: snippetContent)
                            logV(
                                "🖊️ [SnippetReferenceExpander] 스니펫 참조 치환: {{snippet:\(snippetName)}}"
                            )
                        }
                    } catch {
                        logE("🖊️ [SnippetReferenceExpander] 스니펫 파일 읽기 실패: \(snippetName) - \(error)")
                        result.replaceSubrange(fullRange, with: "[스니펫 읽기 실패: \(snippetName)]")
                    }
                } else {
                    logW("🖊️ [SnippetReferenceExpander] 참조 스니펫 못 찾음: {{snippet:\(snippetName)}}")
                    result.replaceSubrange(fullRange, with: "[스니펫 없음: \(snippetName)]")
                }
            }
        }
        return result
    }
}

class ShortcutExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{(")
    }

    func expand(_ content: String) -> String {
        var result = content
        let pattern = #"\{\((.*?)\)\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: result),
                let fullRange = Range(match.range(at: 0), in: result)
            else { continue }

            let contentString = String(result[range])
            // Name:Input 분리
            let parts = contentString.split(
                separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let input = parts.count > 1 ? String(parts[1]) : nil

            if !name.isEmpty {
                let shortcutResult = ShortcutRunner.shared.runShortcut(name: name, input: input)
                result.replaceSubrange(fullRange, with: shortcutResult)
            } else {
                logW("⚡️ [ShortcutExpander] Empty shortcut name found")
            }
        }

        return result
    }
}

class TextPastryExpander: PlaceholderExpander {
    func canExpand(_ content: String) -> Bool {
        return content.contains("{#")
    }

    func expand(_ content: String) -> String {
        var result = content
        // Pattern: {#number} e.g. {#1}, {#0}, {#100}
        // Use extended delimiters ## to avoid \#(...) interpolation conflict
        let pattern = ##"\{\#(\d+)\}"##

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Forward pass to calculate values
        var replacements: [(range: NSRange, value: String)] = []
        var counters: [String: Int] = [:]  // key: start number string

        for match in matches {
            if let range = Range(match.range(at: 1), in: result) {
                let key = String(result[range])

                // Initialize/Get current value
                // Safe implementation to avoid '+= 1' on force unwrap issues
                let startValue = Int(key) ?? 0
                let currentValue = counters[key] ?? startValue

                replacements.append((match.range(at: 0), String(currentValue)))

                // Increment for next
                counters[key] = currentValue + 1
            }
        }

        // Backward pass to apply replacements
        for replacement in replacements.reversed() {
            if let range = Range(replacement.range, in: result) {
                result.replaceSubrange(range, with: replacement.value)
            }
        }

        return result
    }
}
