import Cocoa
import SwiftUI

/// 전역 알림(Toast)을 관리하는 매니저
class ToastManager {
    static let shared = ToastManager()
    private var currentWindow: NSWindow?
    
    /// 메시지와 아이콘을 화면 중앙에 1초간 표시 (선택적 위치 지정)
    func showToast(message: String, iconName: String, duration: TimeInterval = 1.0, relativeTo frame: NSRect? = nil, fontSize: CGFloat? = nil) {
        // 기존 알림이 있으면 즉시 제거
        hideToast()
        
        let toastView = OnScreenNotificationView(message: message, iconName: iconName, fontSize: fontSize)
        let hostingController = NSHostingController(rootView: toastView)
        
        // 윈도우 생성 (fontSize에 따라 크기 조정)
        let windowWidth: CGFloat = fontSize != nil ? max(250, fontSize! * 16) : 250
        let windowHeight: CGFloat = fontSize != nil ? max(150, fontSize! * 8) : 150
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating // .statusBar -> .floating (HistoryViewer 위에 뜨도록)
        window.contentViewController = hostingController
        window.ignoresMouseEvents = true // 클릭 방해 금지
        
        // 화면 중앙 배치 또는 지정된 프레임 중앙 배치
        if let targetFrame = frame {
            let xPos = targetFrame.origin.x + (targetFrame.width - window.frame.width) / 2
            let yPos = targetFrame.origin.y + (targetFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let xPos = screenFrame.origin.x + (screenFrame.width - window.frame.width) / 2
            let yPos = screenFrame.origin.y + (screenFrame.height - window.frame.height) / 2
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
        
        window.orderFront(nil) // ✅ CL045_10 수정: 포커스를 뺏지 않음
        window.alphaValue = 0
        self.currentWindow = window
        
        // 페이드 인 -> 대기 -> 페이드 아웃
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 1.0
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.hideToast()
            }
        })
    }
    
    private func hideToast() {
        guard let window = currentWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            if self.currentWindow === window {
                self.currentWindow = nil
            }
        })
    }
}
