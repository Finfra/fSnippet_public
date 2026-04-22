import CoreGraphics
import Foundation

/// YAML 기반 설정 파일 관리 클래스 (UserDefaults 대체)
/// 위치: ~/Documents/finfra/fSnippet/preferences/_config.yml
class PreferencesManager: PreferencesManagerProtocol {
    static let shared = PreferencesManager()

    private let textQueue = DispatchQueue(
        label: "com.nowage.fSnippet.PreferencesManager", attributes: .concurrent)
    private var cachedConfig: [String: Any] = [:]

    // ✅ 설정 로드 상태
    private var _isConfigLoaded: Bool = false
    var isConfigLoaded: Bool {
        return textQueue.sync { _isConfigLoaded }
    }

    // Issue350: 텍스트 끝을 기준으로 한 @cursor의 최대 거리
    var cursorMaxDistance: Int {
        return get("cursor_max_distance") ?? 100
    }

    /// Issue14: 현재 설정된 언어 코드 (config의 원본 값: "ko", "en", "system" 등; 구형 "kr"은 자동 변환)
    var language: String {
        return get("language") ?? "system"
    }

    /// 환경변수 `fSnippetCli_config` → 기본 경로 순으로 appRootPath 결정
    static func resolveAppRootPath() -> String {
        let envKey = "fSnippetCli_config"
        if let envPath = ProcessInfo.processInfo.environment[envKey], !envPath.isEmpty {
            return envPath.hasPrefix("~")
                ? envPath.replacingOccurrences(of: "~", with: "/Users/\(NSUserName())")
                : envPath
        }
        return "/Users/\(NSUserName())/Documents/finfra/fSnippetData"
    }

    // 기본 경로 설정 (URL 기반)
    private var appBaseURL: URL {
        // Issue 192: Sandbox Container 문제 회피를 위해 명시적 경로 사용
        // 번들ID별로 독립 경로 사용: ~/Documents/finfra/fSnippet/<bundleId> 또는 ~/Documents/finfra/<bundleId>

        // Source of Truth 우선순위: 환경변수 → 기본 경로
        let targetPath = Self.resolveAppRootPath()

        return URL(fileURLWithPath: targetPath)
    }

    private var preferencesURL: URL { return appBaseURL.appendingPathComponent("preferences") }
    // Issue333: Rename config.yaml -> _config.yml
    var configURL: URL { return appBaseURL.appendingPathComponent("_config.yml") }

    // 레거시 지원
    var legacyConfigURL: URL { return appBaseURL.appendingPathComponent("config.yaml") }

    private init() {
        // 앱 시작 시 디렉토리 생성 및 로드
        logV("⚙️ [PreferencesManager] Init started")
        ensureDirectoriesExist()
        loadConfig()
    }

    /// 외부에서 강제로 구조 생성 요청 (Public - Sync)
    func ensureStructureSync() {
        // 동기적으로 디렉토리 및 파일 생성 보장
        textQueue.sync {
            self.ensureDirectoriesExist()

            // Issue333: Check for legacy config.yaml and migrate if needed
            if !FileManager.default.fileExists(atPath: self.configURL.path) {
                if FileManager.default.fileExists(atPath: self.legacyConfigURL.path) {
                    print("🚀 [Preference] Legacy config.yaml 감지 -> _config.yml로 마이그레이션")
                    do {
                        try FileManager.default.moveItem(
                            at: self.legacyConfigURL, to: self.configURL)
                        logI("⚙️ [Preference] config.yaml -> _config.yml 이름 변경 완료")
                        logI("⚙️ [Preference] Legacy config.yaml -> _config.yml 마이그레이션 완료")
                    } catch {
                        logE("⚙️ ❌ [Preference] config.yaml 마이그레이션 실패: \(error)")
                    }
                }
            }

            // 설정 파일이 없으면 생성
            if !FileManager.default.fileExists(atPath: self.configURL.path) {
                logV("⚙️ [Preference] Config 파일 생성 시작 (Sync)")
                if self.copyConfigFromBundle() {
                    self.loadConfigInternal()  // 파일에서 로드
                } else {
                    self.cachedConfig = self.getDefaults()  // 실패 시 하드코딩 기본값
                    self.saveConfigInternal()
                }
                logI("⚙️ [Preference] Config 파일 생성 완료 (Sync)")
            } else {
                logI("⚙️ ℹ️ [Preference] Config 파일 이미 존재함 (Sync)")
            }

            // Issue 474_3: 규칙 파일(_rule.yml) 자동 생성 (Alert 중복 방지)
            let ruleURL = self.appBaseURL.appendingPathComponent("snippets").appendingPathComponent(
                "_rule.yml")
            if !FileManager.default.fileExists(atPath: ruleURL.path) {
                logV("⚙️ [Preference] Rule 파일 생성 시작 (Sync)")
                if self.copyRuleFromBundle(to: ruleURL) {
                    logI("⚙️ [Preference] Rule 파일 생성 완료 (Sync)")
                } else {
                    logE("⚙️ ❌ [Preference] Rule 파일 생성 실패 (Sync)")
                }
            }

            // Issue 192/474_3: Import 규칙 파일(_rule_for_import.yml)을 snippets에 자동 생성
            let ruleForImportURL = self.appBaseURL.appendingPathComponent("snippets")
                .appendingPathComponent("_rule_for_import.yml")
            if !FileManager.default.fileExists(atPath: ruleForImportURL.path) {
                logV("⚙️ [Preference] Rule for Import 파일 생성 시작 (Sync)")
                if self.copyRuleForImportFromBundle(to: ruleForImportURL) {
                    logI("⚙️ [Preference] Rule for Import 파일 생성 완료 (Sync)")
                } else {
                    logE("⚙️ ❌ [Preference] Rule for Import 파일 생성 실패 (Sync)")
                }
            }
        }
    }

    /// 외부에서 강제로 구조 생성 요청 (Public - Async)
    func ensureStructure() {
        textQueue.async(flags: .barrier) {
            self.ensureDirectoriesExist()
            // 설정 파일이 없으면 생성
            if !FileManager.default.fileExists(atPath: self.configURL.path) {
                if self.copyConfigFromBundle() {
                    self.loadConfigInternal()
                } else {
                    self.cachedConfig = self.getDefaults()
                    self.saveConfigInternal()
                }
            }

            // Issue 474_3: 규칙 파일 비동기 확인
            let ruleURL = self.appBaseURL.appendingPathComponent("snippets").appendingPathComponent(
                "_rule.yml")
            if !FileManager.default.fileExists(atPath: ruleURL.path) {
                _ = self.copyRuleFromBundle(to: ruleURL)
            }

            // Issue 192/474_3: Import 규칙 파일 비동기 확인
            let ruleForImportURL = self.appBaseURL.appendingPathComponent("snippets")
                .appendingPathComponent("_rule_for_import.yml")
            if !FileManager.default.fileExists(atPath: ruleForImportURL.path) {
                _ = self.copyRuleForImportFromBundle(to: ruleForImportURL)
            }
        }
    }

    /// 필요한 디렉토리 구조 생성
    private func ensureDirectoriesExist() {
        let fileManager = FileManager.default
        let dirs = [
            appBaseURL, appBaseURL.appendingPathComponent("snippets"),
            appBaseURL.appendingPathComponent("logs"),
        ]

        logV("⚙️ [Preference] 디렉토리 구조 확인 및 생성 시작: \(appBaseURL.path)")

        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                do {
                    try fileManager.createDirectory(
                        at: dir, withIntermediateDirectories: true, attributes: nil)
                    logV("⚙️ [Preference] 디렉토리 생성 성공: \(dir.path)")
                    logV("⚙️ [Preference] 디렉토리 생성 성공: \(dir.path)")
                } catch {
                    logE("⚙️ ❌ [Preference] 디렉토리 생성 실패: \(dir.path), error=\(error)")
                }
            } else {
                logI("⚙️ ℹ️ [Preference] 디렉토리 이미 존재함: \(dir.path)")
            }
        }
    }

    /// 앱 번들에서 기본 설정 파일 복사
    private func copyConfigFromBundle() -> Bool {
        // Issue333: _config.yml을 먼저 검색하고, 필요한 경우 config.yaml로 폴백 (안전성 위해)
        var bundleURL = Bundle.main.url(forResource: "_config", withExtension: "yml")

        if bundleURL == nil {
            bundleURL = Bundle.main.url(forResource: "config", withExtension: "yaml")
        }

        guard let validBundleURL = bundleURL else {
            logW("⚙️ ⚠️ [Preference] 번들 내 설정을 찾을 수 없음. 하드코딩 기본값 사용.")
            logW("⚙️ ⚠️ [Preference] 번들 내 설정(_config.yml 또는 config.yaml)을 찾을 수 없음.")
            return false
        }

        do {
            try FileManager.default.copyItem(at: validBundleURL, to: configURL)
            logI("⚙️ [Preference] 번들 설정 파일 복사 완료")
            logV("⚙️ [Preference] 번들 설정 파일 복사 완료")
            return true
        } catch {
            logE("⚙️ ❌ [Preference] 설정 파일 복사 실패: \(error)")
            return false
        }
    }

    /// 앱 번들에서 기본 규칙 파일 복사 (Issue 474_3)
    private func copyRuleFromBundle(to destinationURL: URL) -> Bool {
        let fileManager = FileManager.default
        // RuleManager는 "yml"을 사용하므로 거기서 사용법 확인.
        guard let bundleURL = Bundle.main.url(forResource: "_rule", withExtension: "yml") else {
            logW("⚙️ ⚠️ [Preference] 번들 내 _rule.yml을 찾을 수 없음.")
            return false
        }

        do {
            try fileManager.copyItem(at: bundleURL, to: destinationURL)
            logV("⚙️ [Preference] 번들 규칙 파일 복사 완료")
            return true
        } catch {
            logE("⚙️ ❌ [Preference] 규칙 파일 복사 실패: \(error)")
            return false
        }
    }

    /// 앱 번들에서 Import용 기본 규칙 파일 복사
    private func copyRuleForImportFromBundle(to destinationURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard let bundleURL = Bundle.main.url(forResource: "_rule_for_import", withExtension: "yml")
        else {
            logW("⚙️ ⚠️ [Preference] 번들 내 _rule_for_import.yml을 찾을 수 없음.")
            return false
        }

        do {
            try fileManager.copyItem(at: bundleURL, to: destinationURL)
            logV("⚙️ [Preference] 번들 _rule_for_import 파일 복사 완료")
            return true
        } catch {
            logE("⚙️ ❌ [Preference] _rule_for_import 파일 복사 실패: \(error)")
            return false
        }
    }

    /// 설정 로드 (외부 호출용)
    func loadConfig() {
        textQueue.async(flags: .barrier) {
            self.loadConfigInternal()
        }
    }

    // YAML 대신 UserDefaults에 저장해야 하는 키들
    private let externalStorageKeys: Set<String> = ["snippet_base_path_bookmark", "debug_logging"]

    /// 설정 로드 (내부용 - 큐 이미 진입 상태 가정)
    private func loadConfigInternal() {
        let fileManager = FileManager.default
        let path = self.configURL.path

        var configToLoad: [String: Any] = [:]

        // 1. YAML 파일 로드
        if fileManager.fileExists(atPath: path) {
            do {
                let content = try String(contentsOf: self.configURL, encoding: .utf8)
                let parsed = self.parseYAML(content)
                // 기본값과 병합 (파일에 있는 값이 우선)
                configToLoad = self.getDefaults().merging(parsed) { (_, new) in new }

                // 특정 디버그
                if let loadedTrigger = configToLoad["snippet_trigger_key"] {
                    logV(
                        "⚙️ [Preference] Config Loaded snippet_trigger_key: '\(loadedTrigger)' (Type: \(type(of: loadedTrigger)))"
                    )
                } else if let legacyTrigger = configToLoad["snippet_default_symbol"] {  // 레거시 확인
                    logV(
                        "⚙️ [Preference] Config Loaded Legacy snippet_default_symbol: '\(legacyTrigger)'"
                    )
                } else {
                    logW("⚙️ 🚀 [Preference] 설정에 snippet_trigger_key 누락! 기본값 사용.")
                }

                logV("⚙️ [Preference] 설정 로드 완료: \(path)")
                logV("⚙️ [Preference] 설정 로드 완료 (\(configToLoad.count) keys)")

                self._isConfigLoaded = true

                // ✅ 리스너에게 설정 준비 완료 알림 (Issue: TriggerKeyManager와 경쟁 상태)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .preferencesDidLoadConfig, object: nil)
                    logV("⚙️ [Preference] Posted .preferencesDidLoadConfig")
                }
            } catch {
                logE("⚙️ ❌ [Preference] 설정 로드 실패: \(error)")
                configToLoad = self.getDefaults()  // 실패 시 기본값 fallback
            }
        } else {
            logI("⚙️ ℹ️ [Preference] 설정 파일이 없음. 기본값 사용 로직 진입: \(path)")
            logI("⚙️ ℹ️ [Preference] 설정 파일이 없음. 기본값(번들 or 하드코딩)으로 생성합니다.")

            if self.copyConfigFromBundle() {
                // 복사 성공 시 재귀 호출로 로드
                self.loadConfigInternal()
                return
            } else {
                // 복사 실패 시 하드코딩 기본값 사용
                configToLoad = self.getDefaults()
                self.cachedConfig = configToLoad
                self.saveConfigInternal()  // 파일 생성
                return
            }
        }

        // 2. External Storage (UserDefaults) 통합 및 마이그레이션
        let defaults = UserDefaults.standard
        var migrationOccurred = false

        for key in externalStorageKeys {
            let udValue = defaults.object(forKey: key)
            let yamlValue = configToLoad[key]

            if let udValue = udValue {
                // Case A: UserDefaults에 값이 있음 -> Source of Truth
                configToLoad[key] = udValue
            } else if let yamlValue = yamlValue {
                // Case B: UserDefaults엔 없고 YAML엔 있음 -> 마이그레이션 대상
                defaults.set(yamlValue, forKey: key)
                logI("⚙️ [Preference] 마이그레이션: '\(key)'를 YAML -> UserDefaults로 이동")
                migrationOccurred = true
                configToLoad[key] = yamlValue
            }
        }

        // Issue 290: Rename Migration (snippet_default_symbol -> snippet_trigger_key)
        if let legacyValue = configToLoad["snippet_default_symbol"] {
            if configToLoad["snippet_trigger_key"] == nil {
                configToLoad["snippet_trigger_key"] = legacyValue
                logI("⚙️ [Preference] 마이그레이션: 'snippet_default_symbol' -> 'snippet_trigger_key'")
                migrationOccurred = true
            }
            // 레거시 키 제거
            configToLoad.removeValue(forKey: "snippet_default_symbol")
            if !migrationOccurred { migrationOccurred = true }  // 저장 발생 보장하여 이전 키 제거
        }

        self.cachedConfig = configToLoad

        // 3. 마이그레이션 발생 시 파일 재저장 (YAML에서 키 제거됨)
        if migrationOccurred {
            self.saveConfigInternal()
            logI("⚙️ [Preference] 마이그레이션 후 설정 파일 정리 완료")
        }
    }

    /// 설정 저장 (내부용)
    private func saveConfigInternal() {
        // 1. External Storage Keys는 UserDefaults에 별도 저장
        let defaults = UserDefaults.standard
        for key in externalStorageKeys {
            if let value = cachedConfig[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        // 2. YAML 직렬화 및 저장 (External Keys 제외됨)
        let content = serializeYAML(cachedConfig)
        do {
            try content.write(to: configURL, atomically: true, encoding: .utf8)
            try content.write(to: configURL, atomically: true, encoding: .utf8)
            logV("⚙️ [Preference] _config.yml 저장 완료 (\(cachedConfig.count) keys)")
        } catch {
            logE("⚙️ ❌ [Preference] 설정 파일 쓰기 실패: \(error)")
        }
    }

    /// 공개 Setter (외부 호출용)
    func set(_ value: Any?, forKey key: String) {
        textQueue.async(flags: .barrier) {
            if let val = value {
                self.cachedConfig[key] = val
            } else {
                self.cachedConfig.removeValue(forKey: key)
            }
            self.saveConfigInternal()
        }
    }

    /// 공개 Getter
    func get<T>(_ key: String) -> T? {
        return textQueue.sync {
            let val = cachedConfig[key]
            if let typedVal = val as? T {
                return typedVal
            }

            // 타입 캐스팅 실패 시 유연한 처리 (특히 Bool/Int 간의 혼용)
            if T.self == Bool.self {
                if let intVal = val as? Int {
                    return (intVal != 0) as? T
                }
                if let strVal = val as? String {
                    let lowered = strVal.lowercased()
                    if lowered == "true" || lowered == "yes" || lowered == "1" { return true as? T }
                    if lowered == "false" || lowered == "no" || lowered == "0" {
                        return false as? T
                    }
                }
            } else if T.self == Int.self {
                if let boolVal = val as? Bool {
                    return (boolVal ? 1 : 0) as? T
                }
                if let strVal = val as? String, let intVal = Int(strVal) {
                    return intVal as? T
                }
                // Issue 355: Double -> Int 변환 (예: 460.0 -> 460)
                if let doubleVal = val as? Double {
                    return Int(doubleVal) as? T
                }
            } else if T.self == Double.self {
                // Issue 355: Int -> Double 변환 (예: 350 -> 350.0)
                if let intVal = val as? Int {
                    return Double(intVal) as? T
                }
                if let floatVal = val as? Float {
                    return Double(floatVal) as? T
                }
                if let strVal = val as? String, let doubleVal = Double(strVal) {
                    return doubleVal as? T
                }
            }

            return nil
        }
    }

    /// 여러 설정을 한 번에 업데이트하고 파일 저장은 1회만 수행 (Batch Update)
    /// - Parameter block: 설정 딕셔너리를 수정하는 클로저. inout 파라미터로 제공됨.
    /// 여러 설정을 한 번에 업데이트하고 파일 저장은 1회만 수행 (Batch Update)
    /// - Parameter block: 설정 딕셔너리를 수정하는 클로저. inout 파라미터로 제공됨.
    func batchUpdate(_ block: @escaping (inout [String: Any]) -> Void) {
        textQueue.async(flags: .barrier) {
            // 1. 메모리 상의 설정 일괄 수정
            block(&self.cachedConfig)

            // 2. 파일 저장은 1회만 수행
            self.saveConfigInternal()
            logV("⚙️ [Preference] Batch Update & Save Completed")

            // Issue 583_9: 알림 발송 (RuleManager 등 캐시 무효화용)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .preferencesDidUpdate, object: nil)
            }
        }
    }

    /// 기본값이 있는 String Getter
    func string(forKey key: String, defaultValue: String = "") -> String {
        return get(key) ?? defaultValue
    }

    /// 기본값이 있는 Bool Getter
    func bool(forKey key: String, defaultValue: Bool = false) -> Bool {
        // get<Bool>이 내부적으로 유연하게 처리하므로 그대로 사용
        return get(key) ?? defaultValue
    }

    // MARK: - 기본값

    private func getDefaults() -> [String: Any] {
        let defaults = UserDefaults.standard

        // 1. UserDefaults 값 우선 사용 (Issue 192: plist to yaml)
        let snippetsPath =
            defaults.string(forKey: "snippet_base_path")
            ?? appBaseURL.appendingPathComponent("snippets").path
        let logLevel = defaults.string(forKey: "log_level") ?? "info"
        let startAtLogin = defaults.bool(forKey: "start_at_login")
        let hideMenuBar = defaults.bool(forKey: "hide_menu_bar_icon")
        let showNotifications = defaults.bool(forKey: "show_notifications")
        let debugLogging = defaults.bool(forKey: "debug_logging")  // 기본값 false

        return [
            "snippet_base_path": snippetsPath,
            "log_level": logLevel,
            "start_at_login": startAtLogin,
            "hide_menu_bar_icon": hideMenuBar,
            "show_notifications": showNotifications,
            "play_ready_sound": false,
            "debug_logging": debugLogging,
            "key_logging": false,  // Issue226: 기본값 false
            "performance_monitoring": false,

            // 기본 단축키
            "snippet_trigger_key": "=",
            "snippet_trigger_bias": 0,
            "cursor_max_distance": 10000,  // Issue354: 경고 방지를 위해 제한 증가

            // 팝업
            "snippet_popup_modifier_flags": 1_048_576,  // Command
            "snippet_popup_key_code": 49,  // Space
            "snippet_popup_hotkey": "⌘Space",
            "snippet_popup_search_scope": "abbreviation",  // Issue184 기본값
            "snippet_popup_height": 300.0,  // Issue184 기본값 (Legacy)
            "snippet_popup_rows": 10,  // Issue245 기본값
            "snippet_popup_width": 350.0,  // Issue355 기본값

            // 제외
            "snippet_excluded_files": [".DS_Store"],

            // 클립보드 히스토리 기본값 (CL002)
            "history.enable.plainText": true,
            "history.retentionDays.plainText": 90,
            "history.enable.images": true,
            "history.retentionDays.images": 7,
            "history.enable.fileLists": true,
            "history.retentionDays.fileLists": 30,
            "history.viewer.hotkey": "^⌥⌘;",
            "history.ignore.images": false,
            "history.ignore.fileLists": true,
            "history.integrate.snippetsHeader": false,
            "history.integrate.showSnippetsInSearch": false,
            "history.moveDuplicatesToTop": true,
            "history.isPaused": false,
            "history.pause.hotkey": "^⌥⌘P",  // 기본값: Control+Option+Command+P
            "settings.hotkey": "^⇧⌘;",  // Issue727: 설정창 열기 글로벌 단축키 (Control+Shift+Command+;)
            "history.pause.showNotification": true,
            "history.showStatusBar": true,  // CL035 기본값
            "history.forceInputSource": "keep",  // CL038 기본값

            "history.showPreview": true,
            "history.preview.hotkey": "",
            "history.registerSnippet.hotkey": "⌘S",

            // CL076: 구성 가능한 너비
            "history.viewer.width": 350.0,
            "history.preview.width": 400.0,

            // Issue 359: 언어 설정
            "language": "system",

            // Issue 425: 스니펫 목록 컬럼 너비
            "snippet_list_name_width": 150.0,
            "snippet_list_abbr_width": 120.0,

            // Issue 741: REST API 설정
            "api_enabled": false,
            "api_port": 3015,
            "api_allow_external": false,
            "api_allowed_cidr": "127.0.0.1/32",
        ]
    }

    // MARK: - 간단한 YAML 파서 & 직렬화기

    // JSON-in-YAML 지원 파서
    private func parseYAML(_ content: String) -> [String: Any] {
        var result: [String: Any] = [:]
        let lines = content.components(separatedBy: .newlines)
        var inPreferences = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed == "preferences:" {
                inPreferences = true
                continue
            }

            if inPreferences {
                // "key: value" 형태 파싱
                let components = trimmed.split(separator: ":", maxSplits: 1).map { String($0) }
                if components.count == 2 {
                    let key = components[0].trimmingCharacters(in: .whitespaces)
                    var valueStr = components[1].trimmingCharacters(in: .whitespaces)

                    // 따옴표 제거
                    if valueStr.hasPrefix("\"") && valueStr.hasSuffix("\"") {
                        valueStr = String(valueStr.dropFirst().dropLast())
                    } else if valueStr.hasPrefix("'") && valueStr.hasSuffix("'") {
                        valueStr = String(valueStr.dropFirst().dropLast())
                    }

                    // JSON 파싱 시도
                    if (valueStr.hasPrefix("[") && valueStr.hasSuffix("]"))
                        || (valueStr.hasPrefix("{") && valueStr.hasSuffix("}"))
                    {
                        if let data = valueStr.data(using: .utf8),
                            let jsonObject = try? JSONSerialization.jsonObject(
                                with: data, options: [])
                        {
                            result[key] = jsonObject
                            continue
                        }
                    }

                    // 기본 타입 추론 (순서 중요: Bool -> Int -> Double -> String)
                    if let boolVal = Bool(valueStr) {
                        result[key] = boolVal
                    } else if let intVal = Int(valueStr) {
                        result[key] = intVal
                        // logV("⚙️ [YAML] Parsed Int: \(key) = \(intVal)")
                    } else if let doubleVal = Double(valueStr) {
                        // Double이지만 .0으로 끝나는 경우 Int로 변환 시도 (Issue 245 Fix)
                        if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                            let intConverted = Int(doubleVal)
                            result[key] = intConverted
                            // logV("⚙️ [YAML] Parsed Double as Int: \(key) = \(intConverted)")
                        } else {
                            result[key] = doubleVal
                        }
                    } else {
                        // 마지막으로 String
                        result[key] = valueStr
                    }
                }
            }
        }
        return result
    }

    private func serializeYAML(_ config: [String: Any]) -> String {
        var content = "# fSnippet Configuration\n"
        content += "# Created: \(Date())\n\n"
        content += "preferences:\n"

        // 키 정렬하여 일관성 유지
        for key in config.keys.sorted() {
            // Issue 195: appRootPath는 YAML에 저장하지 않음 (plist 전용)
            if key == "appRootPath" { continue }

            // Issue 244: External Keys는 YAML에 저장하지 않음 (UserDefaults 전용)
            // (바이너리, 장문 데이터 등 가독성 저해 요소 분리)
            if externalStorageKeys.contains(key) { continue }

            if let val = config[key] {
                if let boolVal = val as? Bool {
                    content += "  \(key): \(boolVal)\n"
                } else if let intVal = val as? Int {
                    content += "  \(key): \(intVal)\n"
                } else if let doubleVal = val as? Double {  // Double 지원 추가
                    // .0으로 끝나는 경우 깔끔하게 정수로 저장
                    if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                        content += "  \(key): \(Int(doubleVal))\n"
                    } else {
                        content += "  \(key): \(doubleVal)\n"
                    }
                } else if let cgFloatVal = val as? CGFloat {  // CGFloat 명시적 지원 (Issue Case)
                    let doubleVal = Double(cgFloatVal)
                    if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                        content += "  \(key): \(Int(doubleVal))\n"
                    } else {
                        content += "  \(key): \(doubleVal)\n"
                    }
                } else if let stringVal = val as? String {
                    // String이지만 숫자로 변환 가능한 경우 (소수점 포함) 정규화 시도
                    if let doubleVal = Double(stringVal) {
                        if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                            content += "  \(key): \(Int(doubleVal))\n"
                        } else {
                            content += "  \(key): \(doubleVal)\n"
                        }
                    } else {
                        content += "  \(key): \"\(stringVal)\"\n"
                    }
                } else if let arrVal = val as? [Any] {
                    // Array -> JSON String
                    if let data = try? JSONSerialization.data(withJSONObject: arrVal, options: []),
                        let jsonStr = String(data: data, encoding: .utf8)
                    {
                        content += "  \(key): \(jsonStr)\n"
                    }
                } else if let dictVal = val as? [String: Any] {
                    // Dict -> JSON String
                    if let data = try? JSONSerialization.data(
                        withJSONObject: dictVal, options: .sortedKeys),
                        let jsonStr = String(data: data, encoding: .utf8)
                    {
                        content += "  \(key): \(jsonStr)\n"
                    }
                } else {
                    // 폴백
                    content += "  \(key): \"\(val)\"\n"
                }
            }
        }
        return content
    }
}
