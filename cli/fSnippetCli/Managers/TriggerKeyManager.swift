import Foundation
import Combine
import Cocoa

/// 트리거키 관리 전용 클래스 (KeyLogger 기반)
class TriggerKeyManager: ObservableObject {
    static let shared = TriggerKeyManager()
    
    // MARK: - Published Properties
    
    /// 현재 활성화된 트리거키들
    @Published private(set) var activeTriggerKeys: [EnhancedTriggerKey] = []
    
    /// 사용 가능한 모든 트리거키들
    @Published private(set) var availableTriggerKeys: [EnhancedTriggerKey] = []
    
    /// 기본 트리거키 (기존 시스템 호환용)
    @Published private(set) var defaultTriggerKey: EnhancedTriggerKey?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let activeTriggerKeysKey = "snippet_active_trigger_keys"
    private let legacyActiveTriggerKeysKey = "ActiveTriggerKeys"
    private let defaultTriggerKeyKey = "DefaultTriggerKey"

    // Issue789: 설정 캐싱 - matchTriggerKey() 호출마다 SettingsManager.load() 실행 방지
    // setupSettingsChangeMonitoring()이 변경 감지 및 갱신을 담당하므로 여기선 캐싱만 수행
    private var cachedDefaultSymbol: String = ""

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupAvailableTriggerKeys()
        loadSettings()
        // Issue789: 초기 캐싱 - loadSettings() 이후 defaultSymbol 캐시 갱신
        cachedDefaultSymbol = SettingsManager.shared.load().defaultSymbol

        // Issue74: init 시점에는 RuleManager가 초기화되지 않을 수 있으므로
        // 잠시 후 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.addRuleSuffixTriggers()
            logV("🔑 [Issue74] Delayed suffix 트리거 추가 완료")
        }

        // ✅ UserDefaults 변경 감지 - defaultSymbol 즉시 적용
        setupSettingsChangeMonitoring()
        
        // ✅ 글로벌 단축키 감지 (일시 중단 토글용)
        setupGlobalHotkeyMonitoring()


        logV("🔑 [TriggerKeyManager] 초기화 완료 - 활성 트리거키: \(activeTriggerKeys.count)개")
        
        // Issue 277_2: 초기화 시 ShortcutMgr에 등록
        updateShortcutMgr()
        

    }
    /// 글로벌 단축키 감지 설정


    
    /// 글로벌 단축키 감지 설정
    private func setupGlobalHotkeyMonitoring() {
        // 1. NSEvent 전역 모니터 (앱이 백그라운드일 때)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
        
        // 2. NSEvent 로컬 모니터 (앱이 활성 상태일 때)
        // Issue763: 단축키 매칭 시 return nil로 이벤트 소비하여 비프음 방지
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleGlobalKeyEvent(event) == true {
                return nil  // 이벤트 소비 → 비프음 방지
            }
            return event
        }
        
        logV("🔑 [TriggerKeyManager] 글로벌/로컬 단축키 모니터링 시작")
    }
    
    // Issue763: 반환타입 Bool로 변경 - 매칭 시 true 반환하여 localMonitor에서 이벤트 소비
    @discardableResult
    private func handleGlobalKeyEvent(_ event: NSEvent) -> Bool {
        let prefs = PreferencesManager.shared

        // 1. 히스토리 뷰어 호출 단축키 체크
        let viewerHotkey = prefs.string(forKey: "history.viewer.hotkey", defaultValue: "^⌥⌘;")
        if matchHotkey(event: event, hotkeyString: viewerHotkey) {
            logI("🔑 [TriggerKeyManager] Viewer Hotkey Detected: \(viewerHotkey)")
            DispatchQueue.main.async {
                HistoryViewerManager.shared.show()
            }
            return true
        }

        // 2. 수집 일시 중단 단축키 체크
        let pauseHotkey = prefs.string(forKey: "history.pause.hotkey", defaultValue: "^⌥⌘P")
        if matchHotkey(event: event, hotkeyString: pauseHotkey) {
            logI("🔑 [TriggerKeyManager] Pause Hotkey Detected: \(pauseHotkey)")
            toggleHistoryPause()
            return true
        }

        return false
    }
    
    private func toggleHistoryPause() {
        let prefs = PreferencesManager.shared
        let current = prefs.bool(forKey: "history.isPaused", defaultValue: false)
        let newState = !current
        prefs.set(newState, forKey: "history.isPaused")
        
        // 상태 변화 전파
        NotificationCenter.default.post(name: NSNotification.Name("historyPauseStateChanged"), object: newState)
        
        // HUD 알림 표시 (Issue14: 다국어 대응)
        let l10n = LocalizedStringManager.shared
        let message = newState ? l10n.string("toast.clipboard_paused") : l10n.string("toast.clipboard_resumed")
        let icon = newState ? "pause.fill" : "play.fill"
        ToastManager.shared.showToast(message: message, iconName: icon)
    }
    
    // MARK: - Hotkey Matching (Public)

    /// 주어진 NSEvent가 특정 핫키 문자열(예: "^⌥⌘P")과 일치하는지 확인
    func isHotkeyMatch(event: NSEvent, hotkeyString: String) -> Bool {
        // 단축키 문자열 파싱 및 비교 로직 (Control:^, Option:⌥, Command:⌘, Shift:⇧)
        // ✅ Issue 430: 정규화를 위해 중괄호 제거 ({keypad_comma} -> keypad_comma)
        let normalizedHotkeyString = EnhancedTriggerKey.unwrapBraces(hotkeyString)
        
        var requiredFlags: NSEvent.ModifierFlags = []
        if normalizedHotkeyString.contains("^") || normalizedHotkeyString.contains("⌃") { requiredFlags.insert(.control) }
        if normalizedHotkeyString.contains("⌥") { requiredFlags.insert(.option) }
        if normalizedHotkeyString.contains("⌘") { requiredFlags.insert(.command) }
        if normalizedHotkeyString.contains("⇧") { requiredFlags.insert(.shift) }
        
        // Modifier Flags Check
        let eventFlags = event.modifierFlags.intersection([.control, .option, .command, .shift])
        guard eventFlags == requiredFlags else { return false }
        
        // Key Matching Logic (Improved for Input Sources)
        // 1. Extract Key String (remove modifiers)
        var keyStr = normalizedHotkeyString
        for mod in ["^", "⌃", "⌥", "⌘", "⇧"] {
            keyStr = keyStr.replacingOccurrences(of: mod, with: "")
        }
        
        // 2. KeyCode 매칭 시도 (기본)
        // 일관된 물리적 키 감지를 위해 표준 QWERTY 매핑 사용
        var targetKeyCodes = TriggerKeyManager.reverseKeyMap[keyStr]
        if targetKeyCodes == nil {
             targetKeyCodes = TriggerKeyManager.legacyKeyMap[keyStr]
        }
        
        if let codes = targetKeyCodes {
            // Check if event's keyCode matches any of the candidate keyCodes
            if codes.contains(event.keyCode) {
                return true
            }
        }
        
        // 3. 문자 매칭으로 폴백 (레거시)
        // KeyCode 매칭이 실패한 경우에만 (예: 알 수 없는 키)
        let keyChar = keyStr.last?.uppercased()
        let eventChar = event.charactersIgnoringModifiers?.uppercased()
        
        return keyChar == eventChar
    }
    
    private func matchHotkey(event: NSEvent, hotkeyString: String) -> Bool {
        return isHotkeyMatch(event: event, hotkeyString: hotkeyString)
    }

    // Reverse mapping from Display String to KeyCodes (Supports duplicates like Numpad)
    // Based on ShortcutInputView.swift's list
    // 표시 문자열에서 KeyCode로의 역매핑 (Numpad와 같은 중복 지원)
    // ShortcutInputView.swift의 목록 기반
    public static var reverseKeyMap: [String: [UInt16]] = {
        var map: [String: [UInt16]] = [
            "A": [0], "S": [1], "D": [2], "F": [3], "H": [4], "G": [5], "Z": [6], "X": [7], "C": [8], "V": [9],
            "B": [11], "Q": [12], "W": [13], "E": [14], "R": [15], "Y": [16], "T": [17], "1": [18, 83], "2": [19, 84],
            "3": [20, 85], "4": [21, 86], "6": [22, 88], "5": [23, 87], "=": [24, 81], "9": [25, 92], "7": [26, 89], "-": [27, 78], "8": [28, 91],
            "0": [29, 82], "]": [30], "O": [31], "U": [32], "[": [33], "I": [34], "P": [35], "[Return]": [36, 76], "L": [37],
            "J": [38], "'": [39], "K": [40], ";": [41], "\\": [42], ",": [43], "/": [44, 75], "N": [45], "M": [46],
            ".": [47, 65], "[Tab]": [48], "Space": [49], "`": [50], "[Backspace]": [51], "[Escape]": [53],
            "*": [67], "+": [69], "[Clear]": [71], "🔢": [71],
            
            // 참고: 기능 키 및 기타 키는 이제 SharedKeyMap에서 가져옵니다.
            // F5-F19, Insert, Home 등
            
            // TriggerKeyManager에만 있는 추가 커스텀 매핑
            "keypad_decimal": [65], "unknown_95": [95], "keypad_comma": [95]
        ]
        // 공유 키패드 매핑 병합 (SSOT)
        map.merge(SharedKeyMap.reverseMapping) { (_, new) in new }
        return map
    }()

    /// 하위 호환성을 위한 레거시 키 맵 (Issue 439)
    /// 조회(KeySpec -> KeyCode)에는 사용되지만 역방향 조회(KeyCode -> KeySpec)에서는 제외됨
    public static let legacyKeyMap: [String: [UInt16]] = [
        "NumKey0": [82], "NumKey1": [83], "NumKey2": [84], "NumKey3": [85], "NumKey4": [86],
        "NumKey5": [87], "NumKey6": [88], "NumKey7": [89], "NumKey8": [91], "NumKey9": [92],
        "NumKey.": [65], "NumKey*": [67], "NumKey+": [69], "NumClear": [71], "NumLock": [71], "NumKey/": [75],
        "NumEnter": [76], "NumKey-": [78], "NumKey=": [81], "NumKey,": [95]
    ]
    
    /// 사용 가능한 트리거키 목록 초기화
    private func setupAvailableTriggerKeys() {
        availableTriggerKeys = EnhancedTriggerKey.presets.sortedByPriority()
        logV("🔑 [TriggerKeyManager] 사용 가능한 트리거키 로드: \(availableTriggerKeys.count)개")
    }
    
    /// 설정 로드
    private func loadSettings() {
        // Issue 277 리팩토링: 기본 심볼을 단일 진실 공급원(SSOT)으로 우선순위화
        // 더 이상 설정의 'activeTriggerKeys' 목록에 의존하지 않습니다.
        loadDefaultTriggerKey()
        setupActiveKeys()
    }
    
    private func setupActiveKeys() {
        guard let defaultKey = defaultTriggerKey else {
             loadDefaultTriggerKey() // 기본값 폴백
             return
        }
        let systemKeys = [EnhancedTriggerKey.delta, EnhancedTriggerKey.ring, EnhancedTriggerKey.`not`]
        activeTriggerKeys = [defaultKey] + systemKeys
        logV("🔑 [TriggerKeyManager] Active Keys Setup: \(activeTriggerKeys.map { $0.displayName })")
    }

    /// Issue88: suffix 트리거 등록 비활성화 (단, Non-Character Generating Key는 예외)
    /// suffix 기반 확장은 KeyEventMonitor.swift:941줄의 suffix 기반 확장 로직에서 처리
    /// 일반 문자(,)는 등록하지 않지만, 특수 키(NumLock 등)는 등록해야 CGEventTap에서 감지됨
    private func addRuleSuffixTriggers() {
        // Issue 480: PSKeyManager를 사용하여 등록된 모든 접미사 가져오기
        let suffixes = PSKeyManager.shared.getSuffixes()
        
        logV("🔑 [Issue88] suffix 규칙 검사 (via PSKeyManager): 총 \(suffixes.count)개")

        for suffix in suffixes {
            
            // 2. Suffix가 KeySpec 형식인지 확인 (예: "{keypad_num_lock}")
            // Issue 459: 접미사는 중괄호로 감싸져 있거나 명확한 키 이름일 수 있음
            let normalizedSuffix = EnhancedTriggerKey.unwrapBraces(suffix)
            
            // 3. Trigger Key로 변환 시도
            // 이미 availableTriggerKeys에 있는지 확인 (ID 또는 시퀀스 또는 표시)
            var targetKey: EnhancedTriggerKey?
            
            if let existing = availableTriggerKeys.first(where: { 
                $0.id == normalizedSuffix || "keyspec_\($0.id)" == normalizedSuffix || $0.keySequence == normalizedSuffix 
            }) {
                targetKey = existing
            } else {
                // 없으면 생성 시도
                targetKey = EnhancedTriggerKey.from(keySpec: suffix)
            }
            
            if let key = targetKey {
                // 4. Non-Character Generating 여부 확인 (Issue 459)
                if !key.isCharacterGenerating {
                    // 특수 키(NumLock, Clear 등)는 반드시 Active Trigger로 등록해야 EventTap에서 잡힘
                    if !activeTriggerKeys.contains(where: { $0.id == key.id }) {
                        logV("🔑 [Issue459] Non-Character Suffix 감지: \(key.displayName) (\(key.id)) -> 활성 트리거 등록")
                        
                        var newActive = activeTriggerKeys
                        newActive.append(key)
                        // 주의: setActiveTriggerKeys는 saveActiveTriggerKeys를 호출함 (Legacy 무시됨)
                        setActiveTriggerKeys(newActive)
                    }
                } else {
                    // 일반 문자(,)는 건너뜀 (KeyEventMonitor에서 텍스트 감지)
                    // logV("🔑 [Issue88] Character Suffix 건너뜀: \(key.displayName)")
                }
            }
        }
    }
    
    /// 활성 트리거키 목록 로드
    private func loadActiveTriggerKeys() {
        // 1. PreferencesManager (config.yaml)에서 로드 시도
        if let savedIds: [String] = PreferencesManager.shared.get(activeTriggerKeysKey) {
            
            // Issue 277: 'keyspec_' ID로부터 커스텀 키 재구성
            for id in savedIds {
                if id.hasPrefix("keyspec_") {
                    // 이미 사용 가능한지 확인 (새로운 시작 시 커스텀 키가 있을 가능성은 낮음)
                    if !availableTriggerKeys.contains(where: { $0.id == id }) {
                        // Decode Base64
                        let base64 = String(id.dropFirst("keyspec_".count))
                        if let data = Data(base64Encoded: base64),
                           let spec = String(data: data, encoding: .utf8) {
                            
                            let newKey = EnhancedTriggerKey.from(keySpec: spec)
                            if newKey.id == id { // ID 일치 확인 (안전장치)
                                availableTriggerKeys.append(newKey)
                                logV("🔑 [TriggerKeyManager] Config에서 커스텀 키 복원됨: \(spec)")
                            }
                        }
                    }
                }
            }
            
            activeTriggerKeys = availableTriggerKeys.filter { savedIds.contains($0.id) }
            logV("🔑 [TriggerKeyManager] config.yaml에서 활성 트리거키 로드: \(savedIds)")
            return
        }
        
        // 2. Legacy UserDefaults에서 로드 시도 (Migration)
        if let data = userDefaults.data(forKey: legacyActiveTriggerKeysKey),
           let savedIds = try? JSONDecoder().decode([String].self, from: data) {
            
            activeTriggerKeys = availableTriggerKeys.filter { savedIds.contains($0.id) }
            logV("🔑 [TriggerKeyManager] Legacy UserDefaults에서 활성 트리거키 로드 (마이그레이션): \(savedIds)")
            
            // 마이그레이션: config.yaml에 저장하고 UserDefaults에서 제거
            saveActiveTriggerKeys()
            userDefaults.removeObject(forKey: legacyActiveTriggerKeysKey)
            
        } else {
             // 3. 기본값: defaultKey + System Keys
             let defaultKey = defaultTriggerKey ?? EnhancedTriggerKey.equals
             let systemKeys = [EnhancedTriggerKey.delta, EnhancedTriggerKey.ring, EnhancedTriggerKey.`not`]
             activeTriggerKeys = [defaultKey] + systemKeys
             
            saveActiveTriggerKeys()
            logV("🔑 [TriggerKeyManager] 기본 활성 트리거키 설정: \(defaultKey.displayName), ∆, ˚, ¬")
        }
    }
    
    /// 기본 트리거키 로드 - SettingsManager와 동기화
    private func loadDefaultTriggerKey() {
        // Issue 277: 'snippet_default_symbol'을 로드하여 KeySpec으로 취급
        // FIX: UserDefaults를 직접 사용하는 것이 아니라, config.yaml에서 읽기 위해 PreferencesManager를 사용해야 함.
        let symbolOrSpec: String = PreferencesManager.shared.get("snippet_trigger_key") ?? "="
        
        logV("🔑 [TriggerKeyManager] Loading Default Key. Spec: '\(symbolOrSpec)' (Raw from Config)")
        
        // 1. 프리셋 매칭 시도 ('diamond_key'와 같은 깔끔한 ID의 하위 호환성을 위해)
        if let preset = EnhancedTriggerKey.presets.first(where: { $0.displayCharacter == symbolOrSpec || $0.keySequence == symbolOrSpec }) {
             defaultTriggerKey = preset
             logV("🔑 [TriggerKeyManager] Preset Default Key Loaded: \(preset.displayName) (ID: \(preset.id))")
        } else {
             // 2. Construct from KeySpec (e.g. "^⇧;")
             let newKey = EnhancedTriggerKey.from(keySpec: symbolOrSpec)
             defaultTriggerKey = newKey
             
             defaultTriggerKey = newKey
             
             logV("🔑 [TriggerKeyManager] Parsed Custom Key: \(newKey.displayName) (ID: \(newKey.id), KeyCode: \(newKey.keyCode), Modifiers: \(newKey.modifiers))")
        }
        
        // 기본 키가 사용 가능한지 확인
        if let key = defaultTriggerKey {
             if !availableTriggerKeys.contains(where: { $0.id == key.id }) {
                 availableTriggerKeys.append(key)
             }
        }
    }

    /// UserDefaults 변경 감지 설정 - defaultSymbol 즉시 적용
    private func setupSettingsChangeMonitoring() {
        // 1. UserDefaults의 defaultSymbol 변경 감지
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .compactMap { _ in
                UserDefaults.standard.string(forKey: "snippetDefaultSymbol")
            }
            .removeDuplicates()
            .sink { [weak self] newDefaultSymbol in
                self?.handleDefaultSymbolChange(newDefaultSymbol)
            }
            .store(in: &cancellables)

        // 2. ✅ 설정창에서 저장 버튼 클릭 시 즉시 감지
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .sink { [weak self] notification in
                logV("🔑 [TriggerKeyManager] .settingsDidChange 알림 수신됨")

                if let settings = notification.object as? SnippetSettings {
                    let newDefaultSymbol = settings.defaultSymbol
                    logV("🔑 [TriggerKeyManager] 설정창 저장으로 defaultSymbol 변경 감지: '\(newDefaultSymbol)'")
                    self?.handleDefaultSymbolChange(newDefaultSymbol)
                } else {
                    logW("🔑 [TriggerKeyManager] 알림 객체를 SnippetSettings로 변환 실패: \(type(of: notification.object))")
                }
            }
            .store(in: &cancellables)

        logV("🔑 [TriggerKeyManager] UserDefaults 및 설정창 변경 감지 설정 완료")
        
        // 3. ✅ PreferencesManager 로드 완료 감지 (Race Condition 해결)
        NotificationCenter.default.publisher(for: .preferencesDidLoadConfig)
            .sink { [weak self] _ in
                logV("🔑 [TriggerKeyManager] Preferences Loaded Notification Received. Reloading Settings...")
                self?.reloadSettings()
            }
            .store(in: &cancellables)
            
        // 4. ✅ 이미 로드되었는지 확인 (누락된 알림 수정)
        if PreferencesManager.shared.isConfigLoaded {
            logV("🔑 [TriggerKeyManager] Preferences already loaded. Reloading Settings immediately.")
            // 필요한 경우 메인 스레드에 있는지 확인, reloadSettings는 안전함
            DispatchQueue.main.async { [weak self] in
                self?.reloadSettings()
            }
        }
    }

    /// defaultSymbol 변경 처리 - 즉시 적용
    private func handleDefaultSymbolChange(_ newDefaultSymbol: String) {
        // Issue789: 캐시 갱신 - 설정 변경 시 cachedDefaultSymbol 업데이트
        cachedDefaultSymbol = newDefaultSymbol
        logV("🔑 [TriggerKeyManager] defaultSymbol 변경 감지: '\(newDefaultSymbol)'")
        logV("🔑 [TriggerKeyManager] 현재 defaultTriggerKey: \(defaultTriggerKey?.displayCharacter ?? "nil")")

        // Issue 454: 중괄호로 감싸진 키 정규화 (예: {keypad_comma})
        let normalizedSymbol = EnhancedTriggerKey.unwrapBraces(newDefaultSymbol)
        
        // 새로운 defaultSymbol에 해당하는 트리거키 찾기
        // Issue 454: keySequence(keypad_comma와 같은 기호용) 및 ID로 조회 지원
        if let matchingTriggerKey = availableTriggerKeys.first(where: { 
            $0.displayCharacter == normalizedSymbol || 
            $0.keySequence == normalizedSymbol ||
            $0.id == normalizedSymbol ||
            $0.id == "keyspec_\(normalizedSymbol)" // 잠재적인 ID 형식 불일치 처리
        }) {
            let oldTriggerKey = defaultTriggerKey
            defaultTriggerKey = matchingTriggerKey

            // 활성 트리거키에 추가 (없다면)
            if !activeTriggerKeys.contains(where: { $0.id == matchingTriggerKey.id }) {
                var newActiveTriggers = activeTriggerKeys
                newActiveTriggers.append(matchingTriggerKey)
                activeTriggerKeys = newActiveTriggers.sortedByPriority()
                saveActiveTriggerKeys()
                logV("🔑 [TriggerKeyManager] 새 기본 트리거키를 활성 목록에 추가: \(matchingTriggerKey.displayName)")
            }

            saveDefaultTriggerKey()

            logV("🔑 [TriggerKeyManager] 기본 트리거키 즉시 변경 완료")
            logV("🔑   → 이전: \(oldTriggerKey?.displayName ?? "없음") (\(oldTriggerKey?.displayCharacter ?? ""))")
            logV("🔑   → 현재: \(matchingTriggerKey.displayName) (\(matchingTriggerKey.displayCharacter))")
            logV("🔑 [TriggerKeyManager] 변경 후 defaultTriggerKey 확인: \(defaultTriggerKey?.displayCharacter ?? "nil")")

            // ✅ Issue38 해결: CGEventTap 재초기화 신호 전송
            NotificationCenter.default.post(name: .triggerKeyDidChange, object: matchingTriggerKey)
            logV("🔑 [TriggerKeyManager] CGEventTap 재초기화 신호 전송: .triggerKeyDidChange")
        } else {
            logW("🔑 [TriggerKeyManager] 알 수 없는 defaultSymbol: '\(newDefaultSymbol)' - 기본 트리거키 유지")
        }
    }

    // MARK: - Public Methods

    /// ✅ Issue38: 설정 변경 시 트리거키 설정 재로드
    func reloadSettings() {
        logV("🔑 [Issue38] TriggerKeyManager 설정 재로드 시작")

        // 기본 트리거키 다시 로드 (SettingsManager와 동기화)
        loadDefaultTriggerKey()
        
        // 활성 트리거키도 다시 로드 (레거시 loadActiveTriggerKeys가 아닌 새로운 로직 사용)
        setupActiveKeys()
        
        // Issue74: suffix 트리거 키 재로드
        addRuleSuffixTriggers()
        
        logV("🔑 [Issue38] TriggerKeyManager 설정 재로드 완료 - 기본 트리거키: '\(defaultTriggerKey?.displayCharacter ?? "없음")'")
    }

    // MARK: - Core Matching Methods
    
    /// KeyLogger 데이터로 트리거키 매칭 (Legacy String-based)
    func matchTriggerKey(keyCode: String, usage: String, usagePage: String,
                        modifiers: String, character: String) -> EnhancedTriggerKey? {
        // ... (Existing implementation kept for compatibility, or forwarded?)
        // For now, keep as is for compatibility with any legacy calls.
        
        // ... (Existing logic below) ...

        // ✅ 실시간 설정 확인: Legacy 시스템과 동일한 방식으로 최신 설정 적용
        let currentSettings = SettingsManager.shared.load()
        let realTimeDefaultSymbol = currentSettings.defaultSymbol

        // 현재 캐시된 defaultTriggerKey와 실시간 설정 비교
        if defaultTriggerKey?.displayCharacter != realTimeDefaultSymbol {
            logV("🔑 [TriggerKeyManager] 실시간 설정 변경 감지: '\(defaultTriggerKey?.displayCharacter ?? "nil")' → '\(realTimeDefaultSymbol)'")

            // 실시간으로 매칭되는 트리거키 찾기
            if let realtimeTriggerKey = availableTriggerKeys.first(where: { $0.displayCharacter == realTimeDefaultSymbol }) {
                defaultTriggerKey = realtimeTriggerKey

                // 활성 목록에도 추가 (없다면)
                if !activeTriggerKeys.contains(where: { $0.id == realtimeTriggerKey.id }) {
                    var newActiveTriggers = activeTriggerKeys
                    newActiveTriggers.append(realtimeTriggerKey)
                    activeTriggerKeys = newActiveTriggers.sortedByPriority()
                    logV("🔑 [TriggerKeyManager] 실시간 트리거키를 활성 목록에 추가: \(realtimeTriggerKey.displayName)")
                }

                logV("🔑 [TriggerKeyManager] 실시간 트리거키 업데이트 완료: \(realtimeTriggerKey.displayName)")
            } else {
                logW("🔑 [TriggerKeyManager] 실시간 설정 '\(realTimeDefaultSymbol)'에 해당하는 트리거키를 찾을 수 없음")
            }
        }

        // 트리거키 매칭 시작
        logV("🔑 트리거키 매칭 시작:")
        logV("🔑    입력: keyCode='\(keyCode)', character='\(character)', modifiers='\(modifiers)'")
        logV("🔑    활성 트리거키 수: \(activeTriggerKeys.count)")

        // 활성화된 트리거키들 중에서 매칭 시도 (우선순위 순)
        let candidates = activeTriggerKeys.sortedByPriority()

        for triggerKey in candidates {
            logV("🔑    검사중: \(triggerKey.displayName)")
            if triggerKey.matches(keyCode: keyCode, usage: usage, usagePage: usagePage,
                                modifiers: modifiers, character: character) {
                logV("🔑 트리거키 매칭: \(triggerKey.displayName)")
                return triggerKey
            }
        }

        // 매칭되는 트리거키 없음
        logV("🔑 매칭되는 트리거키 없음")
        return nil
    }

    /// KeyLogger 데이터로 트리거키 매칭 (Optimized Integer-based) (Issue 583_10)
    func matchTriggerKey(keyCode: UInt16, modifiers: UInt, character: String?) -> EnhancedTriggerKey? {

        // Issue789: cachedDefaultSymbol 사용 (setupSettingsChangeMonitoring이 변경 감지 담당)
        // SettingsManager.shared.load()를 매 호출마다 실행하지 않아 성능 개선
        let realTimeDefaultSymbol = cachedDefaultSymbol

        if defaultTriggerKey?.displayCharacter != realTimeDefaultSymbol {
             if let realtimeTriggerKey = availableTriggerKeys.first(where: { $0.displayCharacter == realTimeDefaultSymbol }) {
                defaultTriggerKey = realtimeTriggerKey
                if !activeTriggerKeys.contains(where: { $0.id == realtimeTriggerKey.id }) {
                    var newActiveTriggers = activeTriggerKeys
                    newActiveTriggers.append(realtimeTriggerKey)
                    activeTriggerKeys = newActiveTriggers.sortedByPriority()
                }
             }
        }

        // 2. 최적화된 매칭 시도
        let candidates = activeTriggerKeys // 이미 sortedByPriority() 상태 유지 가정, 아니면 여기서 정렬? 
                                          // activeTriggerKeys는 수정될때마다 sortedByPriority() 호출함.
        
        for triggerKey in candidates {
            if triggerKey.matches(keyCode: keyCode, modifiers: modifiers, character: character) {
                return triggerKey
            }
        }
        
        return nil
    }
    
    /// 문자만으로 트리거키 매칭 (기존 시스템 호환용)
    func matchTriggerKey(character: String) -> EnhancedTriggerKey? {

        // ✅ 실시간 설정 확인: Legacy 시스템과 동일한 방식으로 최신 설정 적용
        let currentSettings = SettingsManager.shared.load()
        let realTimeDefaultSymbol = currentSettings.defaultSymbol

        // 현재 캐시된 defaultTriggerKey와 실시간 설정 비교
        if defaultTriggerKey?.displayCharacter != realTimeDefaultSymbol {
            logD("🔑 [TriggerKeyManager] 문자 매칭에서 실시간 설정 변경 감지: '\(defaultTriggerKey?.displayCharacter ?? "nil")' → '\(realTimeDefaultSymbol)'")

            // 실시간으로 매칭되는 트리거키 찾기
            if let realtimeTriggerKey = availableTriggerKeys.first(where: { $0.displayCharacter == realTimeDefaultSymbol }) {
                defaultTriggerKey = realtimeTriggerKey

                // 활성 목록에도 추가 (없다면)
                if !activeTriggerKeys.contains(where: { $0.id == realtimeTriggerKey.id }) {
                    var newActiveTriggers = activeTriggerKeys
                    newActiveTriggers.append(realtimeTriggerKey)
                    activeTriggerKeys = newActiveTriggers.sortedByPriority()
                    logV("🔑 [TriggerKeyManager] 문자 매칭에서 실시간 트리거키를 활성 목록에 추가: \(realtimeTriggerKey.displayName)")
                }

                logV("🔑 [TriggerKeyManager] 문자 매칭에서 실시간 트리거키 업데이트 완료: \(realtimeTriggerKey.displayName)")
            } else {
                logW("🔑 [TriggerKeyManager] 문자 매칭에서 실시간 설정 '\(realTimeDefaultSymbol)'에 해당하는 트리거키를 찾을 수 없음")
            }
        }

        let candidates = activeTriggerKeys.matching(character: character).sortedByPriority()
        let result = candidates.first

        // 문자 기반 트리거키 매칭

        return result
    }
    
    /// 현재 기본 트리거키가 주어진 데이터와 매칭되는지 확인
    func isDefaultTriggerKey(keyCode: String, usage: String, usagePage: String, 
                           modifiers: String, character: String) -> Bool {
        guard let defaultTrigger = defaultTriggerKey else { return false }
        
        return defaultTrigger.matches(keyCode: keyCode, usage: usage, usagePage: usagePage, 
                                    modifiers: modifiers, character: character)
    }
    
    /// 현재 기본 트리거키가 주어진 문자와 매칭되는지 확인 (기존 시스템 호환용)
    func isDefaultTriggerKey(character: String) -> Bool {
        return defaultTriggerKey?.displayCharacter == character
    }
    
    // MARK: - Settings Management
    
    /// 활성 트리거키 설정
    func setActiveTriggerKeys(_ triggerKeys: [EnhancedTriggerKey]) {
        activeTriggerKeys = triggerKeys.sortedByPriority()
        saveActiveTriggerKeys()
        logV("🔑 [TriggerKeyManager] 활성 트리거키 업데이트: \(triggerKeys.map { $0.displayName })")
        
        // Issue 277_2: ShortcutMgr 업데이트
        updateShortcutMgr()
    }
    
    /// 활성 트리거키 ID로 설정
    func setActiveTriggerKeys(ids: [String]) {
        let triggerKeys = availableTriggerKeys.filter { ids.contains($0.id) }
        setActiveTriggerKeys(triggerKeys)
    }
    
    // Issue 277_2: ShortcutMgr 동기화
    private func updateShortcutMgr() {
        // Issue 480: PSKeyManager에도 동기화
        syncToPSKeyManager()
        
        // 기존 등록 제거
        ShortcutMgr.shared.clear(type: .triggerKey)
        
        // 활성 트리거 키 등록
        for trigger in activeTriggerKeys {
            // keySpec 생성 (modifiers + key)
            let keySpec = trigger.toKeySpec
            
            let item = ShortcutItem(
                id: "trigger.\(trigger.id)",
                keySpec: keySpec,
                type: .triggerKey,
                description: "Trigger: \(trigger.displayName)",
                source: "TriggerKeyManager",
                userInfo: ["triggerKey": trigger]
            )
            
            ShortcutMgr.shared.register(item)
            logV("🔑 [TriggerKeyManager] ShortcutMgr 등록: \(keySpec) -> \(trigger.displayName)")
        }
    }
    
    /// Issue 480: 활성 트리거 키를 PSKeyManager에 동기화
    func syncToPSKeyManager() {
        let suffixes = activeTriggerKeys.flatMap { key in
            // Issue 524: 중복 Suffix 제거 (사용자 요청: "Option+J는 ∆이므로 ∆만 로그에 표시")
            // displayCharacter가 있다면 그것만 등록합니다.
            
            var uniqueKeys: [String] = []
            
            if !key.displayCharacter.isEmpty {
                uniqueKeys.append(key.displayCharacter)
            } else {
                // 문자가 없는 경우 (예: 특수 키), 식별자나 스펙 사용
                if !key.keySequence.isEmpty {
                    uniqueKeys.append(key.keySequence)
                } else if !key.toKeySpec.isEmpty {
                    uniqueKeys.append(key.toKeySpec)
                }
            }
            
            return uniqueKeys.map { EnhancedTriggerKey.wrapInBraces($0) }
        }
        PSKeyManager.shared.addSuffix(suffixes)
        logV("🔑 [TriggerKeyManager] PSKeyManager에 \(suffixes.count)개 키 동기화 완료")
    }
    
    /// 기본 트리거키 설정
    func setDefaultTriggerKey(_ triggerKey: EnhancedTriggerKey) {
        defaultTriggerKey = triggerKey
        saveDefaultTriggerKey()
        
        // 기본 트리거키는 자동으로 활성 목록에 추가
        if !activeTriggerKeys.contains(where: { $0.id == triggerKey.id }) {
            var newActiveTriggers = activeTriggerKeys
            newActiveTriggers.append(triggerKey)
            setActiveTriggerKeys(newActiveTriggers)
        }
        
        logV("🔑 [TriggerKeyManager] 기본 트리거키 변경: \(triggerKey.displayName)")
    }
    
    /// 트리거키 추가
    func addTriggerKey(_ triggerKey: EnhancedTriggerKey) {
        if !availableTriggerKeys.contains(where: { $0.id == triggerKey.id }) {
            availableTriggerKeys.append(triggerKey)
            availableTriggerKeys = availableTriggerKeys.sortedByPriority()
        }
        
        if !activeTriggerKeys.contains(where: { $0.id == triggerKey.id }) {
            var newActiveTriggers = activeTriggerKeys
            newActiveTriggers.append(triggerKey)
            setActiveTriggerKeys(newActiveTriggers)
        }
        
        logV("🔑 [TriggerKeyManager] 트리거키 추가: \(triggerKey.displayName)")
        
        // Issue 277_2: ShortcutMgr 업데이트 (이미 setActiveTriggerKeys에서 호출되지만, available만 추가된 경우를 대비해 호출)
        if activeTriggerKeys.contains(where: { $0.id == triggerKey.id }) {
            updateShortcutMgr()
        }
    }
    
    /// 트리거키 제거
    func removeTriggerKey(id: String) {
        // 프리셋(기본 제공) 키는 제거 불가하도록 보호할 수 있으나, 활성 목록에서는 제거 가능해야 함.
        // 여기서는 활성 목록에서 제거하고, 커스텀 키라면 available에서도 제거.
        
        var changed = false
        
        if let index = activeTriggerKeys.firstIndex(where: { $0.id == id }) {
            var newActive = activeTriggerKeys
            newActive.remove(at: index)
            setActiveTriggerKeys(newActive)
            changed = true
        }
        
        // 커스텀 키("custom_")인 경우 available에서도 제거
        if id.hasPrefix("custom_") {
             if let index = availableTriggerKeys.firstIndex(where: { $0.id == id }) {
                 availableTriggerKeys.remove(at: index)
             }
        }
        
        if changed {
             logV("🔑 [TriggerKeyManager] 트리거키 제거: \(id)")
        }
    }
    
    /// KeyLogger 결과로부터 트리거키 생성 및 추가
    func createAndAddTriggerKey(character: String, keyCode: String, usage: String, 
                               usagePage: String, modifiers: String) -> EnhancedTriggerKey {
        let newTriggerKey = EnhancedTriggerKey.fromKeyLogger(
            character: character, keyCode: keyCode, usage: usage, 
            usagePage: usagePage, modifiers: modifiers
        )
        
        addTriggerKey(newTriggerKey)
        return newTriggerKey
    }
    
    /// Issue 277_UI_Refine: 단일 주 트리거 키 교체 (시스템 접미사 키 제외)
    func replacePrimaryTriggerKey(with newKey: EnhancedTriggerKey) {
        // 1. 시스템 접미사 키(delta, ring, not)는 유지하고 나머지(주로 기존 선택된 트리거 키)는 제거
        let systemSuffixIds = ["delta_key", "ring_key", "not_key"]
        var keepers = activeTriggerKeys.filter { systemSuffixIds.contains($0.id) }
        
        // 2. 새 키 추가
        keepers.append(newKey)
        
        // 3. Available 목록에도 추가 (없다면)
        if !availableTriggerKeys.contains(where: { $0.id == newKey.id }) {
            availableTriggerKeys.append(newKey)
            availableTriggerKeys = availableTriggerKeys.sortedByPriority()
        }
        
        // 4. 활성 키 교체
        setActiveTriggerKeys(keepers)
        
        logV("🔑 [TriggerKeyManager] 주 트리거 키 교체됨: \(newKey.displayName)")
    }
    
    // MARK: - Persistence
    
    /// 활성 트리거키 저장
    private func saveActiveTriggerKeys() {
        // Issue 277 & User Request:
        // 'snippet_active_trigger_keys'는 config.yaml에 저장되지 않아야 합니다.
        // 더 이상 사용되지 않습니다(Deprecated). Suffix 키는 rule.yaml을 통해 관리됩니다.
        // 주 키는 'snippet_default_symbol'을 통해 관리됩니다.
        // 의도적으로 확인/저장을 비활성화합니다.
        logV("🔑 [TriggerKeyManager] saveActiveTriggerKeys disabled (Legacy/Rule.yaml managed)")
    }
    
    /// 기본 트리거키 저장
    private func saveDefaultTriggerKey() {
        if let triggerKey = defaultTriggerKey {
            userDefaults.set(triggerKey.id, forKey: defaultTriggerKeyKey)
            logV("🔑 [TriggerKeyManager] 기본 트리거키 저장: \(triggerKey.id)")
        }
    }
    
    // MARK: - Legacy Compatibility
    
    /// 기존 SettingsManager와의 호환성을 위한 메서드
    func getCurrentDefaultSymbol() -> String {
        return defaultTriggerKey?.displayCharacter ?? "="
    }
    
    /// 기존 시스템에서 사용하던 폴더별 심볼 매핑과 통합
    func getTriggerKeyForFolder(_ folderName: String) -> EnhancedTriggerKey? {
        // 폴더별 설정이 있다면 해당 트리거키 반환
        // 현재는 기본 트리거키 반환 (향후 확장 가능)
        return defaultTriggerKey
    }
    
    // MARK: - Debug and Utility
    
    // MARK: - 단일 진실 공급원(SSOT) 로직 (Issue 277 Refactor)
    
    /// 기본 트리거 키 업데이트 (SettingsObservableObject에서 호출)
    /// - Parameter keySpec: 새로운 키 스펙 (예: "^⇧;")
    func updateDefaultTriggerKey(to keySpec: String) {
        logV("🔑 [TriggerKeyManager] Default Trigger Key 업데이트 요청: \(keySpec)")
        
        // 1. KeySpec -> EnhancedTriggerKey 변환
        let newKey = EnhancedTriggerKey.from(keySpec: keySpec)
        
        // 2. Default Trigger Key 설정
        defaultTriggerKey = newKey
        
        // 3. activeTriggerKeys 재구성 (Default + System Suffixes)
        // System Suffixes: Delta, Ring, Not
        let systemKeys = [EnhancedTriggerKey.delta, EnhancedTriggerKey.ring, EnhancedTriggerKey.`not`]
        activeTriggerKeys = [newKey] + systemKeys
        
        // 4. ShortcutMgr 업데이트
        updateShortcutMgr()
        
        logI("🔑 [TriggerKeyManager] Active Keys Updated: \(activeTriggerKeys.map { $0.displayName })")
    }
    
    /// 디버깅용 정보 출력
    func printDebugInfo() {
        logV("🔑 === TriggerKeyManager Debug Info ===")
        logV("🔑 활성 트리거키: \(activeTriggerKeys.count)개")
        for (index, triggerKey) in activeTriggerKeys.enumerated() {
            logI("🔑   \(index + 1). \(triggerKey.displayName) (\(triggerKey.keySequence))")
        }
        
        logV("🔑 사용 가능한 트리거키: \(availableTriggerKeys.count)개")
        if let defaultKey = defaultTriggerKey {
            logV("🔑 기본 트리거키: \(defaultKey.displayName)")
        }
        
        logI("🔑 ===================================")
    }
    
    /// 통계 정보
    var statistics: TriggerKeyStatistics {
        return TriggerKeyStatistics(
            totalAvailable: availableTriggerKeys.count,
            totalActive: activeTriggerKeys.count,
            defaultTriggerKeyId: defaultTriggerKey?.id,
            presetCount: EnhancedTriggerKey.presets.count,
            customCount: availableTriggerKeys.count - EnhancedTriggerKey.presets.count
        )
    }
}

// MARK: - Supporting Types

/// 트리거키 관리 통계
struct TriggerKeyStatistics {
    let totalAvailable: Int
    let totalActive: Int
    let defaultTriggerKeyId: String?
    let presetCount: Int
    let customCount: Int
}


