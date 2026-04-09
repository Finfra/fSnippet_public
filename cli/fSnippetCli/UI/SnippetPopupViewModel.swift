import Foundation
import SwiftUI

/// Snippet 팝업의 상태를 관리하는 뷰 모델
class SnippetPopupViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var snippets: [SnippetEntry] = []
    @Published var initialSearchTerm: String = "" // ✅ Issue169: 초기 검색어 전달용
    @Published var listUpdateTrigger = UUID() // ✅ Issue219_1: 리스트 업데이트 신호
    
    var onSelection: ((SnippetEntry) -> Void)?
    var onCancel: (() -> Void)?
    var onSearchTermChanged: ((String) -> Void)? // ✅ Issue170: 검색어 변경 알림 콜백
    var onTransitionToEditor: ((SnippetEntry) -> Void)? // ✅ Issue219_2: 편집기 전환 콜백
    var onAddNewSnippet: ((String) -> Void)? // ✅ Issue 257: 신규 스니펫 생성 콜백
    @Published var suggestedCreateTerm: String? // ✅ Issue 356/357: 검색 실패 시 제안할 생성 용어

    
    /// 선택 인덱스를 업데이트
    func updateSelectedIndex(_ index: Int) {
        guard index >= 0 && index < snippets.count else { return }
        selectedIndex = index
    }
    
    /// 선택을 위로 이동
    func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
            // ✅ Issue272: 불필요한 DispatchQueue.main.async 제거
            self.objectWillChange.send()
        }
    }
    
    /// 선택을 아래로 이동
    func moveSelectionDown() {
        if selectedIndex < snippets.count - 1 {
            selectedIndex += 1
            // ✅ Issue272: 불필요한 DispatchQueue.main.async 제거
            self.objectWillChange.send()
        }
    }
    
    /// 현재 선택된 항목 반환
    func getCurrentSelection() -> SnippetEntry? {
        guard selectedIndex >= 0 && selectedIndex < snippets.count else { return nil }
        return snippets[selectedIndex]
    }
    
    /// 선택 확정
    func confirmSelection() {
        logI("💭 SnippetPopupViewModel.confirmSelection 호출")
        if let selected = getCurrentSelection() {
            logI("💭 선택된 스니펫: '\(selected.abbreviation)' - onSelection 콜백 호출")
            onSelection?(selected)
        } else {
            logW("💭 ⚠️ 선택된 스니펫이 없음")
        }
    }
    
    /// 취소
    func cancel() {
        onCancel?()
    }
    
    /// 스니펫 목록 업데이트
    func updateSnippets(_ newSnippets: [SnippetEntry], force: Bool = false) {
        // Issue261 수정: 내용이 동일한 경우 불필요한 업데이트 방지
        // 실제 변경 사항을 감지하기 위해 개수와 ID 비교
        if !force && snippets.count == newSnippets.count {
            let currentIds = snippets.map { $0.id }
            let newIds = newSnippets.map { $0.id }
            if currentIds == newIds {
                logV("💭 [Popup] 동일한 스니펫 목록, 업데이트 건너뜀")
                return
            }
        }

        snippets = newSnippets
        selectedIndex = 0 // 첫 번째 항목으로 리셋

        // UI 업데이트 강제 실행
        DispatchQueue.main.async {
            self.listUpdateTrigger = UUID() // ✅ Issue219_1: 변경 신호 발생
            logV("💭 [Popup] 남은 스니펫 개수: \(newSnippets.count)") // ✅ 사용자 요청: 개수 로그
            logV("💭 스니펫 목록 업데이트됨: \(newSnippets.count)개, selectedIndex=\(self.selectedIndex)")
        }
    }
}