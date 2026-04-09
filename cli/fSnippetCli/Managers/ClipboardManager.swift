import Cocoa
import Combine
import CryptoKit
import Foundation

/// 클립보드 히스토리 뷰 모드 (CL050)
enum ClipboardHistoryViewMode {
    case list  // 포커스가 히스토리 리스트(좌측)에 있음
    case previewView  // 포커스가 프리뷰 창(우측)의 라인 선택 뷰에 있음 (Read-only / Selection)
    case previewEdit  // 포커스가 프리뷰 창(우측)의 텍스트 에디터에 있음 (Editable)
    case deactive  // 히스토리 창이 비활성 상태이거나 숨겨짐 (Event Gating)
}

/// 클립보드 히스토리 관리자 (Issue84)
class ClipboardManager: ObservableObject, ClipboardManagerProtocol {
    static let shared = ClipboardManager()

    // MARK: - 속성

    @Published var chvMode: ClipboardHistoryViewMode = .list

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var monitorTimer: Timer?
    private var maintenanceTimer: Timer?

    // 동적 폴링(Dynamic Polling) 상태
    private var currentPollingInterval: TimeInterval = 0.5
    private let minPollingInterval: TimeInterval = 0.5
    private let maxPollingInterval: TimeInterval = 10.0
    private var eventMonitor: Any?
    private var localEventMonitor: Any?

    // 로깅을 위한 간단한 래퍼

    // MARK: - 생명주기

    private init() {
        self.lastChangeCount = pasteboard.changeCount
        logI("📋 🔥 ClipboardManager INIT (with Fix Check)")  // 업데이트 확인
        // 초기 실행 시 현재 클립보드 체크 (필요 시)
        checkForChanges()

        // 유지보수 타이머 설정 (TTL 집행)
        setupMaintenanceTimer()

        // ✅ Issue: 누수 정리
        cleanUpInternalLeaks()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - 공개 API

    /// 모니터링 시작
    func startMonitoring() {
        stopMonitoring()  // 중복 실행 방지

        setupEventMonitors()
        scheduleNextPoll(interval: minPollingInterval)
        
        logV("📋 클립보드 모니터링 시작 (지능형 동적 폴링)")
    }

    /// 모니터링 중지
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        removeEventMonitors()

        maintenanceTimer?.invalidate()
        maintenanceTimer = nil

        logV("📋 클립보드 모니터링 및 유지보수 중지")
    }

    /// 다음 폴링 타이머 예약 (지능형 Backoff)
    private func scheduleNextPoll(interval: TimeInterval) {
        monitorTimer?.invalidate()
        if currentPollingInterval != interval {
            logV("📋 [DP] 폴링 간격 변경: \(String(format: "%.1f", interval))초")
        }
        currentPollingInterval = interval
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    /// 히스토리 가져오기 (1-based index) - 텍스트 전용 (플레이스홀더용)
    /// - Parameter index: 1이 가장 최근(현재), 2는 그 전...
    func getHistory(at index: Int) -> String? {
        return ClipboardDB.shared.fetchPlainTextAt(historyIndex: index)
    }

    /// 현재 히스토리 전체 반환 (디버깅용 - 실제 UI는 DB에서 직접 페이징 처리 권장)
    func getAllHistory() -> [String] {
        // 임시로 최근 20개 텍스트만 반환
        var results: [String] = []
        for i in 1...20 {
            if let text = getHistory(at: i) {
                results.append(text)
            }
        }
        return results
    }

    /// 보존 정책(TTL) 강제 집행
    func runMaintenanceNow() {
        performMaintenance()
    }

    /// 클립보드로 항목 복사
    func copyToPasteboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case "plain_text":
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        case "image":
            if let blobPath = item.blobPath, let blobsDir = ClipboardDB.shared.getBlobsDir() {
                let fileURL = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobPath)
                if let image = NSImage(contentsOf: fileURL) {
                    pasteboard.writeObjects([image])
                }
            }
        case "file_list":
            if let json = item.filelistJson,
                let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8))
            {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        default:
            // 기타 형식에 대한 폴백
            if let text = item.text {
                pasteboard.setString(text, forType: .string)
            }
        }

        logV("📋 [Clipboard] Copied item to pasteboard: \(item.kind)")
    }

    /// 텍스트 복사 (부분 복사 등)
    func copyToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logV("📋 [Clipboard] Copied text to pasteboard")
    }

    // MARK: - 비공개 메서드

    private func checkForChanges() {
        // 1. 일시 중지 여부 확인
        if PreferencesManager.shared.bool(forKey: "history.isPaused", defaultValue: false) {
            scheduleNextPoll(interval: currentPollingInterval)
            return
        }

        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount

            // 데이터 수집 파이프라인 (비동기 처리)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processCurrentPasteboard()
            }
            // 변경 감지 시 폴링 주기 즉시 최소화 (0.5초)
            scheduleNextPoll(interval: minPollingInterval)
        } else {
            // 변경 없음: 폴링 주기 점진적 증가 (Backoff, 최대 10초)
            let nextInterval = min(currentPollingInterval * 1.5, maxPollingInterval)
            scheduleNextPoll(interval: nextInterval)
        }
    }

    private func processCurrentPasteboard() {
        // 백그라운드 스레드에서 페이스트보드 읽기 (주의: NSPasteboard는 Thread-Safe하지만, 대량 데이터 읽기는 무거울 수 있음)
        // 메인 스레드 블로킹 방지

        let types = pasteboard.types ?? []
        // 기본 설정 접근은 보통 빠르지만 안전을 위해
        let prefs = PreferencesManager.shared

        // CL060: 소스 앱 캡처 (NSWorkspace를 위해 메인 스레드 UI 접근 필요)
        var appBundle: String? = nil
        DispatchQueue.main.sync {
            appBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }

        // 1. File List (가장 우선순위 높게 취급 - Finder 복사 등)
        if types.contains(.fileURL) {
            let enabled = prefs.bool(forKey: "history.enable.fileLists", defaultValue: true)
            if enabled,
                let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
            {
                let paths = urls.map { $0.path }
                if !paths.isEmpty {
                    addFileListToHistory(paths, appBundle: appBundle)
                    return  // 파일 리스트로 처리했으면 종료
                }
            }
        }

        // 2. 이미지
        if types.contains(.tiff) || types.contains(.png) {
            let enabled = prefs.bool(forKey: "history.enable.images", defaultValue: true)
            if enabled, let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png)
            {
                addImageToHistory(data, appBundle: appBundle)
                return
            }
        }

        // 3. Plain Text (가장 일반적)
        if let content = pasteboard.string(forType: .string) {
            let enabled = prefs.bool(forKey: "history.enable.plainText", defaultValue: true)
            if enabled {
                addTextToHistory(content, appBundle: appBundle)
            }
        }
    }

    // MARK: - 핸들러

    private func addTextToHistory(_ content: String, appBundle: String? = nil) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        let hash = generateHash(for: content)

        let moveDuplicates = PreferencesManager.shared.bool(
            forKey: "history.moveDuplicatesToTop", defaultValue: true)

        if moveDuplicates {
            if let existingId = ClipboardDB.shared.findIdByHash(hash: hash) {
                ClipboardDB.shared.updateTimestamp(id: existingId)
                logD("📋 중복 텍스트 최상단 이동 (id: \(existingId))")
                return
            }
        } else {
            // moveDuplicates가 false인 경우: '연속'된 동일 항목만 무시 (a > b > a 허용)
            if ClipboardDB.shared.getLatestHash() == hash {
                logD("📋 연속된 중복 텍스트 무시")
                return
            }
        }

        // ✅ Issue624: 내부 클래스 이름 및 민감한 디버그 문자열 차단
        // 수정: 부분 일치(.contains)로 차단할 경우 'fSnippet'이 포함된 일반 텍스트나 로그를 복사할 수 없는 문제 발생
        // 정확히 일치하는 경우에만 차단하도록 기준 강화
        let leakKeywords = ["ShortcutMgr", "fSnippet"]
        if leakKeywords.contains(content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            logW("📋 [Security] Blocked internal string leak (Exact match): \(content)")
            return
        }

        let item = ClipboardItem(
            id: nil,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: "plain_text",
            text: content,
            blobPath: nil,
            filelistJson: nil,
            uti: "public.utf8-plain-text",
            sizeBytes: Int64(content.utf8.count),
            hash: hash,
            pinned: 0,
            appBundle: appBundle
        )
        ClipboardDB.shared.insertItem(item)
    }

    /// ✅ Issue: 유출된 내부 문자열 히스토리에서 제거
    func cleanUpInternalLeaks() {
        logI("📋 🔥 Checking for internal leaks...")
        let leakedStrings = ["ShortcutMgr", "fSnippet"]
        for leak in leakedStrings {
            let hash = generateHash(for: leak)
            if let id = ClipboardDB.shared.findIdByHash(hash: hash) {
                ClipboardDB.shared.deleteItem(id: id)
                logI("📋 [Maintenance] Removed leaked internal string: '\(leak)' (ID: \(id))")
            }
        }
    }

    private func addImageToHistory(_ data: Data, appBundle: String? = nil) {
        let hash = generateHash(for: data)

        let moveDuplicates = PreferencesManager.shared.bool(
            forKey: "history.moveDuplicatesToTop", defaultValue: true)

        if moveDuplicates {
            if let existingId = ClipboardDB.shared.findIdByHash(hash: hash) {
                ClipboardDB.shared.updateTimestamp(id: existingId)
                logD("📋 중복 이미지 최상단 이동 (id: \(existingId))")
                return
            }
        } else {
            if ClipboardDB.shared.getLatestHash() == hash {
                logD("📋 연속된 중복 이미지 무시")
                return
            }
        }

        // 블랍 저장 (저장 실패 시 무시)
        guard let blobFolder = ClipboardDB.shared.getBlobsDir() else { return }
        let fileName = "\(hash).png"  // 해시를 파일명으로 사용 (PNG 포맷으로 통일하거나 원본 유지)
        let filePath = URL(fileURLWithPath: blobFolder).appendingPathComponent(fileName)

        do {
            try data.write(to: filePath)

            let item = ClipboardItem(
                id: nil,
                createdAt: Int64(Date().timeIntervalSince1970),
                kind: "image",
                text: nil,
                blobPath: fileName,  // 상대 경로 저장
                filelistJson: nil,
                uti: "public.png",
                sizeBytes: Int64(data.count),
                hash: hash,
                pinned: 0,
                appBundle: appBundle
            )
            ClipboardDB.shared.insertItem(item)
        } catch {
            logE("📋 ❌ [Clipboard] Failed to save image blob: \(error)")
        }
    }

    private func addFileListToHistory(_ paths: [String], appBundle: String? = nil) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: paths, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        let hash = generateHash(for: jsonString)

        let moveDuplicates = PreferencesManager.shared.bool(
            forKey: "history.moveDuplicatesToTop", defaultValue: true)

        if moveDuplicates {
            if let existingId = ClipboardDB.shared.findIdByHash(hash: hash) {
                ClipboardDB.shared.updateTimestamp(id: existingId)
                logD("📋 중복 파일리스트 최상단 이동 (id: \(existingId))")
                return
            }
        } else {
            if ClipboardDB.shared.getLatestHash() == hash {
                logD("📋 연속된 중복 파일리스트 무시")
                return
            }
        }

        let item = ClipboardItem(
            id: nil,
            createdAt: Int64(Date().timeIntervalSince1970),
            kind: "file_list",
            text: nil,
            blobPath: nil,
            filelistJson: jsonString,
            uti: "public.file-url",
            sizeBytes: Int64(jsonString.utf8.count),
            hash: hash,
            pinned: 0,
            appBundle: appBundle
        )
        ClipboardDB.shared.insertItem(item)
    }

    // MARK: - 유틸리티

    private func generateHash(for string: String) -> String {
        let data = Data(string.utf8)
        return generateHash(for: data)
    }

    private func generateHash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 유지보수 (TTL)

    private func setupMaintenanceTimer() {
        maintenanceTimer?.invalidate()

        // 1. 즉시 실행 (백그라운드)
        DispatchQueue.global(qos: .background).async {
            self.performMaintenance()
        }

        // 2. 6시간마다 실행 (21600초)
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) {
            [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.performMaintenance()
            }
        }

        logV("📋 [Clipboard] 유지보수(TTL) 타이머 설정됨 (6h)")
    }

    private func performMaintenance() {
        let prefs = PreferencesManager.shared

        let textDays: Int = prefs.get("history.retentionDays.plainText") ?? 90
        let imageDays: Int = prefs.get("history.retentionDays.images") ?? 7
        let fileListDays: Int = prefs.get("history.retentionDays.fileLists") ?? 30

        logI("📋 [Clipboard] 보존 정책 집행 시작 (T:\(textDays)d, I:\(imageDays)d, F:\(fileListDays)d)")

        ClipboardDB.shared.applyRetentionPolicy(
            textDays: textDays,
            imageDays: imageDays,
            fileListDays: fileListDays
        )
    }

    // MARK: - 복사/붙여넣기 단축키 모니터링 (동적 폴링 즉시 반응)

    private func setupEventMonitors() {
        let mask: NSEvent.EventTypeMask = .keyDown

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommand = flags.contains(.command)
            let isShift = flags.contains(.shift)
            let isControl = flags.contains(.control)

            // 일반적인 복사/잘라내기 키캡:
            // C (keyCode: 8), X (keyCode: 7)
            // Insert (keyCode: 114)
            var isCopyAction = false

            if isCommand && (event.keyCode == 8 || event.keyCode == 7) {  // Cmd+C, Cmd+X
                isCopyAction = true
            } else if isShift && event.keyCode == 114 {  // Shift+Insert
                isCopyAction = true
            } else if isControl && event.keyCode == 114 {  // Ctrl+Insert
                isCopyAction = true
            }

            if isCopyAction {
                // 복사 단축키 감지 시 즉시 0.5초 모드로 복귀하여 빠르게 확인
                logV("📋 [DP] 복사 단축키 감지! 즉각 0.5초 폴링 복귀")
                DispatchQueue.main.async {
                    self.scheduleNextPoll(interval: self.minPollingInterval)
                }
            }
        }

        // 앱 외부에 대해선 Global, 내부에선 Local 모니터
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handler(event)
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}
