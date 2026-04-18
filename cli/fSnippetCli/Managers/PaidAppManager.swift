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

    // MARK: - paid 전용 기능 핸들링

    /// paid 전용 기능 시도 시 호출
    /// - 감지됨 → paid 앱 실행 → 안내 알림
    /// - 감지 안 됨 → NSAlert (App Store / Locate... / Show Config in Finder / Cancel)
    func handlePaidFeature() {
        if isInstalled() {
            let launched = launchPaidApp()
            if launched {
                let alert = NSAlert()
                alert.messageText = "fSnippet launched"
                alert.informativeText = "fSnippet (paid version) has been launched.\nPlease use the feature from fSnippet."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                NSApplication.shared.activate(ignoringOtherApps: true)
                alert.runModal()
            } else {
                showPaidOnlyAlert()
            }
        } else {
            showPaidOnlyAlert()
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
