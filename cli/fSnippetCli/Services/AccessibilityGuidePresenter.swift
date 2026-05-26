import Foundation
import AppKit

/// Issue150: pairApp(fWarrangeCli) pattern — alert presentation extracted from AppDelegate.
/// Single NSAlert on boot when accessibility is not granted; no polling, no revoke handler.
/// brew redeploy can break TCC csreq match — guide the user to toggle OFF → ON in System Settings.
enum AccessibilityGuidePresenter {
    static func show(service: AccessibilityService) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString(
                "Accessibility Permission Required",
                comment: "Alert title when accessibility permission is not granted"
            )
            alert.informativeText = NSLocalizedString(
                "fSnippetCli requires accessibility permission to monitor keyboard input.\n\n시스템 설정 > 개인정보 보호 및 보안 > 접근성에서 fSnippetCli 를 허용해주세요.\n\nbrew 재배포 직후 권한 매칭이 깨졌다면 토글을 OFF → ON 다시 누르세요.",
                comment: "Alert body explaining how to grant accessibility permission"
            )
            alert.addButton(withTitle: NSLocalizedString(
                "Open System Settings",
                comment: "Button to open System Settings"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "Later",
                comment: "Button to dismiss the alert"
            ))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                service.openAccessibilitySettings()
            }
        }
    }
}
