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

// MARK: - _setting.yml 로더

/// `_setting.yml`에서 단축키 등 설정을 읽는 유틸리티
/// 위치: ~/Documents/finfra/fSnippetData/_setting.yml
enum SettingYmlLoader {
    /// _setting.yml에서 key-value 딕셔너리를 로드
    static func load() -> [String: String] {
        let appRoot = PreferencesManager.resolveAppRootPath()
        let path = (appRoot as NSString).appendingPathComponent("_setting.yml")

        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            logD("⚙️ [SettingYml] _setting.yml 없음 — 기본값 사용")
            return [:]
        }

        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            // YAML 따옴표 제거
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        logD("⚙️ [SettingYml] 로드 완료: \(result.count)개 항목")
        return result
    }

    /// 특정 키의 값 반환 (없으면 defaultValue)
    static func string(forKey key: String, defaultValue: String = "") -> String {
        return load()[key] ?? defaultValue
    }

    /// _setting.yml이 없으면 기본 파일 생성
    static func ensureDefaultFile() {
        let appRoot = PreferencesManager.resolveAppRootPath()
        let path = (appRoot as NSString).appendingPathComponent("_setting.yml")

        guard !FileManager.default.fileExists(atPath: path) else { return }

        let defaultContent = """
        # fSnippetCli 설정 파일
        # 단축키 형식: ^ = Control, ⌥ = Option, ⌘ = Command, ⇧ = Shift
        settings_hotkey: "^⇧⌘,"
        """

        do {
            try defaultContent.write(toFile: path, atomically: true, encoding: .utf8)
            logI("⚙️ [SettingYml] 기본 _setting.yml 생성: \(path)")
        } catch {
            logE("⚙️ ❌ [SettingYml] _setting.yml 생성 실패: \(error)")
        }
    }
}
