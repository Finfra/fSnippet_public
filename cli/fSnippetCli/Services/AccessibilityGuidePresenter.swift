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

    /// Issue221: 표시 중 여부. 이 창은 여러 경로에서 호출된다 — 부팅 시 미승인, 워치독의
    /// 권한 상실 감지 등. `runModal()` 은 블로킹이므로 가드가 없으면 호출이 큐에 쌓여
    /// 닫는 즉시 또 뜬다. 사용자가 창을 닫을 수 없게 되는 것과 같다.
    private static let presentLock = NSLock()
    private static var isPresenting = false
    /// Issue221: 현재 표시 중인 안내 창을 닫는다.
    ///
    /// 권한이 다시 승인되면 창을 남겨둘 이유가 없다. 더 중요한 이유가 있는데,
    /// `runModal()` 이 메인 스레드를 잡고 있으면 `AccessibilityGrantWatcher` 가 감지한
    /// 복구 콜백(메인 스레드에서 tap 을 재생성한다)이 실행되지 못한다. 즉 창을 닫아야
    /// 자동 복구가 완료된다.
    static func dismissIfPresenting() {
        DispatchQueue.main.async {
            presentLock.lock()
            let showing = isPresenting
            presentLock.unlock()
            guard showing else { return }
            logI("♿️ [GuidePresenter] 권한 복구 — 안내 창을 닫는다")
            NSApp.abortModal()
        }
    }

    static func show(service: AccessibilityService) {
        // Issue221: 이미 떠 있으면 새로 띄우지 않는다.
        presentLock.lock()
        if isPresenting {
            presentLock.unlock()
            logD("♿️ [GuidePresenter] 안내 창이 이미 표시 중 — 중복 표시 생략")
            return
        }
        isPresenting = true
        presentLock.unlock()

        DispatchQueue.main.async {
            defer {
                presentLock.lock()
                isPresenting = false
                presentLock.unlock()
            }
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
