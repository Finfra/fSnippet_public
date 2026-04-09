import Foundation

// MARK: - 표준 편집 동작 프로토콜
/// 표준 편집 동작(Undo/Redo/Cut/Copy/Paste/SelectAll)을 위한 프로토콜 정의
/// Selector("string") 사용 시 발생하는 경고를 방지하기 위해 사용
@objc protocol StandardEditActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func cut(_ sender: Any?)
    func copy(_ sender: Any?)
    func paste(_ sender: Any?)
    func selectAll(_ sender: Any?)
}
