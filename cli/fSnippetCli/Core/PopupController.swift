import AppKit
import AudioToolbox
import Cocoa
import Foundation

/// 팝업 모드 열거형
enum PopupMode {
    case typing  // 타이핑 모드: 사용자가 텍스트 입력 중
    case selecting  // 선택 모드: 사용자가 화살표 키로 탐색 중
}

/// 상태 변경 알림을 위한 프로토콜
protocol PopupControllerDelegate: AnyObject {
    func popupVisibilityDidChange(isVisible: Bool)
}

/// 개선된 스니펫 팝업 관리 클래스
class PopupController: PopupControllerProtocol {

    // MARK: - Properties

    private let popupWindow = SnippetNonActivatingWindow()

    private(set) var isVisible: Bool = false {
        didSet {
            // ✅ 상태 변경 시 델리게이트에 알림
            if oldValue != isVisible {
                delegate?.popupVisibilityDidChange(isVisible: isVisible)
                logV("📦 [PopupController] 가시성 상태 변경 알림: \(isVisible)")
            }
        }
    }

    private(set) var mode: PopupMode = .typing
    private var allCandidates: [SnippetEntry] = []
    private(set) var currentSearchTerm: String = ""  // 팝업전 버퍼 문자열

    // ✅ 상태 변경 델리게이트
    weak var delegate: PopupControllerDelegate?

    // MARK: - Callbacks

    // ✅ Issue175: onSelection 콜백 서명을 (SnippetEntry, String) -> Void 로 변경
    // String은 팝업 시점의 최종 검색어(searchTerm)
    // ✅ Issue233: 팝업 프레임 정보 추가 (NSRect?)
    private var onSnippetSelected: ((SnippetEntry, String, NSRect?) -> Void)?

    // ✅ 팝업 설정 캐시 (실시간 반영용)
    private var currentSearchScope: PopupSearchScope = .abbreviation

    // MARK: - Initialization

    init() {
        // 설정 로드
        let settings = SettingsManager.shared.load()
        self.currentSearchScope = settings.popupSearchScope

        // 초기화 로직
        // SnippetPreviewManager 관련 등록 제거 (Unified 뷰에서 처리)

        // ✅ Notification 관찰자 추가 (Issue 209, 184/245)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSearchScopeChange(_:)),
            name: .popupSearchScopeDidChange, object: nil)

        // [Issue392] 앱 활성화 모니터링 시작 (포커스 잃으면 닫기)
        AppActivationMonitor.shared.startMonitoring { [weak self] in
            guard let self = self, self.isVisible else { return }
            logI("📦 [PopupController] 앱 비활성화 감지 -> 팝업 닫기")
            self.hidePopup(hideApp: false)
        }

        // [Issue383] 보조 윈도우 닫기 알림 수신
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleCloseAuxiliaryWindows(_:)),
            name: .closeAuxiliaryWindows, object: nil)

        // ✅ Issue219_2 + Issue719: 편집기 전환 처리
        // Issue719: 팝업을 닫지 않고 유지하여 레이어 스택(팝업 → 편집 창) 보존
        popupWindow.viewModel.onTransitionToEditor = { [weak self] snippet in
            logI("📦️ [PopupController] Transitioning to editor for: \(snippet.abbreviation)")

            // 1. 현재 팝업 위치 저장
            let popupFrame = self?.popupWindow.underlyingWindow.frame

            // 2. 편집기 열기 (팝업은 열린 채로 유지 - Issue719)
            SnippetEditorWindowManager.shared.showEditor(for: snippet, relativeTo: popupFrame)
        }

        // ✅ Issue 257: 신규 스니펫 생성 처리
        popupWindow.viewModel.onAddNewSnippet = { [weak self] keyword in
            logI("📦 [PopupController] Creating new snippet with keyword: \(keyword)")

            let popupFrame = self?.popupWindow.underlyingWindow.frame

            // 편집기 열기 (신규 생성 모드)
            SnippetEditorWindowManager.shared.showNewEditor(
                keyword: keyword, relativeTo: popupFrame)

            // 팝업 닫기
            self?.hidePopup(hideApp: false)
        }
    }

    // MARK: - Public Methods

    func showPopup(
        with candidates: [SnippetEntry],
        searchTerm: String = "",  // 팝업전 버퍼 문자열
        cursorRect: CGRect? = nil,  // ✅ Issue181: 미리 계산된 커서 위치 수신
        onSelection: @escaping (SnippetEntry, String, NSRect?) -> Void  // ✅ Issue233 Info Added
    ) {
        logD("📦 [PopupController] showPopup 호출 - 후보 \(candidates.count)개")

        // ✅ Issue 243_5: 최신 스코프 사용을 위해 설정 강제 새로고침
        let settings = SettingsManager.shared.load()
        self.currentSearchScope = settings.popupSearchScope
        logD("📦 [PopupController] showPopup Scope Refreshed: \(self.currentSearchScope)")

        // ✅ CL038: 입력 소스 강제 적용
        InputSourceManager.shared.applyForceInputSource()

        // ✅ Issue Fix: 콜백 저장 (사용자 회귀 리포트 수정 검증됨)
        self.onSnippetSelected = onSelection

        // 이미 표시된 경우 먼저 숨김
        if isVisible {
            logD("📦 [PopupController] 이미 표시 중이므로 먼저 숨김")
            hidePopup()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.showPopup(
                    with: candidates, searchTerm: searchTerm, cursorRect: cursorRect,
                    onSelection: onSelection)
            }
            return
        }

        // ✅ 상태 업데이트 - didSet이 호출되어 델리게이트에 알림
        isVisible = true
        mode = .typing

        // [Issue757] 스니펫 팝업 표시 시 설정창 임시 숨김
        SettingsWindowManager.shared.temporarilyHide()

        // ✅ CL054: 비활성 모드 트리거 (히스토리 이벤트 중지)
        ClipboardManager.shared.chvMode = .deactive
        logD("📦 [PopupController] chvMode set to .deactive")

        // ✅ Issue 236 Fix & Issue 513: 빈 검색어일 때 로직 개선
        // 1. candidates가 비어있으면 (Global Popup 등) -> Top 10 표시
        // 2. candidates가 있으면 (Folder Mode 등) -> 해당 candidates 사용
        if searchTerm.isEmpty {
            if candidates.isEmpty {
                let top10 = SnippetUsageManager.shared.getTop10Snippets()
                if !top10.isEmpty {
                    logV(
                        "📦 [PopupController] showPopup: 검색어 없음 & 후보 없음 -> Top 10 표시 (\(top10.count)개)"
                    )
                    allCandidates = top10
                }
            } else {
                logV(
                    "📦 [PopupController] showPopup: 검색어 없음 & 후보 있움 -> 후보 사용 (\(candidates.count)개)")
                allCandidates = candidates
            }
        } else {
            allCandidates = candidates
        }
        if searchTerm.isEmpty {
            // ...
        } else {
            allCandidates = candidates
        }
        currentSearchTerm = searchTerm

        // ✅ Issue 356 수정: suggestedCreateTerm 초기화
        // 팝업이 새로 열릴 때는 제안어 초기화
        popupWindow.viewModel.suggestedCreateTerm = nil

        // ✅ BufferManager 사용 강제: 팝업 검색어와 버퍼 동기화
        BufferManager.shared.replaceBuffer(with: currentSearchTerm)

        // 실제 팝업 표시
        popupWindow.show(
            with: allCandidates,  // Use updated candidates
            initialSearchTerm: self.currentSearchTerm,
            cursorRect: cursorRect,  // ✅ Issue181: 전달
            onSelection: { [weak self] selectedSnippet in
                self?.handleSnippetSelection(selectedSnippet)
            },
            onSearchTermChanged: { [weak self] newTerm in
                // ✅ Issue170: 검색어 변경 시 컨트롤러로 전달하여 필터링 수행
                self?.updateSearchTerm(newTerm)
            }
        )

        // ✅ Issue616: 팝업이 표시될 때 마우스 커서가 창을 가리면 밖으로 이동
        MouseUtils.ensureMouseOutside(of: popupWindow.underlyingWindow.frame)

        // ...
    }

    // ...

    func updateSearchTerm(_ searchTerm: String) {
        logV("📦 [PopupController] updateSearchTerm 호출")
        logV("📦     - 이전 searchTerm: '\(currentSearchTerm)'")
        logV("📦     - 새로운 searchTerm: '\(searchTerm)'")

        currentSearchTerm = searchTerm
        // ✅ BufferManager 사용 강제: 팝업 타이핑 중 버퍼 동기화
        BufferManager.shared.replaceBuffer(with: searchTerm)
        var newCandidates: [SnippetEntry] = []

        // ✅ Issue 236: 빈 검색어일 때 Top 10 우선 표시
        if searchTerm.isEmpty {
            let top10 = SnippetUsageManager.shared.getTop10Snippets()
            if !top10.isEmpty {
                logV("📦 [PopupController] updateSearchTerm: 검색어 없음 -> Top 10 표시 (\(top10.count)개)")
                newCandidates = top10
            } else {
                // Fallback: 전체 목록
                newCandidates = AbbreviationMatcher().getAllSnippets()
            }
        } else {
            // ✅ Issue 178/209: 캐시된 Search Scope 적용
            switch currentSearchScope {
            case .abbreviation:
                // 기존 로직: AbbreviationMatcher 사용 (단축어 중심)
                let abbreviationMatcher = AbbreviationMatcher()
                newCandidates = abbreviationMatcher.findSnippetCandidates(searchTerm: searchTerm)

            case .name, .content:
                // 확장 검색 모드: SnippetIndexManager 사용 (Scope 전달)
                newCandidates = SnippetIndexManager.shared.search(
                    term: searchTerm, scope: currentSearchScope, maxResults: 100)
            }
        }

        // 새로운 후보들로 allCandidates 업데이트
        allCandidates = newCandidates

        // ✅ Issue 356 & 357 & 365: 검색 결과 없음 -> 생성 버튼 활성화 (검색어 유지)
        if newCandidates.isEmpty && !searchTerm.isEmpty {
            logI("📦 [Issue365] 검색 결과 없음 (term: '\(searchTerm)') -> 생성 제안 표시 (검색어 유지)")

            // 1. 제안어 설정 (생성 버튼용)
            popupWindow.viewModel.suggestedCreateTerm = searchTerm

            // 2. Preview Hide
            SnippetPreviewManager.shared.hide()

            // 3. Fallback 제거 (Issue 365: 빈 리스트 유지하여 "No Results" 표시)
            // newCandidates는 이미 empty임.
            // 이후 로직(updateCandidates, show)을 자연스럽게 타도록 진행
        } else {
            // 검색 결과가 있거나 검색어가 없는 경우: 제안어 초기화
            // ✅ Issue 356 Fix: Recursive clear prevention
            // 검색어가 비어있을 때는(시스템에 의한 초기화 포함) 제안어를 유지해야 함.
            // 검색어가 있을 때만(새로운 검색 성공) 제안어를 지움.
            if !searchTerm.isEmpty {
                popupWindow.viewModel.suggestedCreateTerm = nil
            }
        }

        updateCandidates(newCandidates)
        // ...
        logV("📦 [PopupController] updateSearchTerm 완료 - allCandidates 업데이트됨")
        // 4. 윈도우에 표시 요청
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // ✅ Issue183 경쟁 상태(Race Condition) 수정:
            guard self.isVisible else {
                logD("📦️ [PopupController] updateSearchTerm 비동기 표시 중단 - 팝업이 이미 숨겨짐")
                return
            }

            // ✅ Issue169: currentSearchTerm 전달
            self.popupWindow.show(
                with: newCandidates,
                initialSearchTerm: self.currentSearchTerm,
                onSelection: { [weak self] selectedSnippet in
                    self?.handleSnippetSelection(selectedSnippet)
                },
                onSearchTermChanged: { [weak self] newTerm in
                    self?.updateSearchTerm(newTerm)
                }
            )
        }
    }

    func hidePopup(hideApp: Bool = true) {
        // ✅ [Issue34] wasVisible 캡처 — 닫기 전 상태 저장 (포커스 복원 조건 판단용)
        let wasVisible = isVisible
        logV("📦 [PopupController] hidePopup 호출 (hideApp: \(hideApp), wasVisible: \(wasVisible))")

        // ✅ Issue392: 팝업 닫을 때 검색 버퍼 초기화
        currentSearchTerm = ""
        // ✅ BufferManager 사용 강제: 팝업 닫힐 때 버퍼 초기화
        BufferManager.shared.clear(reason: "Popup Hidden")

        // 입력 소스 복원
        InputSourceManager.shared.restoreInputSource()

        // 팝업 닫기
        popupWindow.hide(hideApp: hideApp)

        isVisible = false

        // [Issue757] 스니펫 팝업 닫힘 시 설정창 복원
        SettingsWindowManager.shared.restoreFromTemporaryHide()

        // Preview Window도 확실히 닫기
        SnippetPreviewManager.shared.hide()

        // ✅ CL054: 모드 복원 (기본값 List, 또는 Focus가 처리)
        // .list로 초기화하여 HistoryViewer(표시된 경우)가 준비되도록 함.
        if ClipboardManager.shared.chvMode == .deactive {
            ClipboardManager.shared.chvMode = .list
            logD("📦 [PopupController] chvMode restored to .list")
        }

        // ✅ [Issue34] 팝업이 실제로 열려있었을 때만 포커스 복원 처리
        if hideApp && wasVisible {
            let isPaidRunning = PaidAppManager.shared.isRunning()
            let showInSwitcher = SettingsObservableObject.shared.showInAppSwitcher

            if isPaidRunning && showInSwitcher {
                // paid + 앱 전환기 모드: NSApp.hide(nil)은 SnippetNonActivatingWindow.hide()에서 이미 호출됨
                logV("📦 [PopupController] paid + show_in_app_switcher 모드 — NSApp.hide 사용 (이미 호출됨)")
            } else {
                // paid 미설치 또는 show_in_app_switcher=false:
                // stale inputApp 대신 현재 실제 frontmost 앱으로 명시적 복귀
                if let currentApp = NSWorkspace.shared.frontmostApplication,
                    currentApp.bundleIdentifier != Bundle.main.bundleIdentifier
                {
                    logV("📦 [PopupController] 현재 앱으로 명시적 복귀: \(currentApp.localizedName ?? "Unknown")")
                    if #available(macOS 14.0, *) {
                        currentApp.activate(options: [])
                    } else {
                        currentApp.activate(options: .activateIgnoringOtherApps)
                    }
                } else {
                    logW("📦 ⚠️ [PopupController] 복귀 대상 앱 없음 — NSApp.hide(nil) Fallback")
                    NSApp.hide(nil)
                }
            }
        }
    }

    func updateCandidates(_ candidates: [SnippetEntry]) {
        popupWindow.updateContent(with: candidates)
    }

    func handleArrowKey(_ keyCode: UInt16) {
        // 모드 전환: 선택 모드로 변경
        if mode != .selecting {
            mode = .selecting
        }
        popupWindow.handleArrowKey(keyCode)
    }

    func moveSelectionUp() {
        mode = .selecting
        popupWindow.handleArrowKey(126)  // Up arrow key code
    }

    func moveSelectionDown() {
        mode = .selecting
        popupWindow.handleArrowKey(125)  // Down arrow key code
    }

    func selectCurrentItem() {
        popupWindow.selectCurrentItem()
    }

    func resetSelection() {
        mode = .typing
        popupWindow.resetSelection()
    }

    var actualVisibility: Bool {
        return popupWindow.isCurrentlyVisible
    }

    //    var storedSearchTermLength: Int {
    //        return searchTermLength
    //    } // Removed in Issue175

    // MARK: - Private Methods

    private func handleSnippetSelection(_ snippet: SnippetEntry) {
        let wasVisible = isVisible

        // ✅ Issue175: 삭제 길이 계산이 KeyEventMonitor로 이동됨.
        // 대신 원본 currentSearchTerm 문자열을 전달함.
        let finalSearchTerm = currentSearchTerm

        // ✅ Issue 235: 사용 이력 기록
        SnippetUsageManager.shared.logUsage(snippet: snippet, triggerMethod: "popup")

        let callback = onSnippetSelected

        // ✅ Issue233: 팝업 닫기 전에 현재 프레임 캡처 (화면 좌표)
        // Hardening: isVisible 체크 없이 무조건 캡처 시도 (타이밍 문제 방지)
        let capturedFrame = popupWindow.underlyingWindow.frame
        let isFrameValid =
            !capturedFrame.isEmpty && capturedFrame.width > 0 && capturedFrame.height > 0

        if isFrameValid {
            logV("📦 [PopupController] 팝업 프레임 캡처 완료: \(capturedFrame)")
        } else {
            logW("📦 ⚠️ [PopupController] 팝업 프레임 캡처 실패 또는 유효하지 않음: \(capturedFrame)")
        }

        logV("📦 팝업에서 스니펫 선택됨: '\(snippet.abbreviation)' (finalSearchTerm: '\(finalSearchTerm)')")
        logI("📦 wasVisible: \(wasVisible), 콜백 존재: \(callback != nil)")

        // ✅ 팝업 숨김 (앱 비활성화 및 포커스 복귀 시작)
        hidePopup()

        // if wasVisible { // ✅ Issue232 Fix: wasVisible 체크 제거
        if let validCallback = callback {
            // ✅ 포커스 복귀를 적극적으로 대기 (고정 지연 → 폴링 방식)
            let targetApp = AppActivationMonitor.shared.getInputApp()
            let startTime = Date()

            // 초기 300ms 대기 후 폴링 시작 (전환 시간 확보)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.handleSnippetSelectionPolling(
                    targetApp: targetApp,
                    startTime: startTime,
                    callback: validCallback,
                    snippet: snippet,
                    term: finalSearchTerm,
                    frame: isFrameValid ? capturedFrame : nil
                )
            }
        } else {
            logE("📦 ❌ onSnippetSelected 콜백이 nil임")
        }
    }

    private func handleSnippetSelectionPolling(
        targetApp: NSRunningApplication?,
        startTime: Date,
        callback: @escaping (SnippetEntry, String, NSRect?) -> Void,
        snippet: SnippetEntry,
        term: String,
        frame: NSRect?
    ) {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let isReady: Bool = {
            if let target = targetApp, let active = activeApp {
                return active.bundleIdentifier == target.bundleIdentifier
            }
            return activeApp?.bundleIdentifier != Bundle.main.bundleIdentifier
        }()

        if isReady {
            logI(
                "📦 [PopupController] 포커스 복귀 확인: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "nil"))"
            )
            logI("📦 선택 콜백 호출: 스니펫='\(snippet.fileName)', 검색어='\(term)'")
            callback(snippet, term, frame)
            logV("📦 선택 콜백 호출 완료")
        } else if Date().timeIntervalSince(startTime) < 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.handleSnippetSelectionPolling(
                    targetApp: targetApp, startTime: startTime, callback: callback,
                    snippet: snippet, term: term, frame: frame)
            }
        } else {
            logW("📦 ⚠️ [PopupController] 포커스 복귀 대기 타임아웃 - Fallback으로 콜백 실행")
            callback(snippet, term, frame)
            logV("📦 선택 콜백 호출 완료 (Fallback)")
        }
    }

    private func filterCandidates(_ candidates: [SnippetEntry], with searchTerm: String)
        -> [SnippetEntry]
    {
        if searchTerm.isEmpty {
            return candidates
        }

        let settings = SettingsManager.shared.load()
        let triggerKey = settings.defaultSymbol

        let filtered = candidates.filter { candidate in
            let abbreviationWithoutTrigger =
                candidate.abbreviation.hasSuffix(triggerKey)
                ? String(candidate.abbreviation.dropLast(triggerKey.count))
                : candidate.abbreviation

            return abbreviationWithoutTrigger.lowercased().hasPrefix(searchTerm.lowercased())
        }

        logV("📦 후보 필터링: '\(searchTerm)' -> \(filtered.count)개 결과")
        return filtered
    }

    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        hidePopup()  // isVisible = false -> 델리게이트 알림
        popupWindow.cleanup()
        // 플레이스홀더 기능 제거됨
        delegate = nil
    }

    // MARK: - Notification Handlers

    @objc private func handleSearchScopeChange(_ notification: Notification) {
        if let scope = notification.object as? PopupSearchScope {
            logI("📦 [PopupController] 검색 범위 실시간 반영: \(scope)")
            self.currentSearchScope = scope

            // 팝업이 떠있다면 검색어 업데이트 트리거
            if isVisible {
                updateSearchTerm(currentSearchTerm)
            }
        }
    }

    // [Issue383] 보조 윈도우 닫기 처리
    @objc private func handleCloseAuxiliaryWindows(_ notification: Notification) {
        if isVisible {
            logI("📦 [PopupController] 설정창 활성화로 인한 팝업 닫기 (hideApp: false)")
            hidePopup(hideApp: false)
        }
    }

    deinit {
        cleanup()
    }

}
