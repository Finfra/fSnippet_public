import Foundation
import AppKit

/// Issue150: pairApp(fWarrangeCli) pattern — alert presentation extracted from AppDelegate.
/// Single NSAlert on boot when accessibility is not granted; no polling, no revoke handler.
/// brew redeploy can break TCC csreq match — guide the user to toggle OFF → ON in System Settings.
///
/// Issue207: the previous copy ended at "enable it in System Settings", which left users stuck —
/// macOS evaluates accessibility at process start and never applies it retroactively, so the
/// running process stayed dead after they followed the instructions. The copy now says so and the
/// alert offers a restart. Automatic recovery is handled separately by `AccessibilityGrantWatcher`.
///
/// ⚠️ The `NSLocalizedString` keys here must match `Localizable.strings` **byte for byte**.
/// The earlier copy had drifted from the table (it embedded Korean directly in the key), so the
/// lookup missed and a mixed English/Korean literal was shown to every locale.
enum AccessibilityGuidePresenter {

    /// Key kept in sync with `ko.lproj/Localizable.strings`.
    ///
    /// Written as explicit `+` concatenation rather than a `"""` literal on purpose: the key must
    /// match the strings table byte for byte, and multiline literals hide exactly which whitespace
    /// and newlines end up in the string.
    private static let bodyKey =
        "fSnippetCli requires accessibility permission to monitor keyboard input.\n\n"
        + "Enable fSnippetCli in System Settings > Privacy & Security > Accessibility.\n\n"
        + "macOS evaluates this permission when the process starts, so turning it on does not revive the running app on its own. fSnippetCli watches for the change and recovers automatically; if it does not, restart the app.\n\n"
        + "If permission matching broke right after a brew redeploy, toggle it OFF then ON again."

    static func show(service: AccessibilityService) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString(
                "Accessibility Permission Required",
                comment: "Alert title when accessibility permission is not granted"
            )
            alert.informativeText = NSLocalizedString(
                bodyKey,
                comment: "Alert body explaining how to grant accessibility permission"
            )
            alert.addButton(withTitle: NSLocalizedString(
                "Open System Settings",
                comment: "Button to open System Settings"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "Restart Now",
                comment: "Button to restart the app so the permission takes effect"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "Later",
                comment: "Button to dismiss the alert"
            ))

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                service.openAccessibilitySettings()
            case .alertSecondButtonReturn:
                restartNow()
            default:
                break
            }
        }
    }

    /// Issue207: restart is delegated to launchd via `brew services restart` — the app never
    /// relaunches itself (that pattern was removed in Issue181). When brew is unavailable we say
    /// so instead of failing silently, because a silent failure here looks identical to success.
    private static func restartNow() {
        guard BrewServiceSync.restartViaBrewServices() else {
            let fallback = NSAlert()
            fallback.alertStyle = .informational
            fallback.messageText = NSLocalizedString(
                "Restart Required",
                comment: "Alert title when automatic restart is unavailable"
            )
            fallback.informativeText = NSLocalizedString(
                "Automatic restart is unavailable (Homebrew service not found). Quit fSnippetCli and start it again so the accessibility permission takes effect.",
                comment: "Alert body asking the user to restart manually"
            )
            fallback.addButton(withTitle: NSLocalizedString("OK", comment: "Dismiss button"))
            fallback.runModal()
            return
        }
        logI("♿️ 사용자 요청으로 brew services restart 실행 — 접근성 권한 반영 (Issue207)")
    }
}
