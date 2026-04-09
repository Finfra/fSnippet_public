import Cocoa
import SwiftUI

// MARK: - 스니펫 편집기 윈도우 관리 (Stub)
// 스니펫 편집 GUI는 fSnippet 메인 앱에서 제공.
// fSnippetCli에서는 다른 컴포넌트 호환을 위한 stub만 유지.

class SnippetEditorWindowManager: NSObject {
    static let shared = SnippetEditorWindowManager()

    private var editorWindow: NSWindow?
    private var currentSnippetEntry: SnippetEntry?

    override init() {
        super.init()
    }

    func showEditor(for snippet: SnippetEntry, relativeTo relativeRect: NSRect? = nil) {
        logD("✏️ [Editor] 스니펫 편집 GUI는 fSnippet 메인 앱에서 제공됨")
    }

    func isEditorWindow(_ window: NSWindow?) -> Bool {
        return false
    }

    func showNewEditor(keyword: String, content: String = "", relativeTo relativeRect: NSRect? = nil) {
        logD("✏️ [Editor] 스니펫 편집 GUI는 fSnippet 메인 앱에서 제공됨")
    }

    func closeEditor() {
        editorWindow = nil
        currentSnippetEntry = nil
    }
}

extension SnippetEditorWindowManager: NSWindowDelegate {}
