import Cocoa
import Foundation

/// 앱 활성화 상태 변경을 감지하는 모니터
class AppActivationMonitor {
    static let shared = AppActivationMonitor()

    // MARK: - Properties

    private var isMonitoring = false
    private var currentActiveApp: NSRunningApplication?
    private weak var popupMonitoringTimer: Timer?
    private var isPopupVisible = false
    private var inputApp: NSRunningApplication?  // 스니펫 팝업창 띄운 시점의 입력하던 앱

    // ✅ [Issue583_5] Safety Timeout
    private var popupMonitoringStartTime: Date?
    private let popupMonitoringTimeout: TimeInterval = 300.0  // 5 minutes

    // ✅ Window Monitoring (Issue 392_2)
    private weak var windowMonitoringTimer: Timer?
    private var lastWindowID: CGWindowID?
    private var lastPID: pid_t?
    // MARK: - Callbacks

    private var onAppDeactivated: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 앱 활성화 상태 모니터링 시작
    /// - Parameter onDeactivated: fSnippet이 비활성화될 때 호출될 콜백 (Optional)
    func startMonitoring(onAppDeactivated: (() -> Void)? = nil) {
        // 콜백 업데이트 (nil이면 기존 콜백 유지)
        if let callback = onAppDeactivated {
            self.onAppDeactivated = callback
        }

        guard !isMonitoring else {
            logV("👋 [AppActivationMonitor] 이미 모니터링 중입니다 (콜백 업데이트 완료)")
            return
        }

        self.isMonitoring = true

        // 현재 활성 앱 저장
        currentActiveApp = NSWorkspace.shared.frontmostApplication

        // NSWorkspace 알림 등록 (NSWorkspace.shared.notificationCenter 사용 필수)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // NSApplication 알림 등록 (fSnippet 자체의 활성화/비활성화)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        startWindowMonitoring()

        logV("👋 [AppActivationMonitor] 앱 활성화 모니터링 시작")
    }

    /// 모니터링 중지
    func stopMonitoring() {
        guard isMonitoring else { return }

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        stopPopupMonitoring()
        stopWindowMonitoring()
        isMonitoring = false
        onAppDeactivated = nil
        currentActiveApp = nil
        // ✅ [Issue583_5] 입력 앱 참조 해제
        inputApp = nil

        logV("👋 [AppActivationMonitor] 앱 활성화 모니터링 중지")
    }

    /// 현재 활성 앱이 fSnippet인지 확인
    func isFSnippetActive() -> Bool {
        return NSApplication.shared.isActive
    }

    /// 현재 활성화된 앱 정보 반환
    func getCurrentActiveApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    /// 입력하던 앱 정보 반환 (스니펫 팝업창 띄운 시점의 앱)
    func getInputApp() -> NSRunningApplication? {
        return inputApp
    }

    /// 스니펫 팝업창 표시 상태 설정 및 Timer 기반 모니터링 시작/중지
    func setPopupVisible(_ visible: Bool) {
        logV("👋 [AppActivationMonitor] 스니펫 팝업창 상태 변경: \(isPopupVisible) → \(visible)")

        isPopupVisible = visible

        if visible {
            startPopupMonitoring()
        } else {
            stopPopupMonitoring()
        }
    }

    /// 스니펫 팝업창 표시 중 Timer 기반 앱 전환 모니터링 시작
    private func startPopupMonitoring() {
        if popupMonitoringTimer != nil {
            logW("👋 [AppActivationMonitor] ⚠️ 팝업 모니터링 타이머가 이미 존재함. 기존 타이머 제거 후 재시작.")
            stopPopupMonitoring()
        }

        // 현재 활성 앱을 "입력하던 앱"으로 저장
        inputApp = NSWorkspace.shared.frontmostApplication
        currentActiveApp = inputApp

        // ✅ [Issue583_5] 타임아웃 시작 시간 기록
        popupMonitoringStartTime = Date()

        logV(
            "👋 [AppActivationMonitor] 팝업 모니터링 시작 - 입력하던 앱: \(inputApp?.localizedName ?? "unknown")(\(inputApp?.bundleIdentifier ?? "nil"))"
        )

        // 0.1초마다 앱 상태 확인
        popupMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            self?.checkAppActivationChange()
        }
    }

    /// 스니펫 팝업창 모니터링 중지
    private func stopPopupMonitoring() {
        if popupMonitoringTimer != nil {
            popupMonitoringTimer?.invalidate()
            popupMonitoringTimer = nil
            // ✅ [Issue583_5] 타임아웃 초기화
            popupMonitoringStartTime = nil
            logV("👋 [AppActivationMonitor] 🛑 팝업 모니터링 타이머 중지됨")
        }
    }

    /// Timer 콜백: 앱 전환 감지
    private func checkAppActivationChange() {
        // ✅ [Issue583_5] Safety Timeout Check
        if let startTime = popupMonitoringStartTime,
            Date().timeIntervalSince(startTime) > popupMonitoringTimeout
        {
            logW(
                "👋 [AppActivationMonitor] ⚠️ 팝업 모니터링 타임아웃 발생 (\(popupMonitoringTimeout)초 초과) - 강제 중지"
            )
            stopPopupMonitoring()
            // 팝업이 닫히지 않은 상태일 수 있으므로 닫기 시도 (선택적)
            performDeactivation()
            return
        }

        let newActiveApp = NSWorkspace.shared.frontmostApplication

        // 앱이 변경되었는지 확인
        if let previous = currentActiveApp,
            let current = newActiveApp,
            previous.bundleIdentifier != current.bundleIdentifier
        {

            logI(
                "👋 [AppActivationMonitor] Timer 기반 앱 전환 감지: \(previous.localizedName ?? "unknown")(\(previous.bundleIdentifier ?? "nil")) → \(current.localizedName ?? "unknown")(\(current.bundleIdentifier ?? "nil"))"
            )

            // 입력하던 앱에서 다른 앱으로 전환된 경우 (fSnippet은 제외)
            if let inputAppID = inputApp?.bundleIdentifier,
                current.bundleIdentifier != inputAppID
                    && current.bundleIdentifier != Bundle.main.bundleIdentifier
            {

                logI(
                    "👋 [AppActivationMonitor] 입력하던 앱(\(inputApp?.localizedName ?? "unknown"))에서 다른 앱으로 전환됨 - 팝업 닫기 트리거"
                )
                performDeactivation()
            }

            currentActiveApp = newActiveApp
        }
    }

    // MARK: - Window Monitoring (Polling)

    private func startWindowMonitoring() {
        if windowMonitoringTimer != nil { return }

        logV("👋 [AppActivationMonitor] 윈도우 모니터링(Polling) 시작")

        // 0.5초마다 윈도우 포커스 변경 확인
        windowMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            self?.checkWindowFocusChange()
        }
    }

    private func stopWindowMonitoring() {
        windowMonitoringTimer?.invalidate()
        windowMonitoringTimer = nil
        logV("👋 [AppActivationMonitor] 윈도우 모니터링 중지")
    }

    /// Polling: 윈도우 포커스 변경 감지
    private func checkWindowFocusChange() {
        // ContextUtils를 사용하여 현재 포커스된 윈도우 정보 획득
        // (KeyEventMonitor에서 사용하는 것과 동일한 유틸리티 활용)
        if let currentContext = ContextUtils.shared.getCurrentFocusedWindowID() {
            let currentPID = currentContext.0
            let currentWindowID = currentContext.1
            // ✅ [Issue601] fSnippet 자체의 윈도우 변경(Hidden -> Popup)은 무시
            if currentPID == NSRunningApplication.current.processIdentifier {
                return
            }


            // 초기화 또는 변경 감지
            if lastPID == nil {
                lastPID = currentPID
                lastWindowID = currentWindowID
                return
            }

            // PID가 같고 WindowID가 다르면 "같은 앱 내 윈도우 전환" (PID가 다르면 이미 App Switch Notification으로 처리됨)
            // 하지만 안전을 위해 PID 변경도 감지하여 로깅할 수 있음 (중복 방지 로직 필요)

            if lastWindowID != currentWindowID {
                if lastPID == currentPID {
                    // 같은 앱 내에서 윈도우만 변경됨
                    logI(
                        "👋 🪟 [AppActivationMonitor] 윈도우 전환 감지: ID(\(lastWindowID ?? 0) -> \(currentWindowID)) (PID: \(currentPID))"
                    )

                    // Notification 발송 (KeyEventMonitor 버퍼 클리어용)
                    NotificationCenter.default.post(name: .didChangeActiveWindow, object: nil)
                }

                // 상태 업데이트
                lastPID = currentPID
                lastWindowID = currentWindowID
            }
        }
    }

    // MARK: - Private Methods

    @objc private func handleAppActivation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let activatedApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else {
            logE("👋 [AppActivationMonitor] NSWorkspace 알림에서 앱 정보 추출 실패")
            return
        }

        let previousApp = currentActiveApp
        currentActiveApp = activatedApp

        logI(
            "👋️ [AppActivationMonitor] 앱 활성화 변경: \(previousApp?.localizedName ?? "nil")(\(previousApp?.bundleIdentifier ?? "nil")) → \(activatedApp.localizedName ?? "unknown")(\(activatedApp.bundleIdentifier ?? "unknown"))"
        )

        // 이전 앱이 fSnippet이었는지 확인
        let wasFSnippetActive = previousApp?.bundleIdentifier == Bundle.main.bundleIdentifier
        let isFSnippetActive = activatedApp.bundleIdentifier == Bundle.main.bundleIdentifier

        logV(
            "👋 [AppActivationMonitor] fSnippet 활성화 상태: 이전=\(wasFSnippetActive), 현재=\(isFSnippetActive)"
        )

        // fSnippet이 비활성화되었을 때 (fSnippet → 다른 앱)
        if wasFSnippetActive && !isFSnippetActive {
            logI("👋 [AppActivationMonitor] fSnippet 비활성화 감지 - 다른 앱으로 전환됨, 콜백 호출")
            performDeactivation()
        } else {
            // logTrace("👋 [AppActivationMonitor] fSnippet 상태 변경 없음 - 콜백 호출하지 않음")
        }
    }

    @objc private func handleAppDidBecomeActive() {
        logD("👋 [AppActivationMonitor] fSnippet이 활성화됨")
    }

    // ✅ [Issue474_6] 재시작 예외 플래그
    private var isRestartPending = false

    /// [Issue474_6] 재시작 알림 표시 상태 설정 (Deactive 처리 예외용)
    func setRestartPending(_ pending: Bool) {
        self.isRestartPending = pending
        logV("👋 [AppActivationMonitor] 재시작 대기 상태 변경: \(pending)")
    }

    /// [Issue474_6] 중앙 집중식 비활성화 처리 (예외 로직 적용)
    private func performDeactivation() {
        if isRestartPending {
            logI("👋️ [AppActivationMonitor] 재시작 알림 표시 중 - Deactive 처리 무시 (performDeactivation)")
            return
        }

        logV("👋 [AppActivationMonitor] 비활성화 콜백 실행")
        onAppDeactivated?()
    }

    @objc private func handleAppDidResignActive() {
        logV("👋 [AppActivationMonitor] fSnippet NSApplication 비활성화 이벤트 - 팝업 닫기 트리거")
        performDeactivation()
    }

    // MARK: - Safe Cleanup

    deinit {
        // Singleton이므로 앱 종료 시까지 해제되지 않는 것이 정상이지만,
        // 만약 해제된다면(테스트 등) 리소스를 확실히 정리해야 함
        stopMonitoring()
        logV("👋 [AppActivationMonitor] ♻️ deinit 호출됨 (리소스 정리 완료)")
    }
}
