import Cocoa
import UniformTypeIdentifiers

/// paid 앱(fSnippet GUI) 감지 및 실행을 전담하는 매니저
/// - 감지: 설치 여부, 실행 파일 존재 여부
/// - 실행: paid 앱 자동 실행
/// - 안내: paid 전용 기능 시도 시 감지 → 실행 → 알림
class PaidAppManager {
    static let shared = PaidAppManager()

    private let paidBundleID = "kr.finfra.fSnippet"
    private let knownPaths = [
        "/Applications/fSnippet.app",
        "/Applications/_nowage_app/fSnippet.app",
    ]

    // MARK: - 감지

    /// LaunchServices가 반환한 URL이 Release 앱인지 확인 (Xcode DerivedData 빌드 제외)
    private func isReleaseAppURL(_ url: URL) -> Bool {
        let path = url.path
        return !path.contains("Library/Developer") && !path.contains("DerivedData")
    }

    /// paid 앱이 설치되어 있고 실행 가능한지 확인
    /// 압축된 .app은 실행 불가이므로 실제 실행 파일 존재 여부까지 검증
    func isInstalled() -> Bool {
        // 경로 기반 탐지
        for path in knownPaths {
            let executablePath = "\(path)/Contents/MacOS/fSnippet"
            if FileManager.default.fileExists(atPath: executablePath) {
                return true
            }
        }
        // Bundle ID 기반 탐지 (LaunchServices) — DerivedData 빌드 제외
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: paidBundleID),
           isReleaseAppURL(appURL) {
            let executableURL = appURL.appendingPathComponent("Contents/MacOS/fSnippet")
            if FileManager.default.fileExists(atPath: executableURL.path) {
                return true
            }
        }
        return false
    }

    /// paid 앱이 현재 실행 중인지 확인
    func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == paidBundleID }
    }

    // MARK: - 실행

    /// paid 앱 실행 시도. 성공 시 true 반환
    @discardableResult
    func launchPaidApp() -> Bool {
        // Bundle ID로 앱 위치 찾기 — DerivedData 빌드 제외
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: paidBundleID),
           isReleaseAppURL(appURL) {
            let executableURL = appURL.appendingPathComponent("Contents/MacOS/fSnippet")
            guard FileManager.default.fileExists(atPath: executableURL.path) else {
                logW("🏷️ [PaidApp] 실행 파일 없음: \(executableURL.path)")
                return false
            }
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
            logI("🏷️ [PaidApp] paid 앱 실행: \(appURL.path)")
            return true
        }
        // fallback: 알려진 경로에서 직접 열기
        for path in knownPaths {
            let executablePath = "\(path)/Contents/MacOS/fSnippet"
            if FileManager.default.fileExists(atPath: executablePath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                logI("🏷️ [PaidApp] paid 앱 실행 (경로): \(path)")
                return true
            }
        }
        logW("🏷️ [PaidApp] paid 앱을 찾을 수 없음")
        return false
    }

    // MARK: - paidApp 단독 종료 (Issue106)

    /// paidApp만 graceful 종료(cliApp은 잔존). 메뉴바 "Quit fSnippet" 항목용.
    /// `fSnippetCliApp.terminatePaidApp()`(Issue101)와 동일 매커니즘 — NSWorkspace.runningApplications + bundleIdentifier 정확 매칭.
    /// graceful 1초 대기 후 미종료 시 forceTerminate fallback.
    @discardableResult
    func terminatePaidApp() -> Bool {
        let paidApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == paidBundleID
        }
        guard !paidApps.isEmpty else {
            logI("🏷️ [PaidApp] terminate 요청 — 실행 중 paidApp 없음")
            return false
        }

        for app in paidApps {
            logI("🏷️ [PaidApp] paidApp 종료 신호 (PID: \(app.processIdentifier))")
            app.terminate()
        }

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if paidApps.allSatisfy({ $0.isTerminated }) {
                logI("🏷️ [PaidApp] paidApp 정상 종료")
                return true
            }
            usleep(50_000)
        }

        for app in paidApps where !app.isTerminated {
            logW("🏷️ [PaidApp] paidApp graceful 실패 — forceTerminate (PID: \(app.processIdentifier))")
            app.forceTerminate()
        }
        return true
    }

    // MARK: - 자동 기동 동의 (Issue112)

    /// User consent flag — once true, .stopped routing skips the dialog and auto-launches.
    /// Persisted via UserDefaults (key: paidApp.autoLaunchConsent).
    private let autoLaunchConsentKey = "paidApp.autoLaunchConsent"

    var autoLaunchConsent: Bool {
        get { UserDefaults.standard.bool(forKey: autoLaunchConsentKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoLaunchConsentKey) }
    }

    // MARK: - foreground / launch helpers (Issue113)

    /// Bring the running paidApp to the foreground.
    /// URL Scheme alone does not guarantee activation when the app is hidden or in the background.
    private func activatePaidApp() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: paidBundleID)
        if let app = apps.first {
            app.activate(options: [.activateIgnoringOtherApps])
            logI("🏷️ [PaidApp] activate (PID: \(app.processIdentifier))")
        }
    }

    /// Wait for paidApp REST register after launch — strict.
    /// Only PaidAppStateStore.status() is the green light: it guarantees the URL Scheme
    /// handler inside paidApp is wired up. NSWorkspace's `isRunning()` flips true the moment
    /// the process spawns, well before AppDelegate / URL handler init — racing on it caused
    /// the menu-click route to drop URL Schemes (register-arrives-1.3s-after-LS-fallback).
    /// - Parameter timeout: maximum wait, default 5.0s (conservative; first launch ~1.5s)
    /// - Returns: true if registration detected within timeout, false on timeout
    private func waitForPaidAppRegistration(timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if PaidAppStateStore.shared.status() != nil {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        logW("🏷️ [PaidApp] register timeout (\(timeout)s) — openSettings는 LaunchServices 폴백으로 진행")
        return false
    }

    /// Launch paidApp, wait for register/running, then openSettings on the main queue.
    /// Used by both consent-based auto-launch (Issue112) and explicit [열기] click.
    /// Note: activatePaidApp() removed (Issue144) — URL scheme's activates=true handles foreground;
    /// calling activatePaidApp() before URL scheme fires applicationDidBecomeActive which
    /// consumes initialActivationHandled before the scheme arrives, causing settings to be suppressed.
    private func launchAndOpenSettings() {
        guard launchPaidApp() else {
            logW("🏷️ [PaidApp] launch 실패 — settings 열기 중단")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            _ = self.waitForPaidAppRegistration()
            DispatchQueue.main.async {
                PaidAppDetector.openSettings()
            }
        }
    }

    // MARK: - paid 전용 기능 핸들링

    /// paid 전용 기능 시도 시 호출 (paid_cli_protocol §4.2 준수)
    /// Routes via AppStateManager.paidAppStatus (single source of truth, Issue110).
    /// - .notInstall → showPaidOnlyAlert (App Store / Locate / Show Config / Cancel)
    /// - .stopped + autoLaunchConsent==false → showRequirePaidAlert (최초 1회 동의)
    /// - .stopped + autoLaunchConsent==true  → 다이얼로그 생략, launchAndOpenSettings (Issue112)
    /// - .started → activate(foreground) + openSettings (Issue113)
    ///
    /// Issue141: cliApp startup 직후 자동 launch 된 paidApp 의 `paidAppStateChanged`
    /// 알림 도달 전이라도 NSWorkspace 직접 확인으로 fresh 평가하여 race 해소.
    func handlePaidFeature() {
        // Issue141: cached paidAppStatus 의 stale 상태(특히 .stopped) 가 첫 클릭을 consent
        // 다이얼로그/launchAndOpenSettings 우회 경로로 잘못 라우팅하지 않도록 fresh check.
        let freshStatus: PaidAppStatus = {
            if isRunning() { return .started }
            if isInstalled() { return .stopped }
            return .notInstall
        }()
        switch freshStatus {
        case .started:
            // Issue113: explicit activate before URL scheme to guarantee foreground
            // Issue142: wait for paidApp registration before openSettings to ensure 1st channel
            // (bundlePath-routed URL scheme) instead of unreliable LaunchServices fallback.
            // Mirrors launchAndOpenSettings() pattern; waitForPaidAppRegistration returns
            // immediately if already registered.
            activatePaidApp()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                _ = self.waitForPaidAppRegistration()
                DispatchQueue.main.async {
                    PaidAppDetector.openSettings()
                }
            }
        case .stopped:
            if autoLaunchConsent {
                logI("🏷️ [PaidApp] 동의 기반 자동 기동 (Issue112)")
                launchAndOpenSettings()
            } else {
                showRequirePaidAlert()
            }
        case .notInstall:
            showPaidOnlyAlert()
        }
    }

    /// 설정창 직접 열기 — consent 우회 (Issue144)
    /// 단축키/메뉴바 트리거 전용. autoLaunchConsent 무관하게 무조건 settings 진입.
    /// - .started → wait for registration + openSettings (activatePaidApp 생략, URL scheme activates)
    /// - .stopped → launchAndOpenSettings (consent 체크 없이 바로 기동)
    /// - .notInstall → showPaidOnlyAlert
    func openSettings() {
        let freshStatus: PaidAppStatus = {
            if isRunning() { return .started }
            if isInstalled() { return .stopped }
            return .notInstall
        }()
        switch freshStatus {
        case .started:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                _ = self.waitForPaidAppRegistration()
                DispatchQueue.main.async {
                    PaidAppDetector.openSettings()
                }
            }
        case .stopped:
            logI("🏷️ [PaidApp] 설정창 직접 기동 — consent 우회 (Issue144)")
            launchAndOpenSettings()
        case .notInstall:
            showPaidOnlyAlert()
        }
    }

    /// "fSnippet이 필요합니다" 안내 NSAlert (Issue70 도입, Issue112에서 1회 동의 정책으로 확장)
    /// [열기] 클릭 시 autoLaunchConsent=true 저장 후 launchAndOpenSettings() 흐름으로 위임
    private func showRequirePaidAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "fSnippet이 필요합니다"
        alert.informativeText = "이 기능은 fSnippet 앱(유료 버전)에서 사용할 수 있습니다.\nfSnippet을 여시겠습니까?\n\n[열기]를 누르면 다음부터는 자동으로 실행됩니다."
        alert.alertStyle = .informational
        if let appIcon = NSApplication.shared.applicationIconImage {
            alert.icon = appIcon
        }
        alert.addButton(withTitle: "열기")
        alert.addButton(withTitle: "취소")

        if alert.runModal() == .alertFirstButtonReturn {
            // Issue112: persist explicit consent so future .stopped routes skip the dialog
            autoLaunchConsent = true
            logI("🏷️ [PaidApp] 사용자 동의 저장 — 이후 .stopped 시 자동 기동")
            launchAndOpenSettings()
        }
    }

    /// "Only support the paid version" NSAlert 표시
    /// App Store / Locate... / Cancel 3개 버튼 제공
    private func showPaidOnlyAlert() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Only support the paid version"
        alert.informativeText = "This feature requires fSnippet (App Store version).\nYou can get it from the App Store or locate an already installed copy."
        alert.alertStyle = .informational

        // 앱 아이콘 설정
        if let appIcon = NSApplication.shared.applicationIconImage {
            alert.icon = appIcon
        }

        alert.addButton(withTitle: "App Store")
        alert.addButton(withTitle: "Locate...")
        alert.addButton(withTitle: "Show Config in Finder")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            // App Store 페이지 열기
            if let url = URL(string: "macappstore://apps.apple.com/app/fsnippet/id6746205800") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // 파일 선택 패널로 fSnippet.app 찾기
            let panel = NSOpenPanel()
            panel.title = "Select fSnippet.app"
            panel.allowedContentTypes = [.application]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            if panel.runModal() == .OK, let selectedURL = panel.url {
                // 선택한 앱의 Bundle ID 검증
                if let bundle = Bundle(url: selectedURL),
                   bundle.bundleIdentifier == paidBundleID {
                    NSWorkspace.shared.open(selectedURL)
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Invalid application"
                    errorAlert.informativeText = "The selected app is not fSnippet."
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            }
        case .alertThirdButtonReturn:
            // 설정 파일을 Finder에서 보기
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let configPath = homeDir
                .appendingPathComponent("Documents")
                .appendingPathComponent("finfra")
                .appendingPathComponent("fSnippetData")
                .appendingPathComponent("_config.yml")
            if FileManager.default.fileExists(atPath: configPath.path) {
                NSWorkspace.shared.activateFileViewerSelecting([configPath])
            } else {
                // 설정 디렉토리라도 열기
                let configDir = configPath.deletingLastPathComponent()
                if FileManager.default.fileExists(atPath: configDir.path) {
                    NSWorkspace.shared.open(configDir)
                }
            }
        default:
            break
        }
    }
}
