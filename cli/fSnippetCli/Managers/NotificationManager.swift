import Cocoa
import UserNotifications
import SwiftUI


/// 알림 및 대화상자 관리 클래스
class NotificationManager {
    
    /// 시스템 알림 표시
    func showNotification(title: String, message: String) {
        // 알림 설정 확인
        guard SettingsObservableObject.shared.showNotifications else {
            logV("🔔 알림 표시 생략됨 (설정: 끔)")
            return
        }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, 
            content: content, 
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                logE("🔔 알림 표시 실패: \(error.localizedDescription)")
            } else {
                logV("🔔 알림 표시 성공: \(title)")
            }
        }
    }
    
    /// 모달 대화상자 표시
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }
    
    /// 확인/취소 대화상자 표시
    func showConfirmation(
        title: String, 
        message: String, 
        confirmButtonTitle: String = "확인",
        cancelButtonTitle: String = "취소",
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: confirmButtonTitle)
            alert.addButton(withTitle: cancelButtonTitle)
            
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }
    
    /// 에러 대화상자 표시
    func showError(title: String = "오류", message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
    }
    
    /// 성공 알림 표시 (간단한 배너)
    func showSuccess(message: String) {
        showNotification(title: "fSnippet", message: message)
    }
    
    /// 경고 알림 표시
    func showWarning(title: String = "경고", message: String) {
        showNotification(title: title, message: message)
    }
}


// MARK: - Issue 350 개선: 플로팅 경고 관리자
// (프로젝트 파일 수정 없이 컴파일되도록 여기에 병합됨)

class FloatingAlertManager: NSObject, NSWindowDelegate {
    static let shared = FloatingAlertManager()
    
    private var window: NSPanel?
    private var eventMonitor: Any? // [Issue350] ESC 키 수신용

    
    func show(title: String, message: String, timeout: TimeInterval? = nil) {
        // 메인 스레드에서 UI 업데이트 보장
        DispatchQueue.main.async {
            self.showInternal(title: title, message: message, timeout: timeout)
        }
    }
    
    // [Issue354] 타임아웃 지원 추가
    private var dismissWorkItem: DispatchWorkItem?

    private func showInternal(title: String, message: String, timeout: TimeInterval?) {
        // 이전 닫기 타이머 취소 (없는 경우)
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        // 1. 윈도우 생성 또는 재사용
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], // 테두리 없음과 유사하지만 내부 구조를 위해 타이틀 포함
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hidesOnDeactivate = false // Issue354: 앱이 백그라운드여도 유지
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 전역 가시성
            panel.delegate = self
            self.window = panel
        }
        
        guard let panel = window else { return }
        
        // 2. 내용 설정
        let hosting = NSHostingController(rootView: FloatingAlertView(title: title, message: message))
        panel.contentViewController = hosting
        
        // 내용에 따른 크기 조절 (대략적 또는 고정 너비, 동적 높이)
        let size = hosting.sizeThatFits(in: CGSize(width: 300, height: 500))
        panel.setContentSize(size)
        
        // 3. 위치 계산 (HistoryViewerManager 로직 재사용 또는 단순화된 버전)
        // 기본값: 커서 위치
        let targetPos = calculatePosition(width: size.width, height: size.height)
        panel.setFrameOrigin(targetPos)
        
        // 4. 앱 활성화 없이 표시 (대상 앱의 포커스 유지를 위해, 하지만 알림은 보여야 함)
        // 요구사항: "포커스 분실 시 자동 닫기".
        // 포커스 분실을 감지하려면 윈도우가 보통 키 윈도우여야 함.
        // 하지만 키 윈도우로 만들면 편집기에서 포커스를 뺏어가므로 타이핑 흐름이 끊길 수 있음 (오류 상태이므로 괜찮을 수도 있음).
        // 확장을 방지하는 오류 알림이므로, 주의를 끌기 위해 포커스를 뺏는 것은 허용됨.
        // However, making it key steals focus from the editor, which might interrupt typing flow (though this is an error state, so maybe okay).
        // Since it's an error alert preventing expansion, stealing focus is acceptable to draw attention.
        panel.makeKeyAndOrderFront(nil)
        // NSApp.activate(ignoringOtherApps: true) // Issue354: 붙여넣기 대상을 위해 포커스를 뺏지 않도록 앱 활성화 금지
        
        
        // [Issue350] ESC 키 로컬 모니터 추가
        // 참고: 윈도우로만 제한할 경우 로컬 모니터가 이벤트를 확실히 받으려면 윈도우가 키 상태여야 함.
        // 하지만 NSEvent.addLocalMonitorForEvents는 앱의 모든 이벤트를 받음.
        // makeKeyAndOrderFront를 하므로 괜찮을 것임.
        // Since we makeKeyAndOrderFront, we should be fine.
        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // ESC
                    self?.hide()
                    return nil // Consume event
                }
                return event
            }
        }

        logD("🔔 [FloatingAlertManager] Showing alert: \(title)")
        
        // [Issue354] 타임아웃 자동 닫기 처리
        if let timeout = timeout {
            let workItem = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
            logD("🔔     -> Auto-dismiss scheduled in \(timeout)s")
        }
    }
    
    func hide() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.orderOut(nil)
    }

    
    // MARK: - 위치 로직 (HistoryViewerManager에서 단순화됨)
    private func calculatePosition(width: CGFloat, height: CGFloat) -> NSPoint {
        let mouseLoc = NSEvent.mouseLocation
        let cursorMargin: CGFloat = 20
        
        // 가능한 경우 Tracker에서 커서 사각형 가져오기
        let cursorRect = CursorTracker.shared.getCursorRect()
        
        var targetPoint: NSPoint
        
        if let rect = cursorRect {
            // 텍스트 커서 근처에 배치
            let screen = NSScreen.screens.first { $0.frame.contains(rect.origin) } ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            
            var x = rect.minX
            var y = rect.minY - height - 10 // 커서 아래
            
            // 경계 확인
            if x + width > screenFrame.maxX { x = screenFrame.maxX - width - 10 }
            if x < screenFrame.minX { x = screenFrame.minX + 10 }
            
            // Y 확인 (아래 공간 부족 시 위로)
            if y < screenFrame.minY {
                y = rect.maxY + 10
            }
            
            targetPoint = NSPoint(x: x, y: y)
        } else {
            // 마우스 위치로 폴백
            let screen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            
            var x = mouseLoc.x
            var y = mouseLoc.y - height - cursorMargin
            
            if x + width > screenFrame.maxX { x = screenFrame.maxX - width - 10 }
            if x < screenFrame.minX { x = screenFrame.minX + 10 }
            if y < screenFrame.minY { y = mouseLoc.y + cursorMargin }
            
            targetPoint = NSPoint(x: x, y: y)
        }
        
        return targetPoint
    }
    
    // MARK: - NSWindowDelegate
    // Issue354: 포커스가 변경되어도 알림이 유지되도록 windowDidResignKey 제거
    // func windowDidResignKey(_ notification: Notification) {
    //     logD("🔔 [FloatingAlertManager] Window resigned key -> Hiding")
    //     hide()
    // }
}

struct FloatingAlertView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(message)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8)) // 어두운 HUD 스타일
                .shadow(radius: 10)
        )

        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        // [Issue350 개선] 닫기 버튼 추가
        .overlay(
            Button(action: {
                FloatingAlertManager.shared.hide()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8),
            alignment: .topTrailing
        )

    }
}