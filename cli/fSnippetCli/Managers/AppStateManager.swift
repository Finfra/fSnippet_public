import Cocoa

// MARK: - PaidAppStatus

/// paidApp 3-state status enum (paid_cli_protocol.md §3.5)
///
/// cliApp menu bar icon and paid-feature routing are driven by this status.
enum PaidAppStatus {
    case notInstall  // paidApp not installed
    case stopped     // paidApp installed, not running
    case started     // paidApp running (REST registered or NSWorkspace detected)
}

// MARK: - AppStateManager

/// Centralises paidApp runtime state and publishes changes for SwiftUI consumers.
/// Replaces the binary isPaidAppRunning flag with a 3-state PaidAppStatus.
final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published private(set) var paidAppStatus: PaidAppStatus

    private init() {
        paidAppStatus = Self.computeStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPaidAppStateChanged(_:)),
            name: .paidAppStateChanged,
            object: nil
        )
    }

    @objc private func onPaidAppStateChanged(_ notification: Notification) {
        let isRunning = notification.userInfo?["isRunning"] as? Bool ?? false
        DispatchQueue.main.async { [weak self] in
            // When paidApp starts, mark started immediately.
            // When it stops, re-evaluate isInstalled to distinguish stopped vs notInstall.
            self?.paidAppStatus = isRunning ? .started : Self.computeStatus()
        }
    }

    private static func computeStatus() -> PaidAppStatus {
        guard PaidAppManager.shared.isInstalled() else { return .notInstall }
        return PaidAppManager.shared.isRunning() ? .started : .stopped
    }
}
