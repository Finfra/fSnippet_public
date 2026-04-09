import ApplicationServices
import Cocoa
import Foundation

// MARK: - 키 이벤트 정보 구조체
// Moved to KeyEventInfo.swift

// MARK: - 키 이벤트 처리 델리게이트 프로토콜

/// 키 이벤트 처리 델리게이트 프로토콜
protocol KeyEventProcessorDelegate: AnyObject {
    func didDetectTriggerKey(_ buffer: String)
    func didDetectPopupKey()
    func didTypeKey(_ keyInfo: KeyEventInfo)
    func didReceiveInterceptedArrowKey(_ keyCode: UInt16)
    func didReceiveInterceptedEscapeKey()
    func didTriggerShortcut(_ shortcut: ShortcutItem)  // Issue278: ShortcutMgr 매칭 알림
    func handleKeyEventAndReturnSuccess(_ keyInfo: KeyEventInfo) -> Bool  // Issue 583: Support Sync Trigger
}

// MARK: - 개선된 KeyEventProcessor

// MARK: - 스레드 안전한 Shortcut 캐시
class ThreadSafeShortcutCache {
    private let queue = DispatchQueue(label: "shortcut.cache", attributes: .concurrent)
    private var _shortcuts: [ShortcutItem] = []

    var shortcuts: [ShortcutItem] {
        get { queue.sync { _shortcuts } }
        set { queue.sync(flags: .barrier) { self._shortcuts = newValue } }
    }
}

// MARK: - 개선된 KeyEventProcessor

class KeyEventProcessor: CGEventTapManagerDelegate {

    // MARK: - Properties

    private var globalMonitor: Any?
    private var localMonitor: Any?
    // private var cgEventTap: CFMachPort? // Removed
    private weak var delegate: KeyEventProcessorDelegate?
    private var isCleanedUp = false

    // Managers
    // Managers
    private let cgEventTapManager = CGEventTapManager()
    private let contextManager = WindowContextManager.shared

    // Cache
    private let shortcutCache = ThreadSafeShortcutCache()

    // Issue720_4: Settings 캐시 (매 키 이벤트마다 SettingsManager.load() 호출 비용 감소)
    private var cachedSettings: SnippetSettings? = nil
    private var settingsCacheTime: TimeInterval = 0
    private let settingsCacheDuration: TimeInterval = 1.0  // 1초 캐시

    private func loadSettingsCached() -> SnippetSettings {
        let now = CACurrentMediaTime()
        if cachedSettings == nil || (now - settingsCacheTime) > settingsCacheDuration {
            cachedSettings = SettingsManager.shared.load()
            settingsCacheTime = now
        }
        return cachedSettings!
    }

    // ✅ Issue466: Modifier State Tracking for De-bouncing Logs
    var lastFlags: CGEventFlags = []

    // ✅ Issue38: TriggerKeyManager 접근을 위한 참조
    private var triggerKeyManager: TriggerKeyManager {
        return TriggerKeyManager.shared
    }

    // 팝업 네비게이션 키 정의 (Enter 제거 - 일반 특수키로 처리)
    private let popupNavigationKeys: Set<UInt16> = [125, 126, 53]  // Down, Up, Escape

    // ✅ Issue 312: Modifier-Only Trigger State (Trigger on Release)
    var pendingModifierTriggerKeyCode: UInt16? = nil
    var pendingModifierFlags: CGEventFlags? = nil  // Fix: Capture original flags for lookup on release

    func setPendingModifierTrigger(_ keyCode: UInt16, flags: CGEventFlags) {
        pendingModifierTriggerKeyCode = keyCode
        pendingModifierFlags = flags
    }

    func cancelPendingModifierTrigger() {
        pendingModifierTriggerKeyCode = nil
        pendingModifierFlags = nil
    }

    /// ✅ Issue395: Reset all transient state (called when app/context changes)
    func resetState() {
        cancelPendingModifierTrigger()
        // Add other state resets here if needed
        logV("🎮 [KeyEventProcessor] State Reset (Pending Modifiers Cleared)")
    }

    // 특수 키 코드 매핑 (팝업 네비게이션 키 제외)
    private let specialKeyCodes: [UInt16: String] = [
        36: "\n",  // Return
        48: "\t",  // Tab
        49: " ",  // Space
        // 53: "",       // Escape - 팝업 네비게이션 키로 이동
        51: "",  // Backspace (handle separately)
        117: "",  // Delete (ignore)
        123: "",  // Left Arrow (ignore)
        124: "",  // Right Arrow (ignore)
            // 125, 126, 36, 53 제거: CGEventTap에서 전담 처리 (팝업 네비게이션 키)
    ]

    // MARK: - Initialization

    init() {
        // 델리게이트는 나중에 설정
        cgEventTapManager.delegate = self
        setupTriggerKeyChangeNotification()
    }

    /// ✅ Issue38: 트리거키 변경 알림 구독
    private func setupTriggerKeyChangeNotification() {
        NotificationCenter.default.addObserver(
            forName: .triggerKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            logV("🎮 [KeyEventProcessor] 트리거키 변경 감지 - CGEventTap 재초기화")

            if let triggerKey = notification.object as? EnhancedTriggerKey {
                logV(
                    "🎮 [KeyEventProcessor] 새 트리거키: \(triggerKey.displayName) (\(triggerKey.displayCharacter))"
                )
            }

            // CGEventTap 재초기화
            self.reinitializeCGEventTap()
        }

        // ✅ Issue 351 & 537: 단축키 변경 감지 강화
        NotificationCenter.default.addObserver(
            forName: .shortcutRegistryDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.updateShortcutCache()
            self?.cachedSettings = nil  // Issue720_4: 단축키 변경 시 Settings 캐시도 무효화
            logV("🎮 [KeyEventProcessor] Shortcut Registry Changed - Cache Updated")
        }

        // 초기 로드
        updateShortcutCache()
    }

    /// 모든 종류의 단축키 캐시 업데이트 (Issue 537)
    private func updateShortcutCache() {
        // ShortcutMgr에서 관리하는 모든 단축키를 가져옴
        DispatchQueue.main.async { [weak self] in
            let shortcuts = Array(ShortcutMgr.shared.registeredShortcuts)
            self?.shortcutCache.shortcuts = shortcuts
            logV("🎮 [KeyEventProcessor] 통합 Shortcut 캐시 업데이트 완료: \(shortcuts.count)개")
        }
    }

    func setDelegate(_ delegate: KeyEventProcessorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Public Methods

    func startMonitoring() {
        guard globalMonitor == nil && localMonitor == nil else {
            logW("🎮 KeyEventProcessor가 이미 실행 중입니다")
            return
        }

        guard isAccessibilityPermissionGranted() else {
            logE("🎮 접근성 권한이 필요합니다")
            requestAccessibilityPermission()
            return
        }

        setupGlobalMonitor()
        setupLocalMonitor()
        cgEventTapManager.start()  // Use Manager

        logV("🎮 개선된 KeyEventProcessor 시작됨 (Global + Local + Manager-based CGEventTap)")
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        cgEventTapManager.stop()

        logV("🎮 개선된 KeyEventProcessor 중지됨")
    }

    /// 일시 중지 (Shortcut 실행 시 Event Tap 차단 해제용 - Issue 568_1)
    func suspendEventTap() {
        cgEventTapManager.stop()
        logV("🎮 [KeyEventProcessor] Event Tap suspended (for Shortcut Input)")
    }

    /// 재개 (Shortcut 실행 완료 후 Event Tap 복구용 - Issue 568_1)
    func resumeEventTap() {
        cgEventTapManager.start()
        logV("🎮 [KeyEventProcessor] Event Tap resumed")
    }

    /// ✅ Issue38: CGEventTap 재초기화 (트리거키 변경 시)
    private func reinitializeCGEventTap() {
        cgEventTapManager.reinitialize()
    }

    func cleanup() {
        guard !isCleanedUp else { return }

        isCleanedUp = true
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
        delegate = nil

        logV("🎮 개선된 KeyEventProcessor 정리 완료")
    }

    // MARK: - 스레드 안전한 상태 관리

    /// 팝업 표시 상태 업데이트 (스레드 안전)
    func updatePopupState(isVisible: Bool) {
        contextManager.isVisible = isVisible
        logV("🎮 [ContextManager] 팝업 상태 업데이트: \(isVisible)")
    }

    /// 텍스트 대체 상태 업데이트 (스레드 안전)
    func updateReplacementState(isReplacing: Bool) {
        contextManager.isReplacing = isReplacing
        logV("🎮 [ContextManager] 텍스트 대체 상태 업데이트: \(isReplacing)")
    }

    /// ✅ Issue118: 앱 활성 상태 업데이트
    func updateAppActiveState(isActive: Bool) {
        contextManager.isAppActive = isActive
        logV("🎮 [ContextManager] 앱 활성 상태 업데이트: \(isActive)")
    }

    /// 현재 텍스트 대체 중인지 확인 (CGEventTap에서 사용)
    func isCurrentlyReplacing() -> Bool {
        // ✅ Issue 583_4 Fix: 플레이스홀더 입력 중(AppActive)에는 텍스트 대체 중이라도
        // 키 입력을 막으면 안됨. 사용자가 입력창에 타이핑해야 하기 때문.
        if contextManager.isAppActive {
            return false
        }
        return contextManager.isReplacing
    }

    /// ✅ Issue118: 현재 앱이 활성화(Key Window) 상태인지 확인
    func isAppActive() -> Bool {
        return contextManager.isAppActive
    }

    /// Protocol Conformance for CGEventTapManagerDelegate
    func shouldInterceptArrowKey(_ keyCode: UInt16) -> Bool {
        return shouldInterceptArrowKeyThreadSafe(keyCode)
    }

    /// 스레드 안전한 화살표 키 차단 여부 확인

    /// 스레드 안전한 화살표 키 차단 여부 확인
    /// 스레드 안전한 화살표 키 차단 여부 확인
    func shouldInterceptArrowKeyThreadSafe(_ keyCode: UInt16) -> Bool {
        // 텍스트 대체 중이면 모든 키 차단 (단, 앱이 활성화된 경우 제외 - Issue 583_4)
        if contextManager.isReplacing && !contextManager.isAppActive {
            logD("🎮 [ThreadSafe] 텍스트 대체 중이므로 차단: true")
            return true
        }

        // 팝업이 표시된 상태에서 팝업 네비게이션 키만 차단
        let isPopupNavigationKey = popupNavigationKeys.contains(keyCode)
        let shouldBlock = contextManager.isVisible && isPopupNavigationKey

        logTrace(
            "🎮 [ThreadSafe] 최종 결정: \(shouldBlock) (팝업: \(contextManager.isVisible), 팝업네비게이션키: \(isPopupNavigationKey))"
        )
        return shouldBlock
    }

    // MARK: - CGEventTap 지원 메서드

    func handleInterceptedSpecialKey(_ keyCode: UInt16) {
        switch keyCode {
        case 125, 126:  // Down, Up 화살표 키
            delegate?.didReceiveInterceptedArrowKey(keyCode)
        case 53:  // Escape 키
            delegate?.didReceiveInterceptedEscapeKey()
        default:
            break
        }
    }

    // ✅ Issue392_1: 차단되지 않은 팝업 네비게이션 키 처리
    func handleNonInterceptedPopupNavigationKey(_ keyCode: UInt16, modifiers: CGEventFlags) {
        // Delegate에게 일반 키 입력으로 전달 (KeyEventMonitor에서 Arrow Key 감지 로직이 동작하도록)
        delegate?.didTypeKey(
            KeyEventInfo(
                type: .special,  // Arrow key is special
                character: "",  // Char doesn't matter much if keyCode is checked, but empty is safe
                keyCode: keyCode,
                modifiers: modifiers
            ))
    }

    /// CGEventTap에서 ◊ 키 이벤트 동기 처리 - Issue38 완전 해결 (하위 호환성)
    func handleDiamondKeyFromCGEventTapSync(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        return handleTriggerKeyFromCGEventTapSync(
            keyCode: keyCode, modifiers: modifiers, triggerChar: "◊")
    }

    /// CGEventTap에서 동적 트리거키 이벤트 동기 처리 - Issue38 완전 해결
    func handleTriggerKeyFromCGEventTapSync(
        keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String
    ) -> Bool {
        logV(
            "🎮 [TRIGGER_SYNC] handleTriggerKeyFromCGEventTapSync Called. TriggerChar: '\(triggerChar)'"
        )

        guard let delegate = delegate else {
            logW("🎮 ⚠️ [TRIGGER_KEY] delegate가 nil - 스니펫 확장 불가")
            return false
        }

        let keyInfo = KeyEventInfo(
            type: .regular,
            character: triggerChar,
            keyCode: keyCode,
            modifiers: modifiers
        )

        // ✅ Issue 583 Fix: Use protocol method instead of casting to KeyEventMonitor
        // The delegate (KeyEventHandler) now implements this method via protocol.
        let success = delegate.handleKeyEventAndReturnSuccess(keyInfo)
        logI("🎮 [Issue38] 트리거키 '\(triggerChar)' 동기 처리 결과: \(success ? "스니펫 확장 성공" : "스니펫 없음")")
        return success
    }

    // MARK: - CGEventTapManagerDelegate Implementation

    // 비동기 트리거 (Manager에서 위임됨)
    func handleTriggerKeyAsync(keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String) {
        handleTriggerKeyFromCGEventTap(
            keyCode: keyCode, modifiers: modifiers, triggerChar: triggerChar)
    }

    // 동기 트리거 (Manager에서 위임됨)
    func handleTriggerKeySync(keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String) -> Bool
    {
        return handleTriggerKeyFromCGEventTapSync(
            keyCode: keyCode, modifiers: modifiers, triggerChar: triggerChar)
    }

    // 앱 단축키 동기화 (Manager에서 위임됨)
    func handleAppShortcutSync(_ shortcut: ShortcutItem) {
        handleAppShortcutFromCGEventTapSync(shortcut)
    }

    // 고스트 키 (Manager에서 위임됨)
    func handleGhostKey(_ nsEvent: NSEvent) {
        handleKeyEvent(nsEvent, isLocal: true)
    }

    // 레거시 구현 (내부용)

    /// CGEventTap에서 App Shortcut 발견 시 처리 (동기/비동기 공용)
    private func handleAppShortcutFromCGEventTapSync(_ shortcut: ShortcutItem) {
        logV("🎮 [APP_SHORTCUT_SYNC] handleAppShortcutFromCGEventTapSync Called. ID: \(shortcut.id)")
        delegate?.didTriggerShortcut(shortcut)
    }

    /// CGEventTap에서 동적 트리거키 이벤트 비동기 처리 (하위 호환성)
    private func handleTriggerKeyFromCGEventTap(
        keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String
    ) {
        // ✅ Issue 312 수정: 레거시 로직 사용 중지. triggerChar를 올바르게 전파하는 동기 로직 사용.
        _ = handleTriggerKeyFromCGEventTapSync(
            keyCode: keyCode, modifiers: modifiers, triggerChar: triggerChar)
    }

    /// 해당 키코드가 트리거키인지 확인 (Modifiers 포함)
    func isTriggerKey(_ keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        // ✅ Issue 286: 화살표 키(123-126)는 절대 트리거키로 동작하지 않게 차단
        if [123, 124, 125, 126].contains(keyCode) {
            return false
        }

        // 🚀 Issue 583_10: Optimization - Check active triggers first using integer matching
        // This avoids string operations for registered trigger keys.
        let nsModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers.rawValue))
        if TriggerKeyManager.shared.matchTriggerKey(
            keyCode: keyCode, modifiers: nsModifiers.rawValue, character: nil) != nil
        {
            return true
        }

        // 1. KeySpec 생성 (PSKeyManager 포맷 호환)
        // Note: modifiers가 비어있으면 일반 문자(예: `)가 될 수 있음.
        // generateKeySpec은 "Keypad1"이나 "right_command" 같은 형식을 반환함.
        // PSKeyManager에는 TriggerKeyManager.syncToPSKeyManager()를 통해
        // displayCharacter, keySequence(modifiers 포함), id가 모두 등록되어 있음.

        // NSEvent가 없으므로 character는 nil로 전달하여 추론하게 함
        let keySpec = generateKeySpec(keyCode: keyCode, modifiers: modifiers, character: nil)

        // Issue 506: keySpec 정규화 (중괄호로 감싸기) - PSKeyManager 형식과 일치
        // TriggerKeyManager는 이제 {keypad_comma}와 같은 토큰에 대해 중괄호를 강제합니다.
        let normalizedSpec = EnhancedTriggerKey.wrapInBraces(keySpec)

        // 2. PSKeyManager를 통한 O(1) 조회
        // TriggerKeyManager가 activeTriggerKeys를 PSKeyManager.suffixes로 동기화해두었으므로
        // isSuffix check만으로 트리거 키 여부 확인 가능.
        if PSKeyManager.shared.isSuffix(normalizedSpec) {
            // ✅ Issue 603: Suffix(폴백) 매칭인 경우, 해당 키가 수정자 키코드(54-63)라면
            // 모디파이어 플래그가 없는 상태(릴리스 이벤트)에서는 트리거로 인정하지 않음.
            // 이는 {right_option} 등을 뗄 때 트리거가 다시 발동되는 것을 방지함.
            if [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode) {
                let meaningfulModifiers = modifiers.intersection([
                    .maskCommand, .maskControl, .maskAlternate, .maskShift,
                ])
                if meaningfulModifiers.isEmpty {
                    logV(
                        "🎮 [Issue 603] Modifier Key Release (\(keyCode)) - Skipping Trigger Fallback"
                    )
                    return false
                }
            }
            return true
        }

        // 3. Fallback: 기본 트리거키 확인 (실시간 설정)
        // PSKeyManager에 등록되지 않은(동기화 딜레이 등) 기본 키를 위한 안전장치
        let currentSettings = SettingsManager.shared.load()
        let realTimeDefaultSymbol = currentSettings.defaultSymbol

        if let realTimeTriggerKey = EnhancedTriggerKey.presets.first(where: {
            $0.displayCharacter == realTimeDefaultSymbol
        }) {
            if realTimeTriggerKey.hardwareKeyCode == keyCode {
                // Modifier 검사
                let requiredModifiers = realTimeTriggerKey.modifiers
                let inputModifiers = convertModifiersToString(modifiers)

                if requiredModifiers == inputModifiers {
                    return true
                }

                // Modifier 없는 경우 (단독 키)
                if requiredModifiers.isEmpty {
                    let meaningfulModifiers = modifiers.intersection([
                        .maskCommand, .maskControl, .maskAlternate,
                    ])
                    if meaningfulModifiers.isEmpty {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// 키코드에 해당하는 트리거 문자 반환 (Modifiers 포함)
    func getTriggerCharacter(_ keyCode: UInt16, modifiers: CGEventFlags) -> String {
        // 🚀 Issue 583_10: Optimization using Integer Matching
        // This replaces the string conversion and array iteration with optimized lookup
        // matchTriggerKey also handles the "Real-time settings sync" logic internally.

        let nsModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers.rawValue))
        if let matchedKey = triggerKeyManager.matchTriggerKey(
            keyCode: keyCode, modifiers: nsModifiers.rawValue, character: nil)
        {
            return matchedKey.displayCharacter
        }

        // Legacy input modifiers string required for logging or fallbacks below?
        let inputModifiersStr = convertModifiersToString(modifiers)

        // 3. Fallback: 표준 문자 키(Standard Key)인 경우 KeyLabel 반환 (Issue Fix)
        // TriggerKeyManager는 일반 문자 키를 activeTriggerKeys에 포함하지 않을 수 있음(최적화)
        // 하지만 isTriggerKey가 true를 반환했다면(Suffix인 경우), 해당 문자를 반환해야 함.
        let meaningfulModifiers = modifiers.intersection([
            .maskCommand, .maskControl, .maskAlternate, .maskShift,
        ])
        if meaningfulModifiers.isEmpty || meaningfulModifiers == .maskShift {
            let resolvedLabel = SingleShortcutMapper.shared.getKeyLabel(for: keyCode)
            // 물음표가 아니고 유효한 문자라면 반환
            if resolvedLabel != "?" && !resolvedLabel.isEmpty {
                // Shift가 눌린 경우 대문자/특수문자 처리 (간단 변환)
                // Note: SingleShortcutMapper.getKeyLabel은 기본적으로 소문자/숫자 반환
                if meaningfulModifiers.contains(.maskShift) {
                    return resolvedLabel.uppercased()
                }
                return resolvedLabel
            }
        }

        // Found warning log...
        logW(
            "🎮 ⚠️ [TRIGGER_KEY] keyCode \(keyCode) + Modifiers '\(inputModifiersStr)' (Raw: \(modifiers.rawValue))에 해당하는 트리거키를 찾을 수 없음 - 기본값 반환"
        )

        let currentSettings = SettingsManager.shared.load()
        let realTimeDefaultSymbol = currentSettings.defaultSymbol

        if let realTimeTriggerKey = EnhancedTriggerKey.presets.first(where: {
            $0.displayCharacter == realTimeDefaultSymbol
        }) {
            return realTimeTriggerKey.displayCharacter
        }
        return "?"
    }

    /// CGEventFlags를 EnhancedTriggerKey 호환 문자열로 변환
    func convertModifiersToString(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        let raw = flags.rawValue

        // 마스크 상수 (Carbon/NX 레거시 값)
        // NX_DEVICELCMDKEYMASK = 0x00000008, NX_DEVICERCMDKEYMASK = 0x00000010
        // NX_DEVICELSHIFTKEYMASK = 0x00000002, NX_DEVICERSHIFTKEYMASK = 0x00000004
        // NX_DEVICELALTKEYMASK = 0x00000020, NX_DEVICERALTKEYMASK = 0x00000040
        // NX_DEVICELCTLKEYMASK = 0x00000001, NX_DEVICERCTLKEYMASK = 0x00002000

        if flags.contains(.maskCommand) {
            // 0x10 is Right Command
            parts.append((raw & 0x10) != 0 ? "right_command" : "left_command")
        }
        if flags.contains(.maskShift) {
            // 0x04 is Right Shift
            parts.append((raw & 0x04) != 0 ? "right_shift" : "left_shift")
        }
        if flags.contains(.maskAlternate) {
            // 0x40 is Right Option
            parts.append((raw & 0x40) != 0 ? "right_option" : "left_option")
        }
        if flags.contains(.maskControl) {
            // 0x2000 is Right Control
            parts.append((raw & 0x2000) != 0 ? "right_control" : "left_control")
        }

        return parts.isEmpty ? "" : "flags " + parts.joined(separator: " ")
    }

    // MARK: - Private Methods

    /// Check if the key event matches any registered shortcut
    /// 등록된 모든 단축키 중 일치하는 항목이 있는지 확인 (Issue 537)
    func isAnyShortcut(keyCode: UInt16, modifiers: CGEventFlags, character: String) -> ShortcutItem?
    {
        // 1. Name-based KeySpec (Primary) - e.g. "semicolon" -> "⌘semicolon"
        let nameKeySpec = generateKeySpec(
            keyCode: keyCode, modifiers: modifiers, character: character)

        var specsToCheck: [String] = [nameKeySpec]

        // 2. Symbol-based KeySpec (Fallback for Issue 537_1)
        // e.g. "semicolon" -> ";" -> "⌘;"
        let resolvedName = SingleShortcutMapper.shared.getKeyLabel(for: keyCode)
        if let symbol = SingleShortcutMapper.shared.getSymbol(for: resolvedName),
            symbol != resolvedName
        {
            // Replace the name suffix with symbol
            if nameKeySpec.hasSuffix(resolvedName) {
                let prefix = String(nameKeySpec.dropLast(resolvedName.count))
                let symbolKeySpec = prefix + symbol
                specsToCheck.append(symbolKeySpec)
            }
        }

        let shortcuts = shortcutCache.shortcuts

        for spec in specsToCheck {
            // A. Strict Match
            let candidates = shortcuts.filter { $0.keySpec == spec }
            if !candidates.isEmpty {
                return candidates.max(by: { $0.type.priority < $1.type.priority })
            }

            // B. Wrapped Match (Issue 513)
            let wrappedSpec = "{\(spec)}"
            let wrappedCandidates = shortcuts.filter { $0.keySpec == wrappedSpec }
            if !wrappedCandidates.isEmpty {
                return wrappedCandidates.max(by: { $0.type.priority < $1.type.priority })
            }
        }

        return nil
    }

    /// 레거시 호환성 유지 (앱 단축키만 여전히 필요한 곳을 위해)
    func isAppShortcut(keyCode: UInt16, modifiers: CGEventFlags, character: String) -> ShortcutItem?
    {
        return isAnyShortcut(keyCode: keyCode, modifiers: modifiers, character: character)?.type
            == .appShortcut
            ? isAnyShortcut(keyCode: keyCode, modifiers: modifiers, character: character) : nil
    }

    /// 원시 이벤트 데이터에서 KeySpec 생성 (KeyEventMonitor.normalizeKeySpec에서 포팅된 로직)
    private func generateKeySpec(keyCode: UInt16, modifiers: CGEventFlags, character: String?)
        -> String
    {
        // Issue 298: 오른쪽 수정자에 대한 상세 로직 (CGEventFlags 기반)
        let raw = modifiers.rawValue

        // Masks: RightCmd(0x10), RightShift(0x04), RightOpt(0x40), RightCtrl(0x2000)
        let hasRight =
            (raw & 0x10 != 0) || (raw & 0x04 != 0) || (raw & 0x40 != 0) || (raw & 0x2000 != 0)

        var spec = ""

        if hasRight {
            // 상세 구성: "right_command+left_shift+..."
            var parts: [String] = []

            // Command
            if modifiers.contains(.maskCommand) {
                parts.append((raw & 0x10) != 0 ? "right_command" : "left_command")
            }

            // Shift
            if modifiers.contains(.maskShift) {
                parts.append((raw & 0x04) != 0 ? "right_shift" : "left_shift")
            }

            // Option
            if modifiers.contains(.maskAlternate) {
                parts.append((raw & 0x40) != 0 ? "right_option" : "left_option")
            }

            // Control
            if modifiers.contains(.maskControl) {
                parts.append((raw & 0x2000) != 0 ? "right_control" : "left_control")
            }

            // Caps Lock
            if modifiers.contains(.maskAlphaShift) {
                parts.append("caps_lock")
            }

            spec = parts.joined(separator: "+")
            if !spec.isEmpty { spec += "+" }

        } else {
            // 표준 심볼 구성
            // 순서 설정: ^ ⌥ ⌘ ⇧
            if modifiers.contains(.maskControl) { spec += "^" }
            if modifiers.contains(.maskAlternate) { spec += "⌥" }
            if modifiers.contains(.maskCommand) { spec += "⌘" }
            if modifiers.contains(.maskShift) { spec += "⇧" }
            // CapsLock for standard symbol? usually ⇪
            if modifiers.contains(.maskAlphaShift) { spec += "⇪" }
        }

        // 2. Character Resolution
        // Issue 537 & 277: SSOT(SingleShortcutMapper)를 사용하여 통합된 키 레이블을 가져옴
        var resolvedChar: String = SingleShortcutMapper.shared.getKeyLabel(for: keyCode)

        // Issue 524: Option 키에 대한 특수 처리 (∆, ˚, ¬, ◊ 등)
        if modifiers.contains(.maskAlternate) {
            if let optionChar = SharedKeyMap.getOptionKeyCharacter(
                keyCode: keyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers.rawValue)))
            {
                resolvedChar = optionChar
            }
        }

        spec += resolvedChar

        // Issue 311: spec이 '+'로 끝나는 경우 문자가 추가되지 않았음을 의미함 (수정자 전용 키).
        // EnhancedTriggerKey 형식(예: "right_command")과 일치하도록 뒤에 붙은 '+'를 제거함.
        if spec.hasSuffix("+") {
            spec.removeLast()
        }

        return spec
    }

    // Legacy setupImprovedCGEventTap removed.

    /// 글로벌 모니터 설정 (팝업 네비게이션 키 제외)
    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] event in
            guard let self = self else { return }

            // fSnippet이 활성화된 상태에서는 Local Monitor에서 처리하므로 중복 방지
            if NSApplication.shared.isActive {
                logV("🎮 [Issue75] Global Monitor - fSnippet 활성 → 스킵")
                return
            }

            // 팝업 네비게이션 키는 CGEventTap에서 전담 처리하므로 제외
            let keyCode = event.keyCode
            if popupNavigationKeys.contains(keyCode) {
                // CGEventTap에서 전담 처리하므로 무시
                return
            }

            logV("🎮 [Issue75] Global Monitor - 키 \(keyCode) 처리")
            self.handleKeyEvent(event, isLocal: false)
        }
    }

    /// 로컬 모니터 설정 (팝업 네비게이션 키 제외)
    private func setupLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] event in
            guard let self = self else { return event }

            // Issue75: fSnippet이 비활성 상태에서는 Global Monitor에서 처리하므로 중복 방지
            if !NSApplication.shared.isActive {
                logV("🎮 [Issue75] Local Monitor - fSnippet 비활성 → 스킵")
                return event
            }

            // 팝업 네비게이션 키는 CGEventTap에서 전담 처리하므로 제외
            let keyCode = event.keyCode
            if popupNavigationKeys.contains(keyCode) {
                // CGEventTap에서 전담 처리하므로 일반 전달
                return event
            }

            logV("🎮 [Issue75] Local Monitor - 키 \(keyCode) 처리")
            self.handleKeyEvent(event, isLocal: true)
            return event
        }
    }

    /// 키 이벤트 처리 (팝업 네비게이션 키 제외)
    func handleKeyEvent(_ event: NSEvent, isLocal: Bool) {
        // ✅ Issue 518 & 518_1: Route Modifier Keys (flagsChanged) to didTypeKey for Standard Logging & Processing
        if event.type == .flagsChanged {
            let keyCode = event.keyCode

            // Check if it's a "Press" event (Flag is present)
            var isPressed = false

            // Map KeyCode to required flag
            switch keyCode {
            case 54, 55:  // Command
                isPressed = event.modifierFlags.contains(.command)
            case 56, 60:  // Shift
                isPressed = event.modifierFlags.contains(.shift)
            case 58, 61:  // Option
                isPressed = event.modifierFlags.contains(.option)
            case 59, 62:  // Control
                isPressed = event.modifierFlags.contains(.control)
            case 57:  // CapsLock
                isPressed = event.modifierFlags.contains(.capsLock)
            default:
                // Function Key modifier? (Fn) - 63
                if keyCode == 63 { isPressed = event.modifierFlags.contains(.function) }
            }

            // Only processing "Press" to avoid double logging (Press + Release)
            if isPressed {
                let keyName = SharedKeyMap.standardKeyNames[keyCode] ?? "Unknown(\(keyCode))"

                // ✅ Issue 519: 디버그 로그에서 특정 키 필터링 (Cmd:55, Shift:56, Ctrl:59, Opt:58, RShift:60, v:9)
                let ignoredLogKeys: Set<UInt16> = [55, 56, 59, 58, 60]
                if !ignoredLogKeys.contains(keyCode) {
                    // ✅ Issue 518_1: 버퍼 부작용을 피하기 위한 수동 로깅
                    // "🔹⌨️ [Typing] Key: SYMBOL (Code: CODE)" 형식 (따옴표 없음)
                    logD(
                        "🎮 🔹⌨️ [Typing] Key: \(keyName.replacingOccurrences(of: "\n", with: "\\n")) (Code: \(keyCode))"
                    )
                }

                // ✅ Issue 513_4: Modifier 키를 프리픽스/서픽스로 사용하기 위해 버퍼에 전달
                // Right Modifiers (54, 61, 62) 및 특정 키패드 특수 키 등을 버퍼로 보냄 (RShift 60 제거)
                let targetSpecialKeys: Set<UInt16> = [54, 61, 62, 71, 95]  // RCmd, ROpt, RCtrl, NumLock, KeypadComma
                if targetSpecialKeys.contains(keyCode) {
                    logV("🎮 [Issue513_4] Modifier/Special Key (Code: \(keyCode)) -> didTypeKey 호출")
                    delegate?.didTypeKey(
                        KeyEventInfo(
                            type: .special,
                            character: "",
                            keyCode: keyCode,
                            modifiers: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                        ))
                }
            }
            return
        }

        let keyCode = event.keyCode
        let settings = loadSettingsCached()  // Issue720_4: 캐시된 Settings 사용

        // ✅ 텍스트 대체 중이면 모든 키 이벤트 무시 (특수키 누수 방지)
        if contextManager.isReplacing {
            logD("🎮 [NSEvent] 텍스트 대체 중 - 키 이벤트 무시: \(keyCode)")
            return
        }

        // KeyEventInfo unified creation
        let keyInfo = KeyEventInfo(
            originalEvent: event.cgEvent,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            keyCode: keyCode,
            modifiers: event.modifierFlags,
            type: .regular
        )

        // ✅ CursorTracker 키 이벤트 무한 루프 방지
        if CursorTracker.shared.isMovingCursor {
            logV("🎮 [CURSOR_FILTER] CursorTracker 키 이동 중 - 키 이벤트 무시: \(keyCode)")
            return
        }

        // Legacy flagsChanged (Removed in Issue 518_1)

        // 키 입력 로깅은 processTypedKey에서 KeyLogger 동기화와 함께 처리

        // 팝업 키 단축키 검사 (최우선 처리)
        if isPopupKeyShortcut(keyInfo, settings: settings) {
            logV("🎮 팝업 키 단축키 감지: \(settings.popupKeyShortcut.displayString)")
            delegate?.didDetectPopupKey()
            return
        }

        // 수정자 키 조합 처리
        let hasModifiers = !event.modifierFlags.intersection([.command, .option, .control, .shift])
            .isEmpty
        if hasModifiers {
            // fSnippet 메뉴 단축키인지 확인하고 직접 처리
            if isFSnippetMenuShortcut(keyCode: keyCode, modifiers: event.modifierFlags) {
                logV("🎮 fSnippet 메뉴 단축키 감지 및 직접 처리: keyCode=\(keyCode)")
                handleFSnippetMenuShortcut(keyCode: keyCode)
                return
            }

            // ✅ Karabiner 매핑된 키는 수정자가 있어도 processTypedKey로 처리
            if RuleManager.shared.getKarabinerMapping(for: keyCode) != nil {
                logV(
                    "🎮 [KARABINER_BYPASS] keyCode \(keyCode)는 Karabiner 매핑 키 - 수정자 무시하고 processTypedKey 호출"
                )
                // processTypedKey로 넘어가도록 함
            } else {
                // ✅ Shift만 눌린 경우는 일반 대문자 입력이므로 processTypedKey로 처리
                let onlyShiftPressed =
                    event.modifierFlags.intersection([.command, .option, .control]) == []
                    && event.modifierFlags.contains(.shift)
                if onlyShiftPressed {
                    logV(
                        "🎮 [SHIFT_ONLY] Shift만 눌린 대문자 입력 - processTypedKey로 처리: keyCode=\(keyCode)")
                    // processTypedKey로 넘어가도록 함
                } else {
                    // ✅ Issue 282: ShortcutMgr를 통한 중앙 집중식 단축키 감지
                    // TriggerKeyManager 직접 확인 대신 ShortcutMgr에 등록된 모든 단축키(Trigger, AppShortcut 등) 확인

                    // Issue720_4: shortcutCache 활용 (ShortcutMgr.shared.registeredShortcuts 직접 순회 대신)
                    var matchedShortcut: ShortcutItem?
                    for item in shortcutCache.shortcuts {
                        if ShortcutMgr.shared.isHotkeyMatch(keyInfo, hotkeyString: item.keySpec) {
                            matchedShortcut = item
                            break
                        }
                    }

                    if let shortcut = matchedShortcut {
                        logV(
                            "🎮 [KeyEventProcessor] ShortcutMgr Match: \(shortcut.keySpec) (\(shortcut.type)) - Passing to processTypedKey"
                        )

                        // Issue278: 델리게이트에게 단축키 발생 알림
                        delegate?.didTriggerShortcut(shortcut)

                        processTypedKey(keyInfo)
                        return
                    }

                    // ✅ 실제 수정자 키 조합만 KeyLogger 동기화를 위해 로깅 처리
                    // 디버그: keyCode가 41(Semicolon) 또는 24(Equal)이고 control을 포함하는 경우 레지스트리 덤프
                    if (keyCode == 41 || keyCode == 24) && event.modifierFlags.contains(.control) {
                        logD("🎮 [KeyEventProcessor] ^; 또는 ^= 매칭 실패. 레지스트리 덤프:")
                        for item in ShortcutMgr.shared.registeredShortcuts {
                            logD("🎮     - \(item.keySpec) (\(item.type))")
                        }
                    }

                    // ✅ Issue 561_1: Option 키 입력 허용 (Pass-through from CGEventTap)
                    // CGEventTapManager에서 차단을 해제했으므로, 여기서 processTypedKey로 전달해야 버퍼에 기록됨.
                    // 단, 다른 수정자(Cmd, Ctrl)가 포함되지 않은 순수 Option(+Shift) 입력만 허용.
                    let isOption = event.modifierFlags.contains(.option)
                    let isCommand = event.modifierFlags.contains(.command)
                    let isControl = event.modifierFlags.contains(.control)

                    if isOption && !isCommand && !isControl {
                        // 문자가 있는지 확인
                        if let chars = event.characters, !chars.isEmpty {
                            logV(
                                "🎮 [Issue561_1] Option Key Input Allowed: '\(chars)' (Code: \(keyCode))"
                            )
                            processTypedKey(keyInfo)
                            return
                        }
                    }

                    // logModifierKeyEvent(event) // Removed unnecessary log
                    // 텍스트 버퍼 처리는 건너뛰기
                    return
                }
            }
        }

        // 키 타입별 처리
        processTypedKey(keyInfo)
    }

    /// 타이핑된 키 처리
    private func processTypedKey(_ keyInfo: KeyEventInfo) {
        let keyCode = keyInfo.keyCode

        // NSEvent modifierFlags needs to be reconstructed or passed if needed
        // Here we just use what we have in keyInfo

        // Backspace 처리
        if keyCode == 51 {
            delegate?.didTypeKey(
                KeyEventInfo(
                    originalEvent: nil,
                    characters: nil,
                    charactersIgnoringModifiers: nil,
                    keyCode: keyCode,
                    modifiers: keyInfo.modifiers,
                    type: .backspace
                ))
            return
        }

        // ✅ Issue39 수정: ◊ 키 처리 구분
        // keyCode 9 + Option+Shift 조합일 때도 이벤트를 그대로 통과시켜
        // 아래 Karabiner 매핑 또는 일반 문자 처리로 전달한다.
        // (이전에는 return하여 이벤트가 소실되어 '◊' 트리거가 동작하지 않는 문제가 있었음)

        // ✅ Karabiner 매핑 확인 (◊ 키 처리 후)
        if let karabinerChar = RuleManager.shared.getKarabinerMapping(for: keyCode) {
            logI("🎮 [KARABINER] keyCode \(keyCode) → '\(karabinerChar)' 매핑 적용")
            delegate?.didTypeKey(
                KeyEventInfo(
                    originalEvent: nil,
                    characters: karabinerChar,
                    charactersIgnoringModifiers: karabinerChar,
                    keyCode: keyCode,
                    modifiers: keyInfo.modifiers,
                    type: .regular
                ))
            return
        }

        // ✅ Suffix 문자 매핑 확인 (_rule.yml 기반 자동 처리)
        // Note: keyInfo.characters can be nil. If nil, empty string.
        let characters = keyInfo.characters ?? ""

        if characters.isEmpty,
            let suffixChar = RuleManager.shared.getSuffixCharacter(
                keyCode: keyCode, modifiers: keyInfo.modifiers)
        {
            logI(
                "🎮 [SUFFIX_MAPPING] keyCode \(keyCode) → '\(suffixChar)' 매핑 적용 (characters 비어있음 해결)"
            )
            delegate?.didTypeKey(
                KeyEventInfo(
                    originalEvent: nil,
                    characters: suffixChar,
                    charactersIgnoringModifiers: suffixChar,
                    keyCode: keyCode,
                    modifiers: keyInfo.modifiers,
                    type: .regular
                ))
            return
        }

        // 특수 키 처리 (팝업 네비게이션 키 제외)
        if let specialChar = specialKeyCodes[keyCode] {
            if !specialChar.isEmpty {
                delegate?.didTypeKey(
                    KeyEventInfo(
                        originalEvent: nil,
                        characters: specialChar,
                        charactersIgnoringModifiers: specialChar,
                        keyCode: keyCode,
                        modifiers: keyInfo.modifiers,
                        type: .special
                    ))
            }
            return
        }

        // 일반 문자 처리
        // ✅ Issue79 & Issue 561_1: Shift 또는 Option 키가 눌린 경우 원본 문자 사용
        // Shift: A, <, > 등 대문자/특수문자 보존
        // Option: ø, π, … 등 특수문자 보존
        let sourceChars: String?
        if keyInfo.modifiers.contains(.shift) || keyInfo.modifiers.contains(.option) {
            sourceChars = keyInfo.characters
        } else {
            sourceChars = keyInfo.charactersIgnoringModifiers  // 소문자 사용 (a, ,, ., 등)
        }

        if let characters = sourceChars {
            for char in characters {
                let finalChar = String(char)
                delegate?.didTypeKey(
                    KeyEventInfo(
                        originalEvent: nil,
                        characters: finalChar,
                        charactersIgnoringModifiers: finalChar,
                        keyCode: keyCode,
                        modifiers: keyInfo.modifiers,
                        type: .regular
                    ))
            }
        }
    }

    /// 팝업 키 단축키 확인
    private func isPopupKeyShortcut(_ keyInfo: KeyEventInfo, settings: SnippetSettings) -> Bool {
        let shortcut = settings.popupKeyShortcut
        let eventModifiers = keyInfo.modifiers.intersection([.command, .option, .control, .shift])
        let expectedModifiers = shortcut.nsModifierFlags.intersection([
            .command, .option, .control, .shift,
        ])

        // 팝업 키 매칭 상세 로깅
        let keyMatch = keyInfo.keyCode == shortcut.keyCode
        let modifierMatch = eventModifiers == expectedModifiers

        logV(
            "🎮 기본 스니펫 팝업키 체크 - 키코드: \(keyInfo.keyCode) vs \(shortcut.keyCode) (\(keyMatch ? "✅" : "❌")), 수식자: \(eventModifiers.rawValue) vs \(expectedModifiers.rawValue) (\(modifierMatch ? "✅" : "❌")), 결과: \((keyMatch && modifierMatch) ? "✅매칭" : "❌실패")"
        )

        return keyMatch && modifierMatch
    }

    /// fSnippet 메뉴 단축키 확인
    private func isFSnippetMenuShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let commandModifier =
            modifiers.intersection([.command, .option, .control, .shift]) == .command

        guard commandModifier else { return false }

        // 설정창이 열려있을 때는 설정창 탭 전환 키들을 통과시킴
        if SettingsWindowManager.shared.isSettingsVisible {
            switch keyCode {
            case 18, 19, 20:  // Cmd+1, Cmd+2, Cmd+3 (설정창 탭 전환)
                logV(
                    "🎮 설정창이 열려있음 - Cmd+\(keyCode == 18 ? "1" : keyCode == 19 ? "2" : "3") 키를 설정창으로 통과시킴"
                )
                return false  // false 반환으로 일반 앱으로 전달
            case 13:  // Cmd+W (설정창 닫기)
                logD("🎮 설정창이 열려있음 - Cmd+W 키를 설정창으로 통과시킴")
                return false
            default:
                break
            }
        }

        // ✅ Issue21: fSnippet 앱이 활성화되어 있을 때만 메뉴 단축키 처리
        let isFSnippetActive = NSApplication.shared.isActive

        switch keyCode {
        case 43:  // Cmd+, (설정)
            if isFSnippetActive {
                logV("🎮 Cmd+, 감지 - fSnippet 활성화 상태, 처리 진행")
                return true
            } else {
                logV("🎮 Cmd+, 감지 - fSnippet 비활성화 상태, 다른 앱으로 전달")
                return false
            }
        case 15:  // Cmd+R (스니펫 다시 로드)
            return isFSnippetActive
        case 34:  // Cmd+I (상태 정보)
            return isFSnippetActive
        case 12:  // Cmd+Q (종료)
            return isFSnippetActive
        default:
            return false
        }
    }

    /// fSnippet 메뉴 단축키 직접 처리
    private func handleFSnippetMenuShortcut(keyCode: UInt16) {
        switch keyCode {
        case 43:  // Cmd+, (설정)
            logV("🎮 Cmd+, 감지 - 설정창 열기")
            DispatchQueue.main.async {
                SettingsWindowManager.shared.showSettings()
            }
        case 15:  // Cmd+R (스니펫 다시 로드)
            logV("🎮 Cmd+R 감지 - 스니펫 다시 로드")
            DispatchQueue.main.async {
                let settings = SettingsManager.shared.load()
                SnippetFileManager.shared.updateRootFolder(settings.basePath)
                SnippetFileManager.shared.loadAllSnippets()
                SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)
                NotificationManager().showNotification(
                    title: "fSnippet", message: "Snippet이 다시 로드되었습니다.")
            }
        case 34:  // Cmd+I (상태 정보)
            logV("🎮 Cmd+I 감지 - 상태 정보 표시")
            DispatchQueue.main.async {
                let fileManager = SnippetFileManager.shared
                let indexManager = SnippetIndexManager.shared
                let stats = indexManager.getIndexStats()

                let message = """
                    📁 Snippet 폴더: \(fileManager.rootFolderURL.path)
                    📄 로드된 Snippet: \(fileManager.snippetMap.count)개
                    🗂 인덱스 통계:
                       - 총 항목: \(stats.total)개
                       - 활성 항목: \(stats.active)개
                       - 캐시: \(stats.cache.entries)/\(stats.cache.maxSize)
                    """

                NotificationManager().showAlert(title: "fSnippet 상태 정보", message: message)
            }
        case 12:  // Cmd+Q (종료)
            logV("🎮 Cmd+Q 감지 - 앱 종료")
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        default:
            break
        }
    }

    /// 접근성 권한 확인
    private func isAccessibilityPermissionGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 접근성 권한 요청 (팝업 없이 로그만)
    private func requestAccessibilityPermission() {
        // prompt: false — 빌드마다 서명 변경 시 매번 팝업 발생 방지
        logE("🎮 접근성 권한이 없습니다. 시스템 설정 > 개인정보 > 접근성에서 fSnippetCli를 추가해 주세요")
    }

    // logModifierKeyEvent removed

    /// 모디파이어 기반 suffix 정보를 저장하는 변수
    private var lastModifierBasedSuffix: String?
    /// 모디파이어 기반 suffix가 성공적으로 처리되었는지 여부
    private var modifierBasedSuffixProcessed: Bool = false

    /// CGEventTap에서 직접 문자 입력 처리 (suffix 매핑용)
    func handleDirectCharacterInput(_ character: String, keyCode: UInt16, modifiers: CGEventFlags) {
        logI("🎮 [DIRECT_INPUT] 직접 문자 입력: '\(character)' (keyCode: \(keyCode))")

        // ✅ 모디파이어 기반 suffix 감지 (Option+키 조합)
        let isModifierBased = modifiers.contains(.maskAlternate)
        if isModifierBased {
            lastModifierBasedSuffix = character
            logV("🎮 [MODIFIER_SUFFIX] 모디파이어 기반 suffix 감지: '\(character)'")
        } else {
            lastModifierBasedSuffix = nil
        }

        // KeyEventInfo 생성하여 델리게이트로 전달
        let keyEventInfo = KeyEventInfo(
            type: .regular,
            character: character,
            keyCode: keyCode,
            modifiers: modifiers
        )

        // 델리게이트에 키 이벤트 전달하여 스니펫 처리 시도
        delegate?.didTypeKey(keyEventInfo)

        // 스니펫 처리 후 짧은 지연 후 물리적 문자 출력 여부 결정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            // ✅ 모디파이어 기반 suffix가 성공적으로 처리된 경우 물리적 출력 차단
            if self.modifierBasedSuffixProcessed {
                logV("🎮 [DIRECT_INPUT] 모디파이어 기반 suffix 처리됨 - '\(character)' 물리적 출력 차단")
                self.modifierBasedSuffixProcessed = false  // 플래그 리셋
                return
            }

            // 텍스트 대체가 진행 중이 아니면 스니펫이 없었던 것으로 판단
            if !self.isCurrentlyReplacing() {
                logI("🎮 [DIRECT_INPUT] 스니펫 없음 - '\(character)' 물리적 출력 (keyCode: \(keyCode))")
                self.outputCharacterToActiveApplication(character, keyCode: keyCode)
            } else {
                logI("🎮 [DIRECT_INPUT] 스니펫 확장 중 - 물리적 출력 건너뜀")
            }
        }
    }

    /// 마지막 모디파이어 기반 suffix 반환 및 초기화
    func getAndClearLastModifierBasedSuffix() -> String? {
        let suffix = lastModifierBasedSuffix
        lastModifierBasedSuffix = nil
        return suffix
    }

    /// 모디파이어 기반 suffix가 성공적으로 처리되었음을 표시
    func markModifierBasedSuffixProcessed() {
        modifierBasedSuffixProcessed = true
        logV("🎮 [MODIFIER_SUFFIX] 모디파이어 기반 suffix 처리 완료 플래그 설정")
    }

    /// 활성 애플리케이션에 문자 직접 출력
    private func outputCharacterToActiveApplication(_ character: String, keyCode: UInt16) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        else {
            logE("🎮 [outputCharacterToActiveApplication] CGEvent 생성 실패")
            return
        }

        // 문자를 유니코드로 설정
        let unicodeString = character.utf16
        let unicodeLength = unicodeString.count

        event.keyboardSetUnicodeString(
            stringLength: unicodeLength, unicodeString: Array(unicodeString))

        // ✅ Issue 524: 루프 방지를 위한 fSnippet 전용 태그 설정
        event.setIntegerValueField(.eventSourceUserData, value: 54321)

        event.post(tap: .cghidEventTap)

        logV("🎮 [DIRECT_OUTPUT] 문자 출력 완료: '\(character)'")
    }

    deinit {
        cleanup()
    }
}
