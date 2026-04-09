import SwiftUI

/// 팝업 키보드 이벤트 처리 전용 클래스
class PopupKeyboardHandler: ObservableObject {
    @Published var selectedIndex: Int = 0
    
    // 수정자(modifiers)를 위해 내부 콜백 접근 필요
    let onEdit: (() -> Void)?
    
    private let maxIndex: () -> Int
    private let onSelection: (Int) -> Void
    private let onCancel: () -> Void
    
    init(
        maxIndex: @escaping () -> Int,
        onSelection: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void,
        onEdit: (() -> Void)? = nil
    ) {
        self.maxIndex = maxIndex
        self.onSelection = onSelection
        self.onCancel = onCancel
        self.onEdit = onEdit
    }
    
    /// 위쪽 화살표 키 처리
    func moveUp() {
        if selectedIndex > 0 {
            // ✅ Issue215: 뷰 업데이트 사이클 중 상태 변경 방지
            DispatchQueue.main.async { [weak self] in
                self?.selectedIndex -= 1
            }
        }
    }
    
    /// 아래쪽 화살표 키 처리
    func moveDown() {
        let maxCount = maxIndex()
        if selectedIndex < maxCount - 1 {
            // ✅ Issue215: 뷰 업데이트 사이클 중 상태 변경 방지
            DispatchQueue.main.async { [weak self] in
                self?.selectedIndex += 1
            }
        }
    }
    
    /// Enter 키 처리
    func confirmSelection() {
        onSelection(selectedIndex)
    }
    
    /// Escape 키 처리
    func cancel() {
        onCancel()
    }
    
    /// ✅ Issue225: 수정(Edit) 키 처리
    func edit() {
        onEdit?()
    }
    
    /// 인덱스 직접 설정
    func setSelectedIndex(_ index: Int) {
        let maxCount = maxIndex()
        let targetIndex: Int
        
        if maxCount > 0 {
            targetIndex = min(max(index, 0), maxCount - 1)
        } else {
            // 빈 리스트일 때는 기본값 0 유지 (음수 방지)
            targetIndex = 0
        }
        
        // ✅ Issue215: 뷰 업데이트 사이클 중 상태 변경 방지
        DispatchQueue.main.async { [weak self] in
            self?.selectedIndex = targetIndex
        }
    }
    
    /// ✅ Issue230: 항목 빠른 선택 (Index Setting + Confirm)
    func quickSelect(index: Int) {
        // 인덱스 유효성 검사 (setSelectedIndex와 유사하지만, 유효하지 않으면 동작 안함)
        let maxCount = maxIndex()
        guard index >= 0 && index < maxCount else { return }
        
        // UI 즉시 반영을 위해 setSelectedIndex 호출
        setSelectedIndex(index)
        
        // 선택 확정 (약간의 딜레이를 주어 UI가 선택 상태를 보여준 뒤 실행할지, 아니면 즉시 실행할지)
        // 즉시 실행이 반응성이 좋음.
        DispatchQueue.main.async { [weak self] in
             self?.onSelection(index)
        }
    }
    
    /// 키 이벤트 처리
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 125: // Down Arrow
            moveDown()
            return true
        case 126: // Up Arrow
            moveUp()
            return true
        case 36: // Enter
            confirmSelection()
            return true
        // ✅ Issue225: Tab 키로 수정창 열기
        case 48: // Tab
            onEdit?()
            return true
        case 53: // Escape
            cancel()
            return true
        default:
            return false
        }
    }
}

// MARK: - SwiftUI View Modifier

struct PopupKeyboardModifier: ViewModifier {
    @ObservedObject var keyboardHandler: PopupKeyboardHandler
    // Issue 230: 수정자를 확인하기 위해 설정 접근
    @ObservedObject var settings = SettingsObservableObject.shared
    
    func body(content: Content) -> some View {
        content
            .onKeyPress { press in
                // Issue 230: 빠른 선택 (검색어 + 숫자)
                // 1. 구성된 수정자가 눌렸는지 확인
                let requiredModifierRaw = UInt(settings.popupQuickSelectModifierFlags)
                let requiredModifier = NSEvent.ModifierFlags(rawValue: requiredModifierRaw)
                
                // press.modifiers는 현재 수정자들을 가짐.
                // 구성된 수정자와 일치하는지 확인 (일부 경우 암시적 Shift 허용하지만, 엄격하게: Mod + Number)
                // 참고: onKeyPress 수정자는 엄격할 수 있음.
                // 교집합 또는 엄격한 동등성 확인. 일반적으로 단축키의 경우 엄격한 것이나 '포함'이 좋음.
                
                // OptionSet으로서의 단순성을 위해 Raw Value 비교
                // 기능 없는 수정자 필터링 (필요한 경우 CapsLock, numericPad 등)
                let relevantModifiers = press.modifiers.intersection([.command, .control, .option, .shift])
                
                // 요구되는 것이 Command라면, Command + 1을 원함.
                // 사용자가 Command + Shift + 1을 누르면 작동해야 하는가? 엄격한 빠른 선택의 경우 일반적으로 "아니오".
                
                let isModifierMatch: Bool
                if requiredModifier.contains(.command) { isModifierMatch = relevantModifiers.contains(.command) }
                else if requiredModifier.contains(.option) { isModifierMatch = relevantModifiers.contains(.option) }
                else if requiredModifier.contains(.control) { isModifierMatch = relevantModifiers.contains(.control) }
                else { isModifierMatch = false } // 구성된 수정자 없음?
                
                if isModifierMatch {
                    if let number = Int(press.characters), (1...9).contains(number) {
                        // 1 -> Index 0
                        keyboardHandler.quickSelect(index: number - 1)
                        return .handled
                    }
                }
                
                return .ignored
            }
            .onKeyPress(.upArrow) {
                keyboardHandler.moveUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                keyboardHandler.moveDown()
                return .handled
            }
            .onKeyPress(.return) {
                keyboardHandler.confirmSelection()
                return .handled
            }
            .onKeyPress(.tab) { // ✅ Issue225: Tab 키 지원
                keyboardHandler.onEdit?()
                return .handled
            }
            .onKeyPress(.escape) {
                keyboardHandler.cancel()
                return .handled
            }
    }
}

extension View {
    func popupKeyboardHandler(_ handler: PopupKeyboardHandler) -> some View {
        self.modifier(PopupKeyboardModifier(keyboardHandler: handler))
    }
}
