import CoreGraphics
import Foundation

// Manages one-shot key-capture sessions initiated via REST API.
// paidApp (Sandboxed) cannot create CGEventTap directly,
// so it delegates single-key capture to cliApp via /api/v2/key-capture/*.
final class KeyCaptureManager {
    static let shared = KeyCaptureManager()
    private init() {}

    enum Status: String {
        case idle     = "idle"
        case pending  = "pending"
        case captured = "captured"
    }

    private var _status: Status = .idle
    private var _capturedKeyCode: UInt16?
    private var _capturedNSModifiers: UInt?   // NSEvent.ModifierFlags.rawValue (UInt)
    private var _capturedDisplayString: String?
    private var _captureStartTime: Date?
    private let lock = NSLock()
    private let timeout: TimeInterval = 30

    // Issue865-fix: lockless fast-path indicator for CGEventTap callback hot-path.
    // Set true only between startCapture() and the first capturing event (or stopCapture).
    // Reading from the callback thread is safe because Swift Bool is word-sized on
    // supported platforms; worst-case a stale read causes one extra lock + NSEvent build,
    // which is bounded and self-correcting.
    private var _isPendingFast: Bool = false

    // Issue863-fix: when false (default), flagsChanged events are NOT captured so that
    // modifier-key presses during a combo (e.g. Ctrl in Ctrl+Shift+D) don't prematurely
    // terminate the capture session. Set true only for trigger-key recording where a
    // bare modifier key (e.g. right_command) is the intended shortcut.
    private var _allowModifierless: Bool = false

    /// Lock-free probe used by CGEventTapManager hot-path to skip
    /// the expensive NSEvent(cgEvent:) construction while no capture session is active.
    var isPendingFast: Bool {
        return _isPendingFast
    }

    /// When false, CGEventTapManager ignores flagsChanged events during capture.
    var allowModifierless: Bool {
        return _allowModifierless
    }

    // MARK: - Session control (called by APIRouter)

    func startCapture(allowModifierless: Bool = false) {
        lock.lock()
        _status = .pending
        _capturedKeyCode = nil
        _capturedNSModifiers = nil
        _capturedDisplayString = nil
        _captureStartTime = Date()
        _allowModifierless = allowModifierless
        _isPendingFast = true   // Issue865-fix: enable hot-path
        lock.unlock()

        logI("🎯 [KeyCaptureManager] Capture session started (allowModifierless:\(allowModifierless))")
        // Issue912: Disable Keyboard Maestro Engine during capture to prevent it from
        // intercepting modifier-only keys (e.g. right_command keyCode 54).
        // KM intercepts the flagsChanged event and injects ⌃⇧⌘F11 instead, causing
        // the wrong keyCode to reach the capture session.
        setKeyboardMaestroEnabled(false)
    }

    func stopCapture() {
        lock.lock()
        _status = .idle
        _isPendingFast = false  // Issue865-fix: disable hot-path
        lock.unlock()

        setKeyboardMaestroEnabled(true)
        logI("🎯 [KeyCaptureManager] Capture session stopped")
    }

    // MARK: - Key intercept (called from CGEventTapManager)

    // Returns true when the event was consumed by the capture session.
    // Caller should suppress the event (return nil from the tap callback).
    // nsModifiers: NSEvent.ModifierFlags.rawValue forwarded from NSEvent(cgEvent:).
    @discardableResult
    func captureKeyIfActive(keyCode: UInt16, nsModifiers: UInt, displayString: String) -> Bool {
        lock.lock()

        guard _status == .pending else {
            lock.unlock()
            return false
        }

        if let start = _captureStartTime, Date().timeIntervalSince(start) > timeout {
            _status = .idle
            _isPendingFast = false  // Issue865-fix
            lock.unlock()
            setKeyboardMaestroEnabled(true)
            logW("🎯 [KeyCaptureManager] Capture session timed out")
            return false
        }

        _capturedKeyCode = keyCode
        _capturedNSModifiers = nsModifiers
        _capturedDisplayString = displayString
        _status = .captured
        _isPendingFast = false      // Issue865-fix: capture done, exit hot-path
        lock.unlock()

        setKeyboardMaestroEnabled(true)
        logI("🎯 [KeyCaptureManager] Key captured — code:\(keyCode) nsMods:\(nsModifiers) display:\(displayString)")
        return true
    }

    // MARK: - Result query (called by APIRouter)

    var result: [String: Any] {
        lock.lock()

        switch _status {
        case .idle:
            lock.unlock()
            return ["status": "idle"]
        case .pending:
            if let start = _captureStartTime, Date().timeIntervalSince(start) > timeout {
                _status = .idle
                _isPendingFast = false   // Issue865-fix
                lock.unlock()
                setKeyboardMaestroEnabled(true)
                return ["status": "idle"]
            }
            lock.unlock()
            return ["status": "pending"]
        case .captured:
            let result: [String: Any] = [
                "status": "captured",
                "keyCode": _capturedKeyCode.map { Int($0) } as Any,
                "modifiers": _capturedNSModifiers as Any,
                "displayString": _capturedDisplayString as Any
            ]
            lock.unlock()
            return result
        }
    }

    // MARK: - Emergency restore (called on app termination)

    /// Re-enables Keyboard Maestro Engine in case cliApp exits during an active capture session.
    func emergencyRestore() {
        setKeyboardMaestroEnabled(true)
    }

    // MARK: - Private: Third-party interference mitigation

    // Disable/enable Keyboard Maestro Engine during capture sessions.
    // Silently succeeds if KM is not running.
    private func setKeyboardMaestroEnabled(_ enabled: Bool) {
        let state = enabled ? "true" : "false"
        let script = "tell application \"Keyboard Maestro Engine\" to set enabled to \(state)"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                logD("🎯 [KeyCaptureManager] KM setenabled \(enabled)")
            } else {
                logD("🎯 [KeyCaptureManager] KM setenabled \(enabled) skipped (exit:\(task.terminationStatus))")
            }
        } catch {
            logD("🎯 [KeyCaptureManager] KM toggle skipped — \(error.localizedDescription)")
        }
    }
}
