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

    /// Lock-free probe used by CGEventTapManager hot-path to skip
    /// the expensive NSEvent(cgEvent:) construction while no capture session is active.
    var isPendingFast: Bool {
        return _isPendingFast
    }

    // MARK: - Session control (called by APIRouter)

    func startCapture() {
        lock.lock()
        defer { lock.unlock() }
        _status = .pending
        _capturedKeyCode = nil
        _capturedNSModifiers = nil
        _capturedDisplayString = nil
        _captureStartTime = Date()
        _isPendingFast = true   // Issue865-fix: enable hot-path
        logI("🎯 [KeyCaptureManager] Capture session started")
    }

    func stopCapture() {
        lock.lock()
        defer { lock.unlock() }
        _status = .idle
        _isPendingFast = false  // Issue865-fix: disable hot-path
        logI("🎯 [KeyCaptureManager] Capture session stopped")
    }

    // MARK: - Key intercept (called from CGEventTapManager)

    // Returns true when the event was consumed by the capture session.
    // Caller should suppress the event (return nil from the tap callback).
    // nsModifiers: NSEvent.ModifierFlags.rawValue forwarded from NSEvent(cgEvent:).
    @discardableResult
    func captureKeyIfActive(keyCode: UInt16, nsModifiers: UInt, displayString: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard _status == .pending else { return false }

        if let start = _captureStartTime, Date().timeIntervalSince(start) > timeout {
            _status = .idle
            _isPendingFast = false  // Issue865-fix
            logW("🎯 [KeyCaptureManager] Capture session timed out")
            return false
        }

        _capturedKeyCode = keyCode
        _capturedNSModifiers = nsModifiers
        _capturedDisplayString = displayString
        _status = .captured
        _isPendingFast = false      // Issue865-fix: capture done, exit hot-path
        logI("🎯 [KeyCaptureManager] Key captured — code:\(keyCode) nsMods:\(nsModifiers) display:\(displayString)")
        return true
    }

    // MARK: - Result query (called by APIRouter)

    var result: [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        switch _status {
        case .idle:
            return ["status": "idle"]
        case .pending:
            if let start = _captureStartTime, Date().timeIntervalSince(start) > timeout {
                _status = .idle
                _isPendingFast = false   // Issue865-fix
                return ["status": "idle"]
            }
            return ["status": "pending"]
        case .captured:
            return [
                "status": "captured",
                "keyCode": _capturedKeyCode.map { Int($0) } as Any,
                "modifiers": _capturedNSModifiers as Any,
                "displayString": _capturedDisplayString as Any
            ]
        }
    }
}
