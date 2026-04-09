import SwiftUI
import Cocoa

/// 스니펫 미리보기 데이터 상태 관리 (Issue 560)
/// 아키텍처 통합에 따라 윈도우 관리 로직이 제거되고 데이터 공급자 역할로 전환됨
class SnippetPreviewManager: ObservableObject {
    static let shared = SnippetPreviewManager()
    
    // 현재 표시 중인 스니펫
    @Published var currentSnippet: SnippetEntry?
    
    private init() {
        // 보조 윈도우 닫기 알림 수신 (필요시 상태 초기화)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCloseAuxiliaryWindows(_:)), name: .closeAuxiliaryWindows, object: nil)
    }
    
    // [Issue383] 보조 윈도우 닫기 처리
    @objc private func handleCloseAuxiliaryWindows(_ notification: Notification) {
        hide()
    }
    
    /// 미리보기용 스니펫을 설정합니다.
    /// UnifiedSnippetPopupView가 이 상태를 관찰하여 화면을 갱신합니다.
    func show(snippet: SnippetEntry, relativeTo frame: NSRect = .zero) {
        // 중복 업데이트 방지
        if let current = currentSnippet, current.id == snippet.id {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.currentSnippet = snippet
        }
        
        logV("🔭 [Preview] currentSnippet 업데이트: \(snippet.abbreviation)")
    }
    
    /// 미리보기를 숨깁니다 (상태 초기화).
    func hide() {
        if currentSnippet != nil {
            currentSnippet = nil
            logV("🔭 [Preview] Preview state cleared")
        }
    }
    
    // 레거시 메서드 호환성 유지 (호출 지점 제거 예정)
    func registerPopupWindow(_ window: NSWindow) {}
    func updatePosition(relativeTo frame: NSRect) {}
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
