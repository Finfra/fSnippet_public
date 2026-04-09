import Foundation
import Cocoa
import ApplicationServices

// MARK: - Window Context Manager

/// 애플리케이션 활성화, 윈도우 포커스 추적 및 스레드 안전 상태 관리
class WindowContextManager {
    static let shared = WindowContextManager()
    
    // MARK: - 스레드 안전 상태 (Thread Safe State)
    private let stateQueue = DispatchQueue(label: "com.fsnippet.windowContextState", attributes: .concurrent)
    private var _isVisible: Bool = false
    private var _isReplacing: Bool = false
    private var _isAppActive: Bool = false
    
    var isVisible: Bool {
        get { stateQueue.sync { _isVisible } }
        set { stateQueue.async(flags: .barrier) { self._isVisible = newValue } }
    }
    
    var isReplacing: Bool {
        get { stateQueue.sync { _isReplacing } }
        set { stateQueue.async(flags: .barrier) { self._isReplacing = newValue } }
    }
    
    var isAppActive: Bool {
        get { stateQueue.sync { _isAppActive } }
        set { stateQueue.async(flags: .barrier) { self._isAppActive = newValue } }
    }
    
    // MARK: - 컨텍스트 추적 (Context Tracking)
    private var lastContext: (pid_t, CGWindowID)?
    private var observationRefs: [NSObjectProtocol] = []
    
    // 변경 알림을 위한 델리게이트 (선택 사항)
    var onContextChange: ((pid_t, CGWindowID?) -> Void)?
    
    // MARK: - Initialization
    
    private init() {}
    
    func startMonitoring() {
        startAppActivationMonitoring()
    }
    
    func stopMonitoring() {
        observationRefs.forEach { NotificationCenter.default.removeObserver($0) }
        observationRefs.removeAll()
    }
    
    private func startAppActivationMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        
        let obs1 = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleGlobalAppActivation(note)
        }
        observationRefs.append(obs1)
        
        // 활성 윈도우 변경 (전역 또는 로컬 로직이 이 알림을 트리거함)
        let obs2 = NotificationCenter.default.addObserver(forName: .didChangeActiveWindow, object: nil, queue: .main) { [weak self] note in
            self?.handleActiveWindowChange(note)
        }
        observationRefs.append(obs2)
    }
    
    private func handleActiveWindowChange(_ notification: Notification) {
        logV("🗂️ ⚙️ [WindowContextManager] Active Window Changed")
        checkContextChange()
    }
    
    private func handleGlobalAppActivation(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        
        // fSnippet 자체 확인
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            isAppActive = true
            return 
        } else {
            isAppActive = false
        }
        
        // 로그 및 알림
        logV("🗂️ ⚙️ [WindowContextManager] App Activated: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        
        // 컨텍스트 업데이트
        checkContextChange()
    }
    
    func checkContextChange() {
        if let currentContext = ContextUtils.shared.getCurrentFocusedWindowID() {
            if let last = self.lastContext {
                if last.0 != currentContext.0 || last.1 != currentContext.1 {
                    logV("🗂️ ⚙️ [WindowContextManager] Context Changed: \(last) -> \(currentContext)")
                    self.lastContext = currentContext
                    onContextChange?(currentContext.0, currentContext.1)
                }
            } else {
                self.lastContext = currentContext
                logV("🗂️ ⚙️ [WindowContextManager] Context Initialized: \(currentContext)")
                onContextChange?(currentContext.0, currentContext.1)
            }
        } else {
            self.lastContext = nil
        }
    }
    
    // KeyEventProcessor에서 원래 사용되던 헬퍼
    func updatePopupState(isVisible: Bool) {
        self.isVisible = isVisible
    }
    
    func updateReplacementState(isReplacing: Bool) {
        self.isReplacing = isReplacing
    }
}