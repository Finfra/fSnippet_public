import Foundation

extension Notification.Name {
    static let appSettingDidChange = Notification.Name("appSettingDidChange")
}

// MARK: - 앱 설정 모델

struct AppSetting: Codable {
    var version: String
    var lastUpdated: Date
    var description: String?

    var bufferClearKeys: BufferClearConfig
    var tuning: TuningConfig
    var logFilter: LogFilterConfig
    var excludedFiles: [String]  // Issue 538

    static let currentVersion = "2.0"

    static var `default`: AppSetting {
        return AppSetting(
            version: currentVersion,
            lastUpdated: Date(),
            description: "System level settings for fSnippet",
            bufferClearKeys: BufferClearConfig.default,
            tuning: TuningConfig.default,
            logFilter: LogFilterConfig.default,
            excludedFiles: ["_README.md", "z_old", ".DS_Store"]  // Issue 538 Default
        )
    }
}

struct BufferClearConfig: Codable {
    var description: String
    var keys: [String]

    static var `default`: BufferClearConfig {
        return BufferClearConfig(
            description: "Buffer clear keys that reset the abbreviation detection",
            keys: []  // Issue 500_1: 기본값은 비어 있음, 값은 appSetting.json에 의존함.
        )
    }
}

struct TuningConfig: Codable {
    var triggerBiasAux: Int
    var description: String

    static var `default`: TuningConfig {
        return TuningConfig(
            triggerBiasAux: 0,
            description: "Auxiliary bias for deletion length calculation (Developer tuning)"
        )
    }
}

struct LogFilterConfig: Codable {
    var enable: Bool
    var mode: String  // "allow" or "deny"
    var allowList: [String]
    var denyList: [String]
    var description: String

    static var `default`: LogFilterConfig {
        return LogFilterConfig(
            enable: false,
            mode: "allow",
            allowList: [],
            denyList: [],
            description:
                "Log filtering configuration. Mode: 'allow' (only listed) or 'deny' (exclude listed)."
        )
    }
}

// MARK: - AppSettingManager

class AppSettingManager {
    static let shared = AppSettingManager()

    private let jsonFileName = "appSetting.json"
    // Issue126: `dataDirectory` 상수 제거됨. Release 분기에서 사용자 폴더에
    // `_data/` 디렉토리를 자동 생성하던 코드도 함께 폐기. Bundle 리소스만 사용.

    private(set) var setting: AppSetting

    // 성능 캐시
    private var bufferClearCharacterSet: Set<Character> = []
    private var denyListSet: Set<String> = []
    private var allowListSet: Set<String> = []

    private init() {
        self.setting = AppSetting.default
        load()
    }

    // MARK: - 공개 접근자

    var bufferClearKeys: Set<Character> {
        return bufferClearCharacterSet
    }

    var tuning: TuningConfig {
        return setting.tuning
    }

    // MARK: - 로깅 필터

    func shouldLog(file: String) -> Bool {
        guard setting.logFilter.enable else { return true }

        // 경로에서 파일명 추출 (예: "Logger.swift")
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        if setting.logFilter.mode == "allow" {
            // 허용 모드: allowList에 있어야 함
            if allowListSet.contains(fileName) { return true }
            return allowListSet.contains(
                URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent)
        } else {
            // 거부 모드: denyList에 없어야 함
            if denyListSet.contains(fileName) { return false }
            return !denyListSet.contains(
                URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent)
        }
    }

    // MARK: - 지속성 (Persistence)

    func load() {
        guard let url = getJSONFileURL() else {
            save()
            return
        }

        // 파일이 존재하지 않으면 기본값 생성
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.shared.info("⚒️ [AppSettingManager] appSetting.json not found, creating default")
            save()
            refreshCache()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // 전체 새 형식 디코딩 시도
            if let decoded = try? decoder.decode(AppSetting.self, from: data) {
                self.setting = decoded
                // 확인해야 할 경우를 대비해 먼저 캐시 새로고침
                refreshCache()
                Logger.shared.verbose("⚒️ [AppSettingManager] Loaded v\(setting.version) settings")
                NotificationCenter.default.post(name: .appSettingDidChange, object: nil)
                return
            }

            // v1.1 마이그레이션 (BufferClearKeyManager 형식)
            if let legacyDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                Logger.shared.warning("⚒️ [AppSettingManager] Legacy format detected. Migrating...")

                var newSetting = AppSetting.default

                // bufferClearKeys 마이그레이션
                if let bufferClearObj = legacyDict["bufferClearKeys"] as? [String: Any],
                    let keys = bufferClearObj["keys"] as? [String]
                {
                    newSetting.bufferClearKeys.keys = keys
                    // 버전/업데이트 날짜 보존 가능? 아니오, 새 시스템으로 재설정.
                } else if let bufferClearObj = legacyDict["bufferClearCharacters"]
                    as? [String: Any],
                    let chars = bufferClearObj["characters"] as? [String]
                {
                    // 추가 레거시
                    newSetting.bufferClearKeys.keys = chars
                }

                // 다른 필드가 존재했다면 마이그레이션 (현재는 없음)

                self.setting = newSetting
                save()  // 새 형식으로 저장
                refreshCache()
                NotificationCenter.default.post(name: .appSettingDidChange, object: nil)
                return
            }

        } catch {
            Logger.shared.error("⚒️ [AppSettingManager] Failed to load settings: \(error)")
        }
    }

    func save() {
        // Issue126: appSetting.json is a DEBUG-only Bundle resource.
        // Writes are scoped to DEBUG so developers can persist edits to the
        // dev-source path returned by getJSONFileURL(). In Release the call
        // is intentionally a no-op — no user-folder leak.
        #if DEBUG
        guard let url = getJSONFileURL() else { return }

        setting.lastUpdated = Date()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(setting)
            try data.write(to: url)
            Logger.shared.verbose("⚒️ [AppSettingManager] Saved configuration")
            refreshCache()
            NotificationCenter.default.post(name: .appSettingDidChange, object: nil)
        } catch {
            Logger.shared.error("⚒️ [AppSettingManager] Failed to save usage: \(error)")
        }
        #else
        Logger.shared.verbose(
            "⚒️ [AppSettingManager] save() skipped in Release (Issue126 read-only policy)")
        #endif
    }

    // MARK: - 내부 헬퍼

    private func refreshCache() {
        // 버퍼 키
        self.bufferClearCharacterSet = Set(
            setting.bufferClearKeys.keys.compactMap { keyStr in
                // 표준 JSON 디코딩 결과 사용 (Issue 500_1)
                return keyStr.count == 1 ? Character(keyStr) : nil
            })

        // 로그 필터 목록
        self.denyListSet = Set(setting.logFilter.denyList)
        self.allowListSet = Set(setting.logFilter.allowList)
    }

    // 수동 이스케이프 처리 제거됨 (표준 JSON 디코더에 의존)

    /// Issue126: Bundle resource read-only loader.
    ///
    /// In DEBUG builds, the source-tree path is preferred so edits to
    /// `cli/fSnippetCli/_data/appSetting.json` reflect without rebuilding.
    /// In Release builds, only the bundled resource is returned — the user
    /// data folder is never touched, even as a fallback.
    ///
    /// Note: As of 2026-05-15 the Bundle does not actually include the
    /// `_data/appSetting.json` resource (Xcode pbxproj does not list it under
    /// Copy Bundle Resources). This means Release returns nil and
    /// `AppSetting.default` is used in-memory. Restoring the bundled resource
    /// is tracked separately so the policy here remains correct either way.
    private func getJSONFileURL() -> URL? {
        #if DEBUG
        if let resourcePath = Bundle.main.resourcePath {
            let devSourceURL = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("_data/\(jsonFileName)")
            if FileManager.default.fileExists(atPath: devSourceURL.path) {
                Logger.shared.debug("⚒️ [AppSettingManager] Using Dev Source Config: \(devSourceURL.path)")
                return devSourceURL
            }
        }
        #endif

        // Release (and DEBUG fallback): bundled resource only.
        let bundled = Bundle.main.url(forResource: "appSetting", withExtension: "json")
        if bundled == nil {
            Logger.shared.verbose(
                "⚒️ [AppSettingManager] Issue126: bundle resource not found; using in-memory AppSetting.default")
        }
        return bundled
    }

    // ShortcutMgr 통합 제거됨 (알림 기반으로 리팩토링됨)
    // ShortcutMgr.registerBufferClearKeys() 참조
}
