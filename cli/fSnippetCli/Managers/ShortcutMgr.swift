import Cocoa
import Combine
import Foundation

/// 단축키의 역할 타입 (우선순위 포함)
enum ShortcutType: String, CaseIterable, Codable {
    case appShortcut  // 앱 기능 단축키 (Viewer, Pause, Popup 등) - Priority 100
    case folderPrefix  // 폴더 접두사 - Priority 92 (Updated for Issue 469)
    case triggerKey  // 스니펫 트리거 키 (=, {keypad_comma},{right_command} 등) - Priority 90
    case popupNavigation  // 팝업 탐색 키 (화살표, 엔터 등) - Priority 80
    case bufferClear  // 버퍼 클리어 키 (엔터, 백스페이스, 탭 등) - Priority 60
    case folderSuffix  // 폴더 접미사 - Priority 50
    // case snippetHotkey      // 개별 스니펫 실행 단축키 (삭제됨)

    var priority: Int {
        switch self {
        case .appShortcut: return 100
        case .folderPrefix: return 92  // ✅ Issue 469: Prioritize Prefix Shortcut over Trigger Key
        case .triggerKey: return 90
        case .popupNavigation: return 80
        case .bufferClear: return 60
        case .folderSuffix: return 50
        // case .snippetHotkey: return 10
        }
    }
}

extension Notification.Name {
    static let shortcutRegistryDidChange = Notification.Name("shortcutRegistryDidChange")
}

/// 등록된 단축키 항목
struct ShortcutItem: Hashable, Identifiable {
    let id: String  // 고유 식별자 (스니펫UUID, 설정키 등)
    let keySpec: String  // 정규화된 키 문자열 (예: "^⌥⌘P", "RightCmd", "Space")
    let type: ShortcutType  // 단축키 타입
    let description: String  // 사용자 표시 이름
    let source: String  // 출처 (예: "Preferences", "TriggerKeyMgr")
    let userInfo: [String: Any]?  // 추가 메타데이터 (TriggerKey 객체 등) - Hashable/Equatable 제외

    init(
        id: String, keySpec: String, type: ShortcutType, description: String, source: String,
        userInfo: [String: Any]? = nil
    ) {
        self.id = id
        self.keySpec = keySpec
        self.type = type
        self.description = description
        self.source = source
        self.userInfo = userInfo
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keySpec)
        hasher.combine(id)  // ✅ Issue 319: Include ID in hash to allow multiple items with same KeySpec
    }

    static func == (lhs: ShortcutItem, rhs: ShortcutItem) -> Bool {
        // ✅ Issue 319: Unique by ID + KeySpec
        return lhs.keySpec == rhs.keySpec && lhs.id == rhs.id
    }
}

/// 중앙 단축키 관리자
class ShortcutMgr: ObservableObject {
    static let shared = ShortcutMgr()

    // 상태 관리
    @Published private(set) var registeredShortcuts: Set<ShortcutItem> = []

    // Issue 621_2: O(1) 매칭을 위한 딕셔너리 인덱스 추가
    // Key: keySpec (예: "^⌥⌘P", "Space", "Trigger")
    // Value: 매칭된 최우선 ShortcutItem
    private var cachedRoleMap: [String: ShortcutItem] = [:]
    private let mapLock = NSLock()

    // Issue650: NSEvent 모니터 반환 토큰 저장 (메모리 누수 방지)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {
        logV("🚀 [ShortcutMgr] 초기화됨 (Phase 2: Active Registry Mode)")

        // ✅ Phase 2: 모니터 설정 및 초기 데이터 로드
        setupMonitors()

        // 초기 데이터 로드 (약간의 지연을 두어 다른 매니저들의 초기화 완료 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshAll()
            self?.debugInfo()  // ✅ 사용자 요청: 초기화 시 모든 단축키 로그 출력
        }

        // ✅ Phase 3: 리스너 마이그레이션
        setupGlobalHotkeyMonitoring()
    }

    // MARK: - Registry Methods

    /// 모든 소스로부터 단축키 목록 재구축
    func refreshAll() {
        logV("🚀 [ShortcutMgr] Refreshing all shortcuts...")
        registerAppGlobalShortcuts()
        registerTriggerKeys()
        registerBufferClearKeys()
        registerFolderShortcuts()

        NotificationCenter.default.post(name: .shortcutRegistryDidChange, object: nil)
    }

    // ... (Monitors setup omitted)

    // ...

    /// 폴더 단축키 (Prefix/Suffix) 등록 (RuleManager)
    func registerFolderShortcuts() {
        clear(type: .folderSuffix)
        clear(type: .folderPrefix)

        let rules = RuleManager.shared.getAllRules()
        for rule in rules {

            // 1. Suffix Shortcuts / Text
            let suffix = rule.suffix
            if !suffix.isEmpty {
                if suffix.hasPrefix("{") && suffix.hasSuffix("}") {
                    // 중괄호로 시작/끝 -> 단일 단축키임 (예: {keypad_comma})
                    let item = ShortcutItem(
                        id: "suffix_\(rule.name)",
                        keySpec: suffix,
                        type: .folderSuffix,
                        description: "Folder Suffix: \(rule.name)",
                        source: "RuleManager",
                        userInfo: ["folderName": rule.name]
                    )
                    register(item)
                } else {
                    // 레거시 텍스트 접미사에 대한 스마트 감지 (예: "⌃=")
                    let s = suffix
                    let modifiers = ["⌃", "^", "⌥", "⌘", "⇧"]
                    if modifiers.contains(where: { s.contains($0) }) && s.count <= 5 {
                        // Normalize '⌃' to '^'
                        let normalizedKeySpec = s.replacingOccurrences(of: "⌃", with: "^")

                        let item = ShortcutItem(
                            id: "suffix_\(rule.name)_legacy",
                            keySpec: normalizedKeySpec,
                            type: .folderSuffix,
                            description: "Folder Suffix (Legacy): \(rule.name)",
                            source: "RuleManager",
                            userInfo: ["folderName": rule.name]
                        )
                        register(item)
                        logV(
                            "🚀 [ShortcutMgr] Automatically registered legacy text suffix as shortcut: \(s) -> \(normalizedKeySpec) -> \(rule.name)"
                        )
                    }
                }
            }

            // 2. 접두사 단축키 (Issue316 & Issue486)
            // 중괄호 구문을 사용하여 접두사 필드로 통합됨
            let prefix = rule.prefix
            if !prefix.isEmpty {
                if prefix.hasPrefix("{") && prefix.hasSuffix("}") {
                    // ✅ Issue 605: Do not register simple typing keys (e.g. {keypad_comma}) as global shortcuts.
                    // This allows them to be handled by the text buffer/trigger processor as namespace prefixes.
                    if !isSimpleTypingKey(prefix) {
                        let item = ShortcutItem(
                            id: "prefix_\(rule.name)",
                            keySpec: prefix,
                            type: .folderPrefix,
                            description: "Folder Prefix: \(rule.name)",
                            source: "RuleManager",
                            userInfo: ["folderName": rule.name]
                        )

                        register(item)
                    } else {
                        logV(
                            "🚀 [ShortcutMgr] Prefix '\(prefix)' for '\(rule.name)' skipped from global shortcuts (Simple Typing Key)"
                        )
                    }
                }
                // If not brace-wrapped, it is a text prefix (e.g. "a", "_"), which is not registered as a hotkey here.
            }
        }

    }

    /// NotificationCenter 구독 설정
    private func setupMonitors() {
        // 1. 트리거 키 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTriggerKeyChange),
            name: .triggerKeyDidChange,
            object: nil
        )

        // 2. 설정 변경 감지 (앱 글로벌 단축키)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: .settingsDidChange,
            object: nil
        )

        // 3. 앱 설정 변경 감지 (AppSettingManager)
        // Issue 500_1: 알림을 수신하도록 리팩토링됨
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppSettingChange),
            name: .appSettingDidChange,
            object: nil
        )
    }

    @objc private func handleTriggerKeyChange(_ notification: Notification) {
        logV("🚀 [ShortcutMgr] Trigger Key Changed Notification")
        registerTriggerKeys()
    }

    @objc private func handleSettingsChange(_ notification: Notification) {
        logV("🚀 [ShortcutMgr] Settings Changed Notification")
        registerAppGlobalShortcuts()
    }

    @objc private func handleAppSettingChange(_ notification: Notification) {
        logV("🚀 [ShortcutMgr] AppSetting Changed Notification - Refreshing Buffer Clear Keys")
        registerBufferClearKeys()
    }

    // MARK: - Registry Methods

    /// 단축키 등록 (충돌 발생 시 우선순위 비교)
    /// - Returns: 등록 성공 여부
    @discardableResult
    func register(_ item: ShortcutItem) -> Bool {
        // 기존에 등록된 키 중 ID가 같은 것은 업데이트
        if let existingById = registeredShortcuts.first(where: { $0.id == item.id }) {
            registeredShortcuts.remove(existingById)
            registeredShortcuts.insert(item)
            updateCacheFor(keySpec: item.keySpec)
            logV("🚀 [ShortcutMgr] 단축키 업데이트 (ID 매칭): \(item.keySpec) (\(item.description))")
            return true
        }

        // 키 스펙이 같은 다른 항목이 있는지 확인 (충돌/중복)
        let conflictingItems = registeredShortcuts.filter { $0.keySpec == item.keySpec }

        if let conflict = conflictingItems.max(by: { $0.type.priority < $1.type.priority }) {  // 가장 높은 우선순위 항목 찾기
            // ✅ Issue 319: 같은 키가 있어도 등록은 허용하되, 우선순위가 낮으면 Warning 로그만 출력
            // 기존 로직: 우선순위 확인 후 실패 리턴
            // 변경 로직: 그냥 등록 (Set에 id가 다르므로 공존 가능). Resolve 시 우선순위 처리.

            if conflict.type.priority >= item.type.priority {
                // logI("🚀 [ShortcutMgr] 중복 등록 (Shadowed): \(item.keySpec)는 이미 \(conflict.description)(\(conflict.type))에서 사용 중. (새 항목의 우선순위가 낮거나 같음: \(item.type.priority) <= \(conflict.type.priority))")
                // 기존엔 return false 였으나, 이제 진행함. (등록 성공)
            } else {
                logI(
                    "🚀 [ShortcutMgr] Overlay 등록 : \(item.keySpec)가 \(conflict.description)(\(conflict.type))보다 우선순위가 높음."
                )
            }
        }

        registeredShortcuts.insert(item)
        updateCacheFor(keySpec: item.keySpec)
        logV("🚀 [ShortcutMgr] 단축키 등록: \(item.keySpec) (\(item.description)) - \(item.type)")
        return true
    }

    /// 특정 타입의 모든 단축키 제거 (일괄 갱신 전 사용)
    func clear(type: ShortcutType) {
        let countBefore = registeredShortcuts.count
        let itemsToRemove = registeredShortcuts.filter { $0.type == type }
        registeredShortcuts.subtract(itemsToRemove)
        rebuildCache()  // Issue 621_2: 일괄 캐시 재구축
        let removedCount = countBefore - registeredShortcuts.count
        if removedCount > 0 {
            logV("🚀 [ShortcutMgr] 타입 제거(\(type)): \(removedCount)개 삭제됨")
        }
    }

    /// 특정 소스의 모든 단축키 제거
    func clear(source: String) {
        let itemsToRemove = registeredShortcuts.filter { $0.source == source }
        registeredShortcuts.subtract(itemsToRemove)
        rebuildCache()  // Issue 621_2: 일괄 캐시 재구축
    }

    // MARK: - Caching Helpers

    private func updateCacheFor(keySpec: String) {
        mapLock.lock()
        defer { mapLock.unlock() }
        let candidates = registeredShortcuts.filter { $0.keySpec == keySpec }
        cachedRoleMap[keySpec] = candidates.max(by: { $0.type.priority < $1.type.priority })
    }

    private func rebuildCache() {
        mapLock.lock()
        defer { mapLock.unlock() }
        cachedRoleMap.removeAll(keepingCapacity: true)
        for item in registeredShortcuts {
            if let existing = cachedRoleMap[item.keySpec] {
                if item.type.priority > existing.type.priority {
                    cachedRoleMap[item.keySpec] = item
                }
            } else {
                cachedRoleMap[item.keySpec] = item
            }
        }
    }

    // MARK: - Query Methods

    /// 충돌 검사 (등록 전 확인용)
    func checkConflict(keySpec: String, excludeId: String? = nil) -> ShortcutItem? {
        return registeredShortcuts.first { item in
            item.keySpec == keySpec && item.id != excludeId
            // Note: 여기서는 여전히 "충돌하는 항목"을 반환하여 UI에서 경고를 띄울 수 있게 함
        }
    }

    /// 키 역할 해결 (Role Resolver)
    /// - Parameter keySpec: 입력된 키 스펙
    /// - Returns: 매칭된 최우선 단축키 항목
    func resolve(keySpec: String) -> ShortcutItem? {
        // Issue 621_2: O(1) Dictionary Lookup 활용
        mapLock.lock()
        let match = cachedRoleMap[keySpec]
        mapLock.unlock()

        if let match = match {
            logD(
                "🚀 [ShortcutMgr] Resolved Role for '\(keySpec.replacingOccurrences(of: "\n", with: "\\n"))' -> \(match.description) (ID: \(match.id))"
            )
            return match
        }

        return nil
    }

    // MARK: - Data Source Integration

    /// 앱 글로벌 단축키 등록 (PreferencesManager)
    private func registerAppGlobalShortcuts() {
        clear(type: .appShortcut)

        let prefs = PreferencesManager.shared

        // 1. History Viewer Hotkey
        let viewerKey = prefs.string(forKey: "history.viewer.hotkey")
        if !viewerKey.isEmpty {
            register(
                ShortcutItem(
                    id: "history.viewer.hotkey",
                    keySpec: viewerKey,
                    type: .appShortcut,
                    description: "History Viewer",
                    source: "Preferences"
                ))
        }

        // 2. Pause Hotkey
        let pauseKey = prefs.string(forKey: "history.pause.hotkey")
        if !pauseKey.isEmpty {
            register(
                ShortcutItem(
                    id: "history.pause.hotkey",
                    keySpec: pauseKey,
                    type: .appShortcut,
                    description: "Pause/Resume",
                    source: "Preferences"
                ))
        }

        // 3. Settings Hotkey (Issue727)
        let settingsKey = prefs.string(forKey: "settings.hotkey")
        if !settingsKey.isEmpty {
            register(
                ShortcutItem(
                    id: "settings.hotkey",
                    keySpec: settingsKey,
                    type: .appShortcut,
                    description: "Settings Window",
                    source: "Preferences"
                ))
        }

        // 4. Snippet Popup Hotkey (Legacy)
        // 참고: 팝업 키는 보통 "Space Space" 같은 시퀀스이거나 특정 키일 수 있음.
        // 현재 설정 구조상 Popup Key는 GeneralSettingsView에서 관리됨.
        let settings = SettingsManager.shared.load()
        let popupKey = settings.popupKeyShortcut
        if !popupKey.toHotkeyString.isEmpty {
            register(
                ShortcutItem(
                    id: "snippet.popup.hotkey",
                    keySpec: popupKey.toHotkeyString,
                    type: .appShortcut,
                    description: "Snippet Popup",
                    source: "Settings"
                ))
        }
    }

    /// 트리거 키 등록 (TriggerKeyManager)
    private func registerTriggerKeys() {
        clear(type: .triggerKey)

        let activeKeys = TriggerKeyManager.shared.activeTriggerKeys

        for key in activeKeys {
            // EnhancedTriggerKey.toKeySpec을 사용하여 일관된 KeySpec 생성
            let fullSpec = key.toKeySpec

            register(
                ShortcutItem(
                    id: "trigger.\(key.id)",
                    keySpec: fullSpec,  // 예: "⌥J" (Option+J)
                    type: .triggerKey,
                    description: "Trigger: \(key.displayName)",
                    source: "TriggerKeyManager",
                    userInfo: ["triggerKey": key]  // ✅ EnhancedTriggerKey 객체 전달
                ))
            logV("🚀 [ShortcutMgr] Registered Trigger: \(fullSpec) -> \(key.displayName)")
        }
    }

    /// KeyLogger modifiers 문자열을 ShortcutMgr keySpec 심볼로 변환
    private func convertModifiersToSpec(_ modifiers: String) -> String {
        var spec = ""
        // 순서 중요: ^ ⌥ ⌘ ⇧ (normalizeKeySpec 일치)
        if modifiers.contains("control") { spec += "^" }
        if modifiers.contains("option") { spec += "⌥" }
        if modifiers.contains("command") { spec += "⌘" }
        if modifiers.contains("shift") { spec += "⇧" }
        return spec
    }

    /// 버퍼 클리어 키 등록 (AppSettingManager)
    private func registerBufferClearKeys() {
        clear(type: .bufferClear)

        let clearKeys = AppSettingManager.shared.bufferClearKeys
        for char in clearKeys {
            let desc = describeChar(char)
            register(
                ShortcutItem(
                    id: "bufferClear.\(desc)",
                    keySpec: desc,  // ✅ Issue 282: KeyEventMonitor와 일치하도록 정규화 (예: " "가 아니라 "Space")
                    type: .bufferClear,
                    description: "Buffer Clear: \(desc)",
                    source: "AppSettingManager"
                ))
        }
    }

    private func describeChar(_ char: Character) -> String {
        switch char {
        case " ": return "Space"
        case "\n": return "Enter"
        case "\t": return "Tab"
        case "\r": return "Return"
        default: return String(char)
        }
    }

    /// Issue 605: Check if a key spec represents a simple typing key (character generating, no modifiers)
    private func isSimpleTypingKey(_ keySpec: String) -> Bool {
        // 1. Check for modifiers
        let modifiers = ["^", "⌃", "⌥", "⌘", "⇧"]
        if modifiers.contains(where: { keySpec.contains($0) }) { return false }

        // 2. Unwrap braces if present
        let content =
            (keySpec.hasPrefix("{") && keySpec.hasSuffix("}"))
            ? String(keySpec.dropFirst().dropLast())
            : keySpec

        // 3. Check for specific non-typing keys (Control/Nav)
        let nonTypingKeys = [
            "Enter", "Return", "Tab", "Space", "Backspace", "Delete", "Escape", "Esc", "Up",
            "Down", "Left", "Right", "PageUp", "PageDown", "Home", "End", "F1", "F2", "F3",
            "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16",
            "F17", "F18", "F19", "F20",
        ]
        if nonTypingKeys.contains(where: { content.caseInsensitiveCompare($0) == .orderedSame }) {
            return false
        }

        // 4. Function keys pattern check (General)
        if content.lowercased().hasPrefix("f"), Int(content.dropFirst()) != nil {
            return false
        }

        // 5. Keypad Enter check
        if content.lowercased() == "keypad_enter" {
            return false
        }

        // Otherwise, assume it is a typing key (e.g. "a", "1", ",", "{keypad_comma}")
        return true
    }

    // MARK: - Debug

    func debugInfo() {
        // Calculate counts
        let appShortcutCount = registeredShortcuts.filter { $0.type == .appShortcut }.count
        let triggerKeyCount = registeredShortcuts.filter { $0.type == .triggerKey }.count
        let bufferClearCount = registeredShortcuts.filter { $0.type == .bufferClear }.count
        let folderPrefixCount = registeredShortcuts.filter { $0.type == .folderPrefix }.count
        let folderSuffixCount = registeredShortcuts.filter { $0.type == .folderSuffix }.count
        let folderTotal = folderPrefixCount + folderSuffixCount

        let total = registeredShortcuts.count

        logI(
            "🚀총 등록된 단축키: \(total)개 \"App Shortcuts (\(appShortcutCount)) + Trigger Keys (\(triggerKeyCount)) + Buffer Clear Keys (\(bufferClearCount)) + Folder Shortcuts (\(folderTotal))\""
        )

        let sorted = registeredShortcuts.sorted {
            if $0.type.priority != $1.type.priority {
                return $0.type.priority > $1.type.priority
            }
            return $0.keySpec < $1.keySpec
        }

        for item in sorted {
            logV("🚀  [\(item.type)] \(item.keySpec): \(item.description) (ID: \(item.id))")
        }

        // 최종 요약 - PSKeyManager (통합된 "추가된 접미사" 로그)
        PSKeyManager.shared.logSummary()
    }

    // MARK: - Global Monitoring (Phase 3)

    func setupGlobalHotkeyMonitoring() {
        // Issue650: 기존 모니터가 있으면 먼저 해제 (재호출 시 중복 방지)
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }

        // 1. NSEvent Global Monitor (반환 토큰 저장)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }

        // 2. NSEvent Local Monitor (반환 토큰 저장)
        // Issue763: 단축키 매칭 시 return nil로 이벤트 소비하여 비프음 방지
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleGlobalKeyEvent(event) == true {
                return nil  // 이벤트 소비 → 비프음 방지
            }
            return event
        }

        logV("🚀 [ShortcutMgr] Global Hotkey Monitoring Started")
    }

    // Issue763: 반환타입 Bool로 변경 - 매칭 시 true 반환하여 localMonitor에서 이벤트 소비
    @discardableResult
    private func handleGlobalKeyEvent(_ event: NSEvent) -> Bool {
        // .appShortcut 타입만 검사
        let appShortcuts = registeredShortcuts.filter { $0.type == .appShortcut }

        for item in appShortcuts {
            if isHotkeyMatch(event: event, hotkeyString: item.keySpec) {
                logI("🚀 [ShortcutMgr] Hotkey Detected: \(item.keySpec) -> \(item.id)")
                executeAction(for: item.id)
                return true
            }
        }
        return false
    }

    private func executeAction(for id: String) {
        // ✅ Issue 288: 현재 스레드(로컬 모니터 컨텍스트)에서 커서 위치를 즉시 캡처
        // 이는 컨텍스트 전환 전에 *현재 초점이 맞춰진* 앱에서 커서를 가져오도록 보장함.
        let cursorRect = CursorTracker.shared.getCursorRect()

        DispatchQueue.main.async {
            switch id {
            case "history.viewer.hotkey":
                // Pass the eagerly captured cursor rect
                HistoryViewerManager.shared.show(cursorRect: cursorRect)
            case "history.pause.hotkey":
                self.toggleHistoryPause()
            case "settings.hotkey":
                SettingsWindowManager.shared.toggleSettings()
            case "snippet.popup.hotkey":
                // Issue 429: 알림을 통해 팝업 트리거
                // 글로벌 핫키가 감지되면 KeyEventMonitor에 처리를 요청함.
                NotificationCenter.default.post(
                    name: NSNotification.Name("fSnippetShowPopup"), object: nil)
            case "history.registerSnippet.hotkey":
                // Future Implementation
                break
            default:
                logW("🚀 [ShortcutMgr] Unknown Action ID: \(id)")
            }
        }
    }

    private func toggleHistoryPause() {
        let prefs = PreferencesManager.shared
        let current = prefs.bool(forKey: "history.isPaused", defaultValue: false)
        let newState = !current
        prefs.set(newState, forKey: "history.isPaused")

        NotificationCenter.default.post(
            name: NSNotification.Name("historyPauseStateChanged"), object: newState)

        let l10n = LocalizedStringManager.shared
        let message = newState ? l10n.string("toast.clipboard_paused") : l10n.string("toast.clipboard_resumed")
        let icon = newState ? "pause.fill" : "play.fill"
        ToastManager.shared.showToast(message: message, iconName: icon)
    }

    // MARK: - Hotkey Matching Helpers

    /// 주어진 NSEvent가 특정 핫키 문자열(예: "^⌥⌘P" 또는 "right_command+P")과 일치하는지 확인
    func isHotkeyMatch(event: NSEvent, hotkeyString: String) -> Bool {
        // Issue 298: 상세 수식어 매칭
        let isVerbose = hotkeyString.contains("right_") || hotkeyString.contains("left_")

        if isVerbose {
            // 1. 수식어 매칭 (엄격한 문자열 비교)
            let eventModifiersStr = event.modifierFlags.distinctDescription

            // 키 문자열에서 수식어 추출 (키 부분 제거)
            // hotkeyString 형식: "right_command+left_shift+J"
            // 키 자체가 "+"일 수 있는 경우 지원 필요 (이 형식에서는 거의 없지만)
            var hotkeyModifiersStr = hotkeyString

            // 마지막 부분(키)을 제거하여 수식어 가져오기
            // 마지막 '+'를 구분자로 가정.
            if let lastPlusIndex = hotkeyString.lastIndex(of: "+") {
                let keyPart = hotkeyString[hotkeyString.index(after: lastPlusIndex)...]
                // Verify keyPart length to avoid stripping if it's just "right_command" (no key?) - unlikely for hotkey
                hotkeyModifiersStr = String(hotkeyString[..<lastPlusIndex])

                // 2. Match Key Character
                let keyStr = String(keyPart)

                // Key Matching Logic (Verbose path)
                // Check KeyCode first (Reverse Map)
                if let targetKeyCodes = ShortcutMgr.reverseKeyMap[keyStr.uppercased()] {
                    if !targetKeyCodes.contains(event.keyCode) {
                        return false
                    }
                } else {
                    // Fallback to Char match
                    let eventChar = event.charactersIgnoringModifiers?.uppercased()
                    if keyStr.uppercased() != eventChar {
                        return false
                    }
                }
            }

            // Modifiers Match
            // Note: distinctDescription uses "+" separator, same as toKeySpec
            return eventModifiersStr == hotkeyModifiersStr

        } else {
            // 표준 기호 매칭 (기존 로직)
            // ✅ Issue 352: 명시적 엄격 수식어 매칭
            // 추가 수식어가 눌리지 않았는지 확인하기 위해 각 수식어 플래그를 개별적으로 확인합니다.

            // 1. Command
            let hasCommand = event.modifierFlags.contains(.command)
            let requiresCommand = hotkeyString.contains("⌘")
            if hasCommand != requiresCommand { return false }

            // 2. Option
            let hasOption = event.modifierFlags.contains(.option)
            let requiresOption = hotkeyString.contains("⌥")
            if hasOption != requiresOption { return false }

            // 3. Control (두 기호 모두 확인)
            let hasControl = event.modifierFlags.contains(.control)
            let requiresControl = hotkeyString.contains("⌃") || hotkeyString.contains("^")
            if hasControl != requiresControl { return false }

            // 4. Shift
            let hasShift = event.modifierFlags.contains(.shift)
            let requiresShift = hotkeyString.contains("⇧")
            if hasShift != requiresShift { return false }

            // Issue 621_2: 매 프레임 발생하는 무거운 문자열 치환 연산 제거
            // Modifiers 기호들을 제거하고 순수 키 부분만 추출
            var keyStr = ""
            for char in hotkeyString {
                switch char {
                case "^", "⌃", "⌥", "⌘", "⇧", " ": continue
                default: keyStr.append(char)
                }
            }

            // ✅ Issue 513 Fix: Unwrap braces for matching
            if keyStr.hasPrefix("{") && keyStr.hasSuffix("}") {
                keyStr = String(keyStr.dropFirst().dropLast())
            }

            let lookUpKey = keyStr.lowercased()

            // 3. KeyCode 매칭 (Case-insensitive)
            // Note: reverseKeyMap keys are mixed case, so we search iteratively or normalize.
            var targetKeyCodes: [UInt16]? = nil
            for (name, codes) in ShortcutMgr.reverseKeyMap {
                if name.lowercased() == lookUpKey {
                    targetKeyCodes = codes
                    break
                }
            }

            if targetKeyCodes == nil {
                for (name, codes) in TriggerKeyManager.legacyKeyMap {
                    if name.lowercased() == lookUpKey {
                        targetKeyCodes = codes
                        break
                    }
                }
            }

            if let targetCodes = targetKeyCodes {
                if targetCodes.contains(event.keyCode) {
                    return true
                }
            }

            // 4. 문자 매칭 (폴백)
            if keyStr.count == 1 {
                let keyChar = keyStr.lowercased()
                let eventChar = event.charactersIgnoringModifiers?.lowercased()

                return keyChar == eventChar
            }

            return false
        }
    }

    /// KeyEventInfo를 사용하는 편의 메서드
    func isHotkeyMatch(_ keyInfo: KeyEventInfo, hotkeyString: String) -> Bool {
        // Issue 298: 상세 수식어 매칭
        // KeyEventInfo.modifiers는 NSEvent.ModifierFlags입니다.
        // 하지만 distinctDescription 프로퍼티가 NSEvent extension에 있다면 여기서도 사용 가능할 수 있습니다.
        // 만약 없다면 직접 구현해야 합니다.
        // 여기서는 KeyEventInfo -> NSEvent(가장 근접한) 변환을 통해 기존 로직을 재사용하는 것이 안전할 수 있습니다.
        // 하지만 NSEvent 생성은 복잡하므로, 로직을 복제하거나 공통 로직으로 추출하는 것이 좋습니다.

        // 간단한 접근: isVerbose 여부에 따라 분기

        let isVerbose = hotkeyString.contains("right_") || hotkeyString.contains("left_")

        if isVerbose {
            // 수식어 매칭 (엄격한 문자열 비교)
            // KeyEventInfo는 distinctDescription을 직접 지원하지 않을 수 있음.
            // 하지만 normalizedKeySpec을 사용하여 비교할 수 있음.

            let eventSpec = keyInfo.normalizedKeySpec()

            // hotkeyString이 "right_command+J"라면 eventSpec도 "right_command+J"여야 함.
            // normalizedKeySpec은 정확히 이 포맷을 따름.
            return eventSpec == hotkeyString

        } else {
            // 표준 기호 매칭
            // 1. Command
            let hasCommand = keyInfo.modifiers.contains(.command)
            let requiresCommand = hotkeyString.contains("⌘")
            if hasCommand != requiresCommand { return false }

            // 2. Option
            let hasOption = keyInfo.modifiers.contains(.option)
            let requiresOption = hotkeyString.contains("⌥")
            if hasOption != requiresOption { return false }

            // 3. Control
            let hasControl = keyInfo.modifiers.contains(.control)
            let requiresControl = hotkeyString.contains("⌃") || hotkeyString.contains("^")
            if hasControl != requiresControl { return false }

            // 4. Shift
            let hasShift = keyInfo.modifiers.contains(.shift)
            let requiresShift = hotkeyString.contains("⇧")
            if hasShift != requiresShift { return false }

            // Issue 621_2: 무거운 문자열 치환 연산 제거 (isHotkeyMatch 최적화)
            var keyStr = ""
            for char in hotkeyString {
                switch char {
                case "^", "⌃", "⌥", "⌘", "⇧", " ": continue
                default: keyStr.append(char)
                }
            }
            keyStr = keyStr.uppercased()

            // 3. KeyCode 매칭
            var targetKeyCodes = ShortcutMgr.reverseKeyMap[keyStr]
            if targetKeyCodes == nil {
                targetKeyCodes = TriggerKeyManager.legacyKeyMap[keyStr]
            }

            if let targetCodes = targetKeyCodes {
                if targetCodes.contains(keyInfo.keyCode) {
                    return true
                }
            }

            // 4. 문자 매칭 (폴백)
            if keyStr.count == 1 {
                let keyChar = keyStr.last?.uppercased()
                let eventChar =
                    keyInfo.charactersIgnoringModifiers?.uppercased()
                    ?? keyInfo.character?.uppercased()

                return keyChar == eventChar
            }

            return false
        }
    }

    // Reverse mapping from Display String to KeyCodes
    private static var reverseKeyMap: [String: [UInt16]] = {
        var map: [String: [UInt16]] = [
            "A": [0], "S": [1], "D": [2], "F": [3], "H": [4], "G": [5], "Z": [6], "X": [7],
            "C": [8], "V": [9],
            "B": [11], "Q": [12], "W": [13], "E": [14], "R": [15], "Y": [16], "T": [17],
            "1": [18, 83], "2": [19, 84],
            "3": [20, 85], "4": [21, 86], "6": [22, 88], "5": [23, 87], "=": [24, 81],
            "9": [25, 92], "7": [26, 89], "-": [27, 78], "8": [28, 91],
            "0": [29, 82], "]": [30], "O": [31], "U": [32], "[": [33], "I": [34], "P": [35],
            "[Return]": [36, 76], "L": [37],
            "J": [38], "'": [39], "K": [40], ";": [41], "\\": [42], ",": [43], "/": [44, 75],
            "N": [45], "M": [46],
            ".": [47, 65], "[Tab]": [48], "Space": [49], "`": [50], "[Backspace]": [51],
            "[Escape]": [53],
            "*": [67], "+": [69], "[Clear]": [71],
            "F5": [96], "F6": [97], "F7": [98], "F3": [99], "F8": [100], "F9": [101], "F11": [103],
            "F10": [109], "F12": [111], "F13": [105], "F14": [107], "F15": [113], "F16": [114],
        ]
        // Merge Shared Keypad Mappings (SSOT)
        map.merge(SharedKeyMap.reverseMapping) { (_, new) in new }
        return map
    }()

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Issue650: NSEvent 모니터 명시적 해제
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
