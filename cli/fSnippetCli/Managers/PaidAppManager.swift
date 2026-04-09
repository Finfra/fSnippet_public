import Cocoa

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
    /// - 감지 안 됨 → "Only Support the Paid Version" 토스트
    /// - 감지됨 → paid 앱 실행 → "fSnippet에서 다시 실행해주세요" 알림
    func handlePaidFeature(relativeTo frame: NSRect? = nil) {
        if isInstalled() {
            let launched = launchPaidApp()
            if launched {
                ToastManager.shared.showToast(
                    message: LocalizedStringManager.shared.string("toast.paid_launched"),
                    iconName: "arrow.up.forward.app.fill",
                    duration: 2.0,
                    relativeTo: frame,
                    fontSize: 24
                )
            } else {
                showPaidOnlyToast(relativeTo: frame)
            }
        } else {
            showPaidOnlyToast(relativeTo: frame)
        }
    }

    /// "Only Support the Paid Version" 토스트 표시 (Issue14: 다국어 대응)
    private func showPaidOnlyToast(relativeTo frame: NSRect? = nil) {
        ToastManager.shared.showToast(
            message: LocalizedStringManager.shared.string("toast.paid_only"),
            iconName: "lock.fill",
            relativeTo: frame,
            fontSize: 28
        )
    }
}
