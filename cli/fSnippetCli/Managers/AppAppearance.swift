import Cocoa

class AppAppearance {
    static let shared = AppAppearance()

    enum Mode: String, CaseIterable {
        case system = "system"
        case light = "light"
        case dark = "dark"
    }

    func apply(_ modeString: String) {
        let mode = Mode(rawValue: modeString) ?? .system
        switch mode {
        case .system:
            NSApp.appearance = nil // 시스템 따름
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
