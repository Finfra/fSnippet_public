import ApplicationServices
import Cocoa
import Foundation

// MARK: - Delegate Protocol

protocol CGEventTapManagerDelegate: AnyObject {
    // 앱 상태 (App State)
    func isAppActive() -> Bool
    func isCurrentlyReplacing() -> Bool

    // 로직 위임 (Logic Delegation)
    func isTriggerKey(_ keyCode: UInt16, modifiers: CGEventFlags) -> Bool
    func getTriggerCharacter(_ keyCode: UInt16, modifiers: CGEventFlags) -> String

    // 액션 위임 (Action Delegation)
    func handleTriggerKeySync(keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String) -> Bool
    func handleTriggerKeyAsync(keyCode: UInt16, modifiers: CGEventFlags, triggerChar: String)
    func handleDirectCharacterInput(_ char: String, keyCode: UInt16, modifiers: CGEventFlags)

    // 앱 단축키 및 통합 단축키 (Shortcut Handling)
    func isAnyShortcut(keyCode: UInt16, modifiers: CGEventFlags, character: String) -> ShortcutItem?  // Issue 537
    func isAppShortcut(keyCode: UInt16, modifiers: CGEventFlags, character: String) -> ShortcutItem?
    func handleAppShortcutSync(_ shortcut: ShortcutItem)

    // 특수 키 (Special Keys)
    func shouldInterceptArrowKey(_ keyCode: UInt16) -> Bool
    func handleInterceptedSpecialKey(_ keyCode: UInt16)
    func handleNonInterceptedPopupNavigationKey(_ keyCode: UInt16, modifiers: CGEventFlags)
    func handleGhostKey(_ nsEvent: NSEvent)

    // 유틸리티 (Utils)
    func convertModifiersToString(_ flags: CGEventFlags) -> String

    // 상태 추적 (State Tracking)
    var lastFlags: CGEventFlags { get set }
}

// MARK: - CGEventTapManager

class CGEventTapManager {

    // MARK: - Properties
    private var cgEventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    weak var delegate: CGEventTapManagerDelegate?

    // 로직 상태 (Logic State)
    private var pendingModifierTriggerKeyCode: UInt16? = nil
    private var pendingModifierFlags: CGEventFlags? = nil

    // 중복 방지를 위한 Static 변수 (Static for duplicate prevention)
    private static var lastKeyEventTime: CFTimeInterval = 0
    private static var lastKeyCode: UInt16 = 0

    // ✅ Issue 583_2: Backoff Strategy for Event Tap Re-enabling
    private var reenableRetryCount: Int = 0
    private var lastReenableTime: Date = Date.distantPast
    private let maxRetries = 5
    private let resetInterval: TimeInterval = 5.0
    private let cooldownInterval: TimeInterval = 3.0

    // MARK: - Public Methods

    func start() {
        guard cgEventTap == nil else {
            logW("💉 ⚙️ [CGEventTapManager] Event Tap already running.")
            return
        }
        setupEventTap()
    }

    func stop() {
        if let eventTap = cgEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
            }
            cgEventTap = nil
        }
        logV("💉 ⚙️ [CGEventTapManager] Stopped.")
    }

    func reinitialize() {
        logV("💉 ⚙️ [CGEventTapManager] Reinitializing...")
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
            logV("💉 ⚙️ [CGEventTapManager] Reinitialized.")
        }
    }

    func cancelPendingModifierTrigger() {
        pendingModifierTriggerKeyCode = nil
        pendingModifierFlags = nil
    }

    // MARK: - Internal Setup

    private func setupEventTap() {
        let eventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            // Issue 385: Resilience
            | (1 << 0xFFFF_FFFE)  // kCGEventTapDisabledByTimeout
            | (1 << 0xFFFF_FFFF)  // kCGEventTapDisabledByUser

        guard
            let eventTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: cgEventTapCallback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        else {
            logE("💉 ⚙️ ❌ [CGEventTapManager] Failed to create CGEventTap")
            return
        }

        self.cgEventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logV("💉 ⚙️ [CGEventTapManager] Event Tap Created and Enabled")
    }

    func handleTapDisabled() {
        guard let eventTap = cgEventTap else {
            reinitialize()
            return
        }

        // ✅ Issue 583_2: Backoff Logic
        let now = Date()
        if now.timeIntervalSince(lastReenableTime) > resetInterval {
            reenableRetryCount = 0
        }

        if reenableRetryCount < maxRetries {
            reenableRetryCount += 1
            lastReenableTime = now

            // Exponential Backoff (Optional) or simply slight delay
            let delay = 0.1 * Double(reenableRetryCount)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                logI(
                    "💉 ⚙️ [CGEventTapManager] Tap re-enabled. Attempt: \(self.reenableRetryCount)/\(self.maxRetries)"
                )
            }
        } else {
            logE(
                "💉 ⚙️ 🚨 [CGEventTapManager] Event Tap disabled repeatedly! Cooldown for \(cooldownInterval)s..."
            )

            // Cooldown 후 리셋 및 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + cooldownInterval) { [weak self] in
                guard let self = self else { return }
                self.reenableRetryCount = 0
                self.handleTapDisabled()  // 재귀 호출로 재시도
            }
        }
    }

    // MARK: - Logic Methods (Called from Callback)

    fileprivate func handleCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>?
    {
        guard let delegate = delegate else { return Unmanaged.passUnretained(event) }

        // 타임아웃/비활성화 처리 (Timeout/Disabled Handling)
        if type == .tapDisabledByTimeout || type.rawValue == 0xFFFF_FFFF {
            logW("💉 ⚙️ 🚨 [CGEventTapManager] Event Tap Disabled! Auto-reenabling...")
            handleTapDisabled()
            return nil
        }

        guard type == .keyDown || type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // ✅ Issue 524: fSnippet 자체에서 발생시킨 이벤트 필터링하여 무한 루프 방지
        // 1. UserData 태그 확인 (가장 확실함)
        if event.getIntegerValueField(.eventSourceUserData) == 54321 {
            return Unmanaged.passUnretained(event)
        }

        // 2. PID 기반 필터링 (보조)
        let senderPID = event.getIntegerValueField(.eventSourceUnixProcessID)
        if senderPID == Int64(ProcessInfo.processInfo.processIdentifier) {
            return Unmanaged.passUnretained(event)
        }

        // Pass through 확인 (Passthrough Check)
        if delegate.isAppActive() {
            if AboutWindowManager.shared.isAboutWindowVisible {
                NSLog("[CGEventTap] About 창 활성 중 - keyCode: \(keyCode), type: \(type.rawValue)")
            }
            if delegate.isCurrentlyReplacing() {
                logD("💉 ⚙️ [CGEventTapManager] Replacing (App Active) - Blocking Key: \(keyCode)")
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // ✅ [Issue 537] 통합 단축키 체크 (App Hotkey, Trigger Key, Folder Prefix 등 모든 등록된 단축키)
        // 텍스트 대체 중이 아닐 때만 체크 (대체 중이면 위에서 이미 차단됨)
        if type == .keyDown {
            if let nsEvent = NSEvent(cgEvent: event),
                let shortcut = delegate.isAnyShortcut(
                    keyCode: keyCode, modifiers: event.flags,
                    character: nsEvent.charactersIgnoringModifiers ?? "")
            {

                logV(
                    "💉 ⚙️ [CGEventTapManager] Registered Shortcut Detected (Blocking): \(shortcut.keySpec) [\(shortcut.type)]"
                )

                // 1. 앱 단축키(.appShortcut)인 경우
                if shortcut.type == .appShortcut {
                    DispatchQueue.main.async { delegate.handleAppShortcutSync(shortcut) }
                    return nil  // Strong Block
                }

                // 2. 트리거 키 또는 폴더 접두사 등 스니펫 관련 단축키인 경우
                if shortcut.type == .triggerKey || shortcut.type == .folderPrefix
                    || shortcut.type == .folderSuffix
                {
                    let triggerChar: String
                    if let key = shortcut.userInfo?["triggerKey"] as? EnhancedTriggerKey {
                        triggerChar = key.displayCharacter
                    } else {
                        triggerChar = delegate.getTriggerCharacter(keyCode, modifiers: event.flags)
                    }

                    // 메인 스레드 비동기 처리 기동 (이벤트가 OS 큐에 먼저 도달하도록)
                    DispatchQueue.main.async {
                        _ = delegate.handleTriggerKeySync(
                            keyCode: keyCode, modifiers: event.flags, triggerChar: triggerChar)
                    }
                    logD(
                        "💉 ⚙️ [CGEventTapManager] Passing through Registered Shortcut: \(triggerChar) (Code: \(keyCode))"
                    )
                    return Unmanaged.passUnretained(event)
                }

                // 3. 기타 등록된 단축키 (BufferClear 등)
                // BufferClear 유형(Space, Enter 등)은 시스템 및 다른 앱으로 전달되어야 하므로 차단하지 않음
                if shortcut.type == .bufferClear {
                    return Unmanaged.passUnretained(event)
                }

                // 그 외(appShortcut, trigger 등) fSnippet이 전담하는 키들은 차단
                return nil  // Strong Block
            }
        }

        if delegate.isCurrentlyReplacing() {
            logD("💉 ⚙️ [CGEventTapManager] Replacing - Blocking Key: \(keyCode)")
            return nil
        }

        // Issue40: j,k,l 안전장치 (Option 키 없음)
        if type == .keyDown && !event.flags.contains(.maskAlternate)
            && [37, 38, 40].contains(keyCode)
        {
            return Unmanaged.passUnretained(event)
        }

        // 콤보 중단 (Combo Breaker)
        if type == .keyDown && pendingModifierTriggerKeyCode != nil {
            cancelPendingModifierTrigger()
        }

        // 플래그 변경 (Modifier 트리거)
        if type == .flagsChanged {
            delegate.lastFlags = event.flags  // 델리게이트 상태 업데이트

            // ... (Right modifier logging omitted for brevity, can re-add if needed or delegate) ...

            if delegate.isTriggerKey(keyCode, modifiers: event.flags) {
                pendingModifierTriggerKeyCode = keyCode
                pendingModifierFlags = event.flags
                logI("💉 ⚙️ [CGEventTapManager] Pending Modifier Trigger Set: \(keyCode)")
                return Unmanaged.passUnretained(event)
            }

            if let pending = pendingModifierTriggerKeyCode, pending == keyCode {
                let replayFlags = pendingModifierFlags ?? []
                cancelPendingModifierTrigger()
                logI("💉 ⚙️ [CGEventTapManager] FIRE Pending Modifier: \(keyCode)")

                let char = delegate.getTriggerCharacter(keyCode, modifiers: replayFlags)
                RunLoop.main.perform {
                    _ = delegate.handleTriggerKeySync(
                        keyCode: keyCode, modifiers: replayFlags, triggerChar: char)
                }
                return Unmanaged.passUnretained(event)
            }

            return Unmanaged.passUnretained(event)
        }

        // ⚠️ [Issue 537] 레거시 트리거 체크 (위의 통합 체크에서 대부분 처리됨)
        // 하지만 캐시에 없는 동적 트리거가 있을 수 있으므로 폴백으로 유지하되,
        // 이미 위에서 차단되지 않은 경우에만 도달함.
        if type == .keyDown {
            if delegate.isTriggerKey(keyCode, modifiers: event.flags) {
                let char = delegate.getTriggerCharacter(keyCode, modifiers: event.flags)
                DispatchQueue.main.async {
                    delegate.handleTriggerKeyAsync(
                        keyCode: keyCode, modifiers: event.flags, triggerChar: char)
                }
                logV(
                    "💉 ⚙️ [CGEventTapManager] Passing through Fallback Trigger: \(char) (Code: \(keyCode))"
                )
                return Unmanaged.passUnretained(event)
            }
        }

        // 접미사 매핑 (Suffix Mapping) (Option+J/K/L, π 등)
        let flags = event.flags
        if type == .keyDown && flags.contains(.maskAlternate) {
            let isStrict =
                !flags.contains(.maskControl) && !flags.contains(.maskCommand)
                && !flags.contains(.maskShift)
            if isStrict {
                // ✅ Issue 524: SharedKeyMap을 이용한 통합 옵션 키 매핑 적용 (˚, π 등 전체 지원)
                // Note: type == .keyDown 조건이 필수 (flagsChanged 시 keyCode 0으로 인한 å 오발착 방지)
                if let mappedChar = SharedKeyMap.getOptionKeyCharacter(
                    keyCode: keyCode,
                    modifiers: NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue)))
                {
                    logV(
                        "💉 ⚙️ [CGEventTapManager] Option Mapping (SSOT): \(mappedChar) (Pass-through allowed)"
                    )
                    // ✅ Issue 561_1 Fix: Do NOT intercept. Let it pass to OS.
                    // KeyEventProcessor's handleKeyEvent will catch it for buffering.
                    // RunLoop.main.perform { delegate.handleDirectCharacterInput(mappedChar, keyCode: keyCode, modifiers: flags) }
                    // return nil
                }
            }
        }

        // 특수 키 (Special Keys) (Arrow/Esc)
        if [125, 126, 53].contains(keyCode) {
            if delegate.shouldInterceptArrowKey(keyCode) {
                DispatchQueue.main.async { delegate.handleInterceptedSpecialKey(keyCode) }
                return nil
            } else {
                DispatchQueue.main.async {
                    delegate.handleNonInterceptedPopupNavigationKey(keyCode, modifiers: flags)
                }
            }
        }

        // 고스트 키 (Ghost Keys)
        // Added 95 (Keypad Comma) - Issue 507
        let ghostKeys: Set<UInt16> = [
            82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 65, 67, 69, 75, 78, 81, 95,
        ]
        if ghostKeys.contains(keyCode) {
            if let nsEvent = NSEvent(cgEvent: event) {
                DispatchQueue.main.async { delegate.handleGhostKey(nsEvent) }
            }
        }

        return Unmanaged.passUnretained(event)
    }
}

// Global Callback
func cgEventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<CGEventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleCallback(proxy: proxy, type: type, event: event)
}
