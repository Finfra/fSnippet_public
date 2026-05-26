import Foundation
import AppKit

// MARK: - Protocol

/// Issue150: pairApp(fWarrangeCli) pattern — protocol facade for accessibility checks.
/// Decouples permission probing from UI presentation so tests can stub the system call.
protocol AccessibilityService {
    func isAccessibilityGranted() -> Bool
    func openAccessibilitySettings()
}

// MARK: - Default implementation

final class SystemAccessibilityService: AccessibilityService {

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
