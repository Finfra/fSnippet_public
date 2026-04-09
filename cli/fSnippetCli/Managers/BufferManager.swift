import Foundation

protocol BufferManagerDelegate: AnyObject {
    func bufferDidClear(reason: String)
}

/// 버퍼 관리자 (텍스트 버퍼 캡슐화)
/// 버퍼 상태 관리 및 초기화 로직을 중앙 집중화합니다.
class BufferManager {

    // MARK: - 속성

    static let shared = BufferManager()

    private let textBuffer: TextBuffer
    weak var delegate: BufferManagerDelegate?

    // MARK: - 초기화

    private init() {
        self.textBuffer = TextBuffer(maxLength: 100)
    }

    // MARK: - 공개 메서드

    /// 버퍼를 지우고 델리게이트에 알립니다.
    /// 이것은 버퍼 삭제를 위한 단일 제어 지점입니다.
    func clear(reason: String) {
        // logI("📥 [BufferManager] \(reason) - Clearing Buffer")
        textBuffer.clear()
        delegate?.bufferDidClear(reason: reason)
    }

    // MARK: - TextBuffer 프록시 메서드

    func append(_ text: String) {
        textBuffer.append(text)
    }

    func removeLast() {
        textBuffer.removeLast()
    }

    func getCurrentText() -> String {
        return textBuffer.getCurrentText()
    }

    func hasSuffix(_ suffix: String) -> Bool {
        return textBuffer.hasSuffix(suffix)
    }

    func extractSearchTerm() -> String {
        return textBuffer.extractSearchTerm()
    }

    func findAbbreviationCandidates(triggerKey: String) -> [String] {
        return textBuffer.findAbbreviationCandidates(triggerKey: triggerKey)
    }

    var isEmpty: Bool {
        return textBuffer.isEmpty
    }

    var count: Int {
        return textBuffer.count
    }
    /// 버퍼 내용을 새로운 텍스트로 교체
    func replaceBuffer(with text: String) {
        textBuffer.replaceBuffer(with: text)
    }
}
