import Cocoa

// MARK: - 설정 윈도우 관리
// Issue20: 유료 버전(fSnippet GUI 앱) 감지 후 분기 처리

class SettingsWindowManager: NSObject {
    static let shared = SettingsWindowManager()

    var isPopupActiveProvider: (() -> Bool)?
    var dismissPopupsProvider: (() -> Void)?

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// 설정 열기 — PaidAppManager에 위임
    func showSettings() {
        PaidAppManager.shared.handlePaidFeature()
    }

    func hideSettings() {}

    var isSettingsVisible: Bool { false }

    // MARK: - 팝업 임시 숨김/복원 (Stub)

    private(set) var isTemporarilyHiddenByPopup = false

    func temporarilyHide() {}

    func restoreFromTemporaryHide() {}

    @objc func toggleSettings() {
        showSettings()
    }

    // MARK: - 유료 버전 감지

    /// fSnippet GUI 앱(유료 버전)이 설치되어 있고 실행 가능한지 확인
    /// 압축된 .app은 실행 불가이므로 실제 실행 파일 존재 여부까지 검증
    func isPaidVersionInstalled() -> Bool {
        // 경로 기반 탐지: .app 번들 내 실행 파일까지 존재하는지 확인
        let knownPaths = [
            "/Applications/fSnippet.app",
            "/Applications/_nowage_app/fSnippet.app",
        ]
        for path in knownPaths {
            let executablePath = "\(path)/Contents/MacOS/fSnippet"
            if FileManager.default.fileExists(atPath: executablePath) {
                return true
            }
        }
        // Bundle ID 기반 탐지: LaunchServices에서 찾은 경로의 실행 파일도 검증
        // DerivedData(Xcode 빌드) 경로는 제외
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "kr.finfra.fSnippet"),
           !appURL.path.contains("Library/Developer"), !appURL.path.contains("DerivedData") {
            let executableURL = appURL.appendingPathComponent("Contents/MacOS/fSnippet")
            if FileManager.default.fileExists(atPath: executableURL.path) {
                return true
            }
        }
        return false
    }

    // MARK: - 유료 앱 설정 열기

    /// fSnippet GUI 앱을 직접 실행하여 설정창을 연다
    private func openPaidAppSettings() {
        // Bundle ID로 앱 위치 찾기 — DerivedData 빌드 제외
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "kr.finfra.fSnippet"),
           !appURL.path.contains("Library/Developer"), !appURL.path.contains("DerivedData") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
            return
        }
        // fallback: 알려진 경로에서 직접 열기
        let knownPaths = [
            "/Applications/fSnippet.app",
            "/Applications/_nowage_app/fSnippet.app",
        ]
        for path in knownPaths {
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                return
            }
        }
        logW("🪟 [Settings] 유료 앱 경로를 찾을 수 없음")
    }
}

// MARK: - Preferences Protocol

protocol PreferencesController {
    func showPreferences()
    func hidePreferences()
    var isPreferencesVisible: Bool { get }
}

extension SettingsWindowManager: PreferencesController {
    func showPreferences() { showSettings() }
    func hidePreferences() { hideSettings() }
    var isPreferencesVisible: Bool { isSettingsVisible }
}

// NOTE: _setting.yml 로더(SettingYmlLoader)는 제거됨 — 모든 설정은 _config.yml SSOT
// (PreferencesManager 단일 경로). 설정창 단축키는 _config.yml의 settings.hotkey 사용.
