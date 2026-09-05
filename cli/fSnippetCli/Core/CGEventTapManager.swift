import ApplicationServices
import Cocoa
import Foundation

// MARK: - Delegate Protocol

protocol CGEventTapManagerDelegate: AnyObject {
    // 앱 상태 (App State)
    func isAppActive() -> Bool
    func isCurrentlyReplacing() -> Bool
    // Issue881: Whether paidApp (fSnippet GUI) is the current foreground app.
    func isPaidAppForeground() -> Bool

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

    // Issue208: permission probe used to decide whether re-enabling the tap makes sense.
    private let accessibilityService: AccessibilityService = SystemAccessibilityService()

    // Issue211: the permission probes cannot be trusted, so the tap's *actual* state is
    // checked after every re-enable. See `handleTapDisabled()` for the full rationale.
    private var healthCheckWork: DispatchWorkItem?
    private var recoveryAttempt = 0

    // Issue212: the freeze is a CALLBACK STALL, not a permission problem. Measured
    // 2026-09-05 20:47~20:48 — every disable arrived as `timeout` (raw=0xFFFFFFFE) while
    // `tapIsEnabled` stayed true. While the callback is stuck, EVERY HID event (mouse
    // included) waits for it to return, which is exactly what "frozen" looks like.
    private var recentTimeouts: [Date] = []
    private var lastCallbackMark = "idle"

    // Issue213: 메인 스레드에 있는 방어는 메인 스레드가 멈추면 함께 멈춘다.
    //
    // 실측 2026-09-05 21:28 — re-enable 직후 콜백이 반환하지 않아 `defer` 의 SLOW 로그도,
    // 3초 뒤 health check 도, timeout 누적 탈출구도 전부 실행되지 못했다. 전부 메인 큐에
    // 얹혀 있었기 때문이다. 그래서 감시자는 **별도 큐**에 둔다. 콜백이 일정 시간 안에
    // 돌아오지 않으면 워치독이 tap 을 꺼서 입력을 되돌린다 — 메인 스레드가 죽어 있어도.
    private let watchdogQueue = DispatchQueue(label: "kr.finfra.fSnippetCli.tap-watchdog")
    private var watchdogTimer: DispatchSourceTimer?
    private let callbackStateLock = NSLock()
    private var callbackEnteredAt: CFAbsoluteTime = 0  // 0 = 콜백 바깥
    private var callbackMarkShared = "idle"
    private var tapDisabledByWatchdog = false
    private static let watchdogInterval: TimeInterval = 0.5
    private static let stallThreshold: CFAbsoluteTime = 1.5
    // 실측 간격은 21s·12s 였다. 창 60s·임계 2회면 두 번째 timeout 에서 빠져나온다.
    // 임계를 1 로 두지 않는 이유는 바쁜 프레임 한 번으로도 timeout 이 날 수 있어서다.
    private static let timeoutWindow: TimeInterval = 60.0
    private static let timeoutBurstThreshold = 2
    private static let slowCallbackThresholdMs: Double = 80.0
    private static let slowNSEventThresholdMs: Double = 20.0
    private static let healthCheckDelay: TimeInterval = 3.0
    private static let recoveryBaseInterval: TimeInterval = 5.0
    private static let recoveryMaxInterval: TimeInterval = 60.0

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
        stopWatchdog()  // Issue213
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
        // Issue208: the former `(1 << 0xFFFF_FFFE)` / `(1 << 0xFFFF_FFFF)` terms (Issue 385)
        // were dead code. Swift's smart shift yields 0 on overshift, so both always evaluated
        // to 0 and contributed nothing. Tap-disabled notifications reach the callback
        // regardless of the mask, so no dedicated bit is required.
        let eventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard
            let eventTap = CGEvent.tapCreate(
                // Issue216: `.cghidEventTap` 에서 세션 레벨로 낮춘다.
                //
                // HID 레벨 tap 은 **마우스를 포함한 모든 입력이 최선두에서 통과**한다. 콜백이
                // 이벤트를 그대로 흘려보내도(실측: `nearEnd.ghostCheck`, 0.1ms) tap 이 거기
                // 있다는 사실만으로 이벤트 경로가 바뀌고, 권한 상태가 흔들리면 시스템 입력
                // 전체가 이 tap 에 인질로 잡힌다. 2026-09-05 프리즈에서 앱을 죽이는 즉시
                // 입력이 돌아온 것이 그 증거다 — 프로세스가 사라지면 tap 도 스트림에서 빠진다.
                //
                // 세션 레벨은 로그인 세션 이벤트만 받으므로 HID 스트림을 막지 않는다.
                // ⚠️ 대신 다른 앱보다 늦게 받는다 — 단축키 가로채기·트리거 감지에 회귀가
                // 없는지 확인이 필요하다. `place` 는 세션 내 최선두를 유지한다.
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: cgEventTapCallback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        else {
            // Issue211: without arming recovery here, a failed creation leaves the app
            // permanently without a tap — silent and unrecoverable short of a restart.
            logE(
                "💉 ⚙️ ❌ [CGEventTapManager] Failed to create CGEventTap "
                    + "(likely missing accessibility permission) — arming recovery")
            startGrantWatchdog()
            return
        }

        self.cgEventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        startWatchdog()  // Issue213
        logV("💉 ⚙️ [CGEventTapManager] Event Tap Created and Enabled")
    }

    func handleTapDisabled() {
        // ✅ Issue208: never keep re-enabling a tap we no longer have permission for.
        //
        // The tap is `.cghidEventTap` + `.defaultTap` (active) + `.headInsertEventTap`, so
        // EVERY HID input — mouse included — flows through it at the very head of the stream.
        // Leaving an unusable tap in place and re-enabling it forever makes events be consumed
        // or delayed: the keyboard goes dead first, then the mouse locks up too. Observed on
        // 2026-09-05: the machine had to be rebooted to recover.
        //
        // So when the permission is gone we do NOT re-enable — we remove the tap from the
        // event stream entirely. Input returns to normal the moment the tap is gone. Recovery
        // is delegated to the Issue207 grant watcher.
        // ⚠️ Issue211: the permission probes LIE. Measured 2026-09-05 20:29 — accessibility
        // was revoked in System Settings, yet `AXIsProcessTrusted()` kept returning true, so
        // the Issue208 gate never fired and the machine froze anyway. `AXIsProcessTrusted()`
        // reflects the value cached at process start; revocation is not propagated.
        //
        // So the gate no longer relies on a single probe. Both probes are consulted, and —
        // more importantly — the tap's REAL state is verified after every re-enable
        // (`CGEvent.tapIsEnabled`). A dead tap left in the stream is what freezes input, and
        // that state is observable regardless of what the probes claim.
        let axTrusted = accessibilityService.isAccessibilityGranted()
        let listenAccess = CGPreflightListenEventAccess()
        guard axTrusted && listenAccess else {
            logE(
                "💉 ⚙️ 🚨 [CGEventTapManager] Accessibility permission lost "
                    + "(AXIsProcessTrusted=\(axTrusted), CGPreflightListenEventAccess=\(listenAccess)) "
                    + "— removing the tap from the event stream instead of re-enabling it "
                    + "(prevents input freeze). It will be recreated once permission returns."
            )
            removeTapForSafety()
            return
        }

        guard let eventTap = cgEventTap else {
            reinitialize()
            return
        }

        // ✅ Issue208: the retry counter is no longer reset by elapsed time.
        //
        // The previous logic reset it whenever `now - lastReenableTime > resetInterval` (5s).
        // Real disable intervals were 13s / 62s / 10min — all above 5s — so the counter was
        // pinned at 1, `maxRetries` was never reached and the cooldown branch was dead code,
        // leaving an unbounded re-enable loop. The counter is now cleared only by
        // `noteHealthyEvent()`, i.e. when an actual event has been received.
        if reenableRetryCount < maxRetries {
            reenableRetryCount += 1
            lastReenableTime = Date()

            // Exponential Backoff (Optional) or simply slight delay
            let delay = 0.1 * Double(reenableRetryCount)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                CGEvent.tapEnable(tap: eventTap, enable: true)

                // Issue211: `tapEnable` fails SILENTLY when the permission is gone. This is the
                // one signal that does not depend on a probe — if the tap did not come back up,
                // it must leave the event stream immediately or input freezes.
                guard CGEvent.tapIsEnabled(tap: eventTap) else {
                    logE(
                        "💉 ⚙️ 🚨 [CGEventTapManager] Re-enable did not take effect "
                            + "(tapIsEnabled=false) — the tap is dead. Removing it from the "
                            + "event stream to prevent an input freeze."
                    )
                    self.removeTapForSafety()
                    return
                }

                logI(
                    "💉 ⚙️ [CGEventTapManager] Tap re-enabled. Attempt: \(self.reenableRetryCount)/\(self.maxRetries)"
                )
                self.scheduleHealthCheck(eventTap)
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

    /// Issue208: records that a real event came through — the only place the retry counter
    /// is cleared. Time-based resets used to mask a permanently broken tap as healthy.
    private func noteHealthyEvent() {
        // Issue211: real traffic also clears the recovery backoff.
        recoveryAttempt = 0
        guard reenableRetryCount != 0 else { return }
        logD(
            "💉 ⚙️ [CGEventTapManager] Healthy event received — retry counter reset "
                + "(\(reenableRetryCount) -> 0)"
        )
        reenableRetryCount = 0
    }

    // MARK: - Issue213: off-main watchdog

    /// 콜백 진입을 워치독에 알린다.
    private func noteCallbackEnter(at time: CFAbsoluteTime) {
        callbackStateLock.lock()
        callbackEnteredAt = time
        callbackMarkShared = "enter"
        callbackStateLock.unlock()
    }

    /// 콜백 이탈을 워치독에 알린다.
    private func noteCallbackExit() {
        callbackStateLock.lock()
        callbackEnteredAt = 0
        callbackStateLock.unlock()
    }

    /// 콜백 안의 현재 위치를 기록한다 — 멈췄을 때 어디였는지가 유일한 단서다.
    private func setMark(_ mark: String) {
        lastCallbackMark = mark
        callbackStateLock.lock()
        callbackMarkShared = mark
        callbackStateLock.unlock()
    }

    /// Issue213: 별도 큐에서 콜백 지연을 감시하고, 멈췄으면 tap 을 꺼서 입력을 되살린다.
    ///
    /// 이것이 프리즈에 대한 유일하게 신뢰할 수 있는 방어다. 메인 스레드에 얹은 방어는
    /// 메인 스레드가 멈추는 순간 같이 멈추므로 정의상 이 상황을 처리할 수 없다.
    /// `CGEvent.tapEnable(false)` 는 tap 을 이벤트 스트림에서 떼어내므로, 호출되는 즉시
    /// 대기 중이던 HID 이벤트가 흐르기 시작한다.
    private func startWatchdog() {
        guard watchdogTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        timer.schedule(
            deadline: .now() + Self.watchdogInterval, repeating: Self.watchdogInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.callbackStateLock.lock()
            let enteredAt = self.callbackEnteredAt
            let mark = self.callbackMarkShared
            self.callbackStateLock.unlock()

            guard enteredAt > 0 else { return }  // 콜백 바깥 — 정상
            let elapsed = CFAbsoluteTimeGetCurrent() - enteredAt
            guard elapsed >= Self.stallThreshold else { return }

            guard let tap = self.cgEventTap, !self.tapDisabledByWatchdog else { return }
            self.tapDisabledByWatchdog = true
            logE(
                "💉 ⚙️ 🚨 [Watchdog] 콜백이 \(String(format: "%.1f", elapsed))초째 반환하지 않는다 "
                    + "(mark=\(mark)) — tap 을 꺼서 입력을 회복시킨다. "
                    + "메인 스레드가 멈춰 있으므로 이 조치는 워치독 큐에서 수행된다.")
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        timer.resume()
        watchdogTimer = timer
        logD("💉 ⚙️ [Watchdog] 시작 (\(Self.watchdogInterval)s 간격, stall 임계 \(Self.stallThreshold)s)")
    }

    /// 워치독 정지.
    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        tapDisabledByWatchdog = false
        noteCallbackExit()
    }

    /// Issue212: record a timeout and decide whether the tap must leave the stream.
    ///
    /// A single timeout is normal — a slow frame, a busy main thread. A burst is not: it means
    /// the callback is reliably too slow, and every re-enable buys another stall. Measured
    /// 20:47:54 / 20:48:15 / 20:48:27 — three inside two minutes, with the machine unusable
    /// throughout. Removing the tap is the only action that returns input to the user.
    private func noteTimeoutAndShouldBail() -> Bool {
        let now = Date()
        recentTimeouts.append(now)
        recentTimeouts.removeAll { now.timeIntervalSince($0) > Self.timeoutWindow }
        guard recentTimeouts.count >= Self.timeoutBurstThreshold else { return false }

        logE(
            "💉 ⚙️ 🚨 [CGEventTapManager] \(recentTimeouts.count) timeouts within "
                + "\(Int(Self.timeoutWindow))s — the callback is stalling, not the permission. "
                + "Removing the tap from the event stream so input recovers. "
                + "Last checkpoint before the stall: \(lastCallbackMark)")
        recentTimeouts.removeAll()
        removeTapForSafety()
        return true
    }

    /// Issue212: `charactersIgnoringModifiers` without building an `NSEvent`.
    ///
    /// This is the Issue912 remedy applied to the last remaining offender. That fix established
    /// the rule — *do not construct `NSEvent` inside the tap callback* — because
    /// `NSEvent(cgEvent:)` blocks on events injected by Karabiner VirtualHIDKeyboard, which
    /// pushes the callback past macOS's tap timeout and gets the tap disabled. Issue912 applied
    /// it only to the key-capture path (and the neighbouring "Issue865-fix" comment covers the
    /// same path); the Issue537 shortcut path kept building one for EVERY keyDown, which is the
    /// stall observed on 2026-09-05.
    ///
    /// `keyboardGetUnicodeString` reads the same character straight from the event. Modifiers
    /// are cleared on a copy first, which is what makes the result "ignoring modifiers" — the
    /// original event is never mutated.
    private func charactersIgnoringModifiers(from event: CGEvent) -> String {
        guard let bare = event.copy() else { return "" }
        bare.flags = []
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        bare.keyboardGetUnicodeString(
            maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: min(length, buffer.count))
    }

    /// Issue212: time `NSEvent(cgEvent:)`, the known stall suspect.
    ///
    /// It has already dragged this callback past the tap timeout twice — Issue865 (built
    /// unconditionally on every keystroke) and Issue912 (blocks on Karabiner-injected
    /// flagsChanged). Both were fixed only on the key-capture path; the Issue537 shortcut path
    /// still builds one for every keyDown. Measuring it settles the question.
    private func timedNSEvent(_ event: CGEvent, mark: String) -> NSEvent? {
        setMark(mark)
        let t0 = CFAbsoluteTimeGetCurrent()
        let ns = NSEvent(cgEvent: event)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000.0
        if ms > Self.slowNSEventThresholdMs {
            logW(
                "💉 ⚙️ ⏱️ [CGEventTapManager] NSEvent(cgEvent:) took "
                    + "\(String(format: "%.0f", ms))ms at \(mark)")
        }
        setMark(mark + ".done")
        return ns
    }

    /// Issue211: take the tap out of the event stream and arm a recovery path.
    ///
    /// This is the single exit used by every "the tap is unusable" branch. Removing the tap is
    /// what actually unfreezes input — a dead tap sitting at the head of `.cghidEventTap`
    /// swallows every HID event, mouse included.
    private func removeTapForSafety() {
        healthCheckWork?.cancel()
        healthCheckWork = nil
        stop()
        reenableRetryCount = 0
        startGrantWatchdog()
    }

    /// Issue211: a re-enable can report success and still be dead.
    ///
    /// `tapEnable` + an immediate `tapIsEnabled` check catches the common case, but the state
    /// can also flip shortly after. This delayed check is the second net; it costs one timer
    /// and never produces a false positive, because it inspects the tap's own state rather
    /// than guessing from event traffic (the user may simply not be typing).
    private func scheduleHealthCheck(_ eventTap: CFMachPort) {
        healthCheckWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.cgEventTap != nil else { return }
            guard CGEvent.tapIsEnabled(tap: eventTap) else {
                logE(
                    "💉 ⚙️ 🚨 [CGEventTapManager] Health check failed "
                        + "(\(Int(Self.healthCheckDelay))s after re-enable, tapIsEnabled=false) "
                        + "— removing the tap from the event stream."
                )
                self.removeTapForSafety()
                return
            }
            logD("💉 ⚙️ [CGEventTapManager] Health check passed — tap alive")
        }
        healthCheckWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.healthCheckDelay, execute: work)
    }

    /// Issue208/211: bring the tap back once the system lets us.
    ///
    /// Two paths, because the probes are unreliable:
    /// * probe says *not granted* → the Issue207 watcher polls until the user flips the toggle
    /// * probe says *granted* but the tap died anyway → retry on our own with a backoff, since
    ///   the watcher refuses to start while it believes permission is present
    private func startGrantWatchdog() {
        guard !accessibilityService.isAccessibilityGranted() else {
            let interval = min(
                Self.recoveryBaseInterval * pow(2.0, Double(recoveryAttempt)),
                Self.recoveryMaxInterval
            )
            recoveryAttempt += 1
            logW(
                "💉 ⚙️ [CGEventTapManager] Probe still reports granted but the tap is dead — "
                    + "retrying tap creation in \(Int(interval))s (attempt \(recoveryAttempt))"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                guard let self = self, self.cgEventTap == nil else { return }
                self.start()
            }
            return
        }

        AccessibilityGrantWatcher.shared.startIfNeeded(service: accessibilityService) {
            [weak self] in
            guard let self = self else { return }
            logI("💉 ⚙️ [CGEventTapManager] Accessibility re-granted — recreating Event Tap")
            self.recoveryAttempt = 0
            self.start()
        }
    }

    // MARK: - Logic Methods (Called from Callback)

    fileprivate func handleCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>?
    {
        // Issue212: measure the whole callback. macOS disables the tap when this runs long,
        // and until it returns the entire HID stream is stalled. `lastCallbackMark` records
        // the last checkpoint entered, so a slow log names the culprit instead of guessing.
        let cbStart = CFAbsoluteTimeGetCurrent()
        var cbKeyCode: UInt16 = 9999  // Issue214: defer 로그용 (아직 미파싱이면 9999)
        lastCallbackMark = "enter"
        noteCallbackEnter(at: cbStart)  // Issue213: 워치독이 읽는 상태
        defer {
            noteCallbackExit()
            let ms = (CFAbsoluteTimeGetCurrent() - cbStart) * 1000.0
            // Issue214 진단: 콜백이 "어디로" 빠져나가는지가 유일하게 남은 미지수다.
            // stall 도 아니고 메인 정지도 아닌데 [Typing] 이 안 찍히므로, 종료 지점을
            // 무조건 남긴다. 키 입력당 1줄이라 재현 구간에서만 부담이 있다.
            logD("💉 ⚙️ [cb] exit mark=\(lastCallbackMark) kc=\(cbKeyCode) type=\(type.rawValue) \(String(format: "%.1f", ms))ms")
            if ms > Self.slowCallbackThresholdMs {
                logW(
                    "💉 ⚙️ ⏱️ [CGEventTapManager] SLOW callback "
                        + "\(String(format: "%.0f", ms))ms (type=\(type.rawValue), "
                        + "lastMark=\(lastCallbackMark)) — this is what stalls all input")
            }
        }

        guard let delegate = delegate else { return Unmanaged.passUnretained(event) }

        // 타임아웃/비활성화 처리 (Timeout/Disabled Handling)
        if type == .tapDisabledByTimeout || type.rawValue == 0xFFFF_FFFF {
            // Issue211: log WHICH disable this is. `timeout` means our callback was too slow;
            // `userInput` is what macOS sends on permission changes. Without this the two are
            // indistinguishable in the log, which cost a full diagnosis round.
            let isTimeout = (type == .tapDisabledByTimeout)
            let reason = isTimeout ? "timeout" : "userInput/permission"
            logW(
                "💉 ⚙️ 🚨 [CGEventTapManager] Event Tap Disabled "
                    + "(\(reason), raw=\(type.rawValue))! Auto-reenabling...")

            // Issue212: repeated timeouts mean the callback is the problem, and re-enabling
            // just restarts the stall. Bail out and take the tap off the stream so the user
            // gets their keyboard and mouse back.
            if isTimeout, noteTimeoutAndShouldBail() {
                return nil
            }

            handleTapDisabled()
            return nil
        }

        guard type == .keyDown || type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        // Issue208: a real event proves the tap is functional again.
        noteHealthyEvent()

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        cbKeyCode = keyCode

        // ✅ Issue 524: fSnippet 자체에서 발생시킨 이벤트 필터링하여 무한 루프 방지
        // 1. UserData 태그 확인 (가장 확실함)
        if event.getIntegerValueField(.eventSourceUserData) == CGEventPool.selfInjectedTag {
            setMark("exit.selfTag")
            return Unmanaged.passUnretained(event)
        }

        // 2. PID 기반 필터링 (보조)
        let senderPID = event.getIntegerValueField(.eventSourceUnixProcessID)
        if senderPID == Int64(ProcessInfo.processInfo.processIdentifier) {
            setMark("exit.selfPID")
            return Unmanaged.passUnretained(event)
        }

        // 콤보 중단 (Combo Breaker) — 모든 단축키/bufferClear 조기 반환보다 먼저 실행되어야 함.
        // 모디파이어 트리거(예: 오른쪽 ⌘) pending 중 다른 키(Tab/Space/Enter 등 bufferClear 포함)가
        // 눌리면 콤보(예: ⌘+Tab 앱 전환)로 간주하여 pending 을 취소한다. 이를 누락하면 모디파이어
        // 릴리스 시 트리거가 오발동(spurious FIRE)하여 ⌘+Tab 같은 시스템 조합을 잡아먹는다.
        // (이전에는 line 306 위치라 bufferClear early-return 에 가려 도달하지 못했음.)
        if type == .keyDown && pendingModifierTriggerKeyCode != nil {
            cancelPendingModifierTrigger()
        }

        // Issue863: key-capture mode — consume the event for REST API session.
        // Issue865-fix: fast lockless check first to avoid the expensive NSEvent(cgEvent:)
        // construction on every keystroke when no capture session is pending. The previous
        // unconditional NSEvent build caused CGEventTap callback latency to exceed macOS's
        // tap timeout, triggering frequent .tapDisabledByTimeout events and intermittent
        // key processing.
        if KeyCaptureManager.shared.isPendingFast,
           type == .keyDown || (type == .flagsChanged && KeyCaptureManager.shared.allowModifierless)
        {
            // Issue912: For flagsChanged (modifier-only) events, skip NSEvent construction
            // entirely. NSEvent(cgEvent:) blocks on certain flagsChanged events injected by
            // Karabiner VirtualHIDKeyboard (e.g. right_command keyCode 54), causing the
            // CGEventTap callback to exceed macOS's timeout threshold, which disables the
            // tap before captureKeyIfActive() is ever reached.
            // For keyDown, NSEvent is still needed for charactersIgnoringModifiers.
            // Issue165/fix: Apply keyCode-based .deviceRight* patch unconditionally so both
            // physical and remapped right-side modifiers are recognised correctly.
            let displayStr: String
            var rawMods: UInt
            if type == .flagsChanged {
                displayStr = ""
                rawMods = UInt(event.flags.rawValue)
            } else if let nsEv = timedNSEvent(event, mark: "keyCapture") {
                displayStr = nsEv.charactersIgnoringModifiers ?? ""
                rawMods = nsEv.modifierFlags.rawValue
            } else {
                displayStr = ""
                rawMods = UInt(event.flags.rawValue)
            }
            // Patch .deviceRight* flags based on keyCode regardless of NSEvent availability
            var patchedMods = NSEvent.ModifierFlags(rawValue: rawMods)
            switch keyCode {
            case 54: if patchedMods.contains(.command) { patchedMods.insert(.deviceRightCommand) }
            case 60: if patchedMods.contains(.shift) { patchedMods.insert(.deviceRightShift) }
            case 61: if patchedMods.contains(.option) { patchedMods.insert(.deviceRightOption) }
            case 62: if patchedMods.contains(.control) { patchedMods.insert(.deviceRightControl) }
            default: break
            }
            let nsMods = patchedMods.rawValue
            logD("🎯 [CGEventTapManager] KeyCapture attempt — keyCode:\(keyCode) type:\(type.rawValue) displayStr:\"\(displayStr)\" nsMods:\(nsMods) flags:\(event.flags.rawValue)")
            let captured = KeyCaptureManager.shared.captureKeyIfActive(
                keyCode: keyCode, nsModifiers: nsMods, displayString: displayStr)
            logD("🎯 [CGEventTapManager] captureKeyIfActive → \(captured)")
            if captured {
                return nil
            }
        }

        // Pass through 확인 (Passthrough Check)
        let appActive = delegate.isAppActive()
        setMark("isAppActive=\(appActive)")
        if appActive {
            if AboutWindowManager.shared.isAboutWindowVisible {
                NSLog("[CGEventTap] About 창 활성 중 - keyCode: \(keyCode), type: \(type.rawValue)")
            }
            if delegate.isCurrentlyReplacing() {
                setMark("exit.appActive.replacing.SWALLOW")
                logD("💉 ⚙️ [CGEventTapManager] Replacing (App Active) - Blocking Key: \(keyCode)")
                return nil
            }
            setMark("exit.appActive.pass")
            return Unmanaged.passUnretained(event)
        }

        // ✅ [Issue 537] 통합 단축키 체크 (App Hotkey, Trigger Key, Folder Prefix 등 모든 등록된 단축키)
        // 텍스트 대체 중이 아닐 때만 체크 (대체 중이면 위에서 이미 차단됨)
        if type == .keyDown {
            // Issue212: no `NSEvent` here. This ran on every single keyDown and is the
            // stall the 2026-09-05 freezes traced back to — same failure mode Issue912
            // documented, just on the path that fix did not cover.
            setMark("shortcut537")
            let character = charactersIgnoringModifiers(from: event)
            setMark("shortcut537.isAnyShortcut")
            if let shortcut = delegate.isAnyShortcut(
                keyCode: keyCode, modifiers: event.flags, character: character)
            {

                logD(
                    "💉 ⚙️ [CGEventTapManager] Registered Shortcut Detected (Blocking): \(shortcut.keySpec) [\(shortcut.type)]"
                )

                // 1. 앱 단축키(.appShortcut)인 경우
                if shortcut.type == .appShortcut {
                    // Issue881: When paidApp is foreground and the settings shortcut fires,
                    // pass the event through so paidApp's own localHotkeyMonitor handles it.
                    // This lets paidApp activate with .regular policy (visible in Dock/app-switcher)
                    // instead of being opened headlessly via URL scheme without focus.
                    if shortcut.id == "settings.hotkey" && delegate.isPaidAppForeground() {
                        logD("💉 ⚙️ [CGEventTapManager] Settings shortcut: paidApp foreground, passing through for direct handling")
                        return Unmanaged.passUnretained(event)
                    }
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

        // 콤보 중단 (Combo Breaker) — 위쪽(PID 필터 직후)으로 이동됨.
        // bufferClear/단축키 early-return 보다 먼저 실행되어야 ⌘+Tab 등 조합에서
        // 모디파이어 트리거 오발동을 막을 수 있어 위치를 옮겼다.

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
                logD(
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
                    logD(
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
        setMark("nearEnd.ghostCheck")
        if ghostKeys.contains(keyCode) {
            if let nsEvent = timedNSEvent(event, mark: "ghostKey") {
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
