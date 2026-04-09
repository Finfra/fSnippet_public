import AppKit
import Foundation

// MARK: - Mock TextReplacer (Issue795)

class MockTextReplacer: TextReplacerProtocol {

    // 테스트 검증용 속성
    var replaceAsyncCallCount = 0
    var replaceSyncCallCount = 0
    var insertOnlyCallCount = 0
    var cleanupCallCount = 0
    var lastAbbreviation: String?
    var lastSnippetContent: String?
    var mockResult = true

    var lastErrorInfo: TextReplacerError? { return nil }

    func replaceTextAsync(
        abbreviation: String,
        with snippetContent: String,
        referenceFrame: NSRect?,
        snippetPath: String?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        replaceAsyncCallCount += 1
        lastAbbreviation = abbreviation
        lastSnippetContent = snippetContent
        completion(mockResult, nil)
    }

    @discardableResult
    func replaceTextSync(
        abbreviation: String, with snippetContent: String,
        referenceFrame: NSRect?, snippetPath: String?
    ) -> Bool {
        replaceSyncCallCount += 1
        lastAbbreviation = abbreviation
        lastSnippetContent = snippetContent
        return mockResult
    }

    func insertOnlyTextSync(_ content: String) -> Bool {
        insertOnlyCallCount += 1
        return mockResult
    }

    func cleanup() {
        cleanupCallCount += 1
    }
}

// MARK: - Mock PopupController (Issue795)

class MockPopupController: PopupControllerProtocol {

    // 테스트 검증용 속성
    var showPopupCallCount = 0
    var hidePopupCallCount = 0
    var updateSearchTermCallCount = 0
    var lastSearchTerm: String?
    var lastCandidates: [SnippetEntry] = []

    private(set) var isVisible: Bool = false
    private(set) var mode: PopupMode = .typing
    var currentSearchTerm: String = ""

    func showPopup(
        with candidates: [SnippetEntry],
        searchTerm: String,
        cursorRect: CGRect?,
        onSelection: @escaping (SnippetEntry, String, NSRect?) -> Void
    ) {
        showPopupCallCount += 1
        lastCandidates = candidates
        lastSearchTerm = searchTerm
        isVisible = true
    }

    func updateSearchTerm(_ searchTerm: String) {
        updateSearchTermCallCount += 1
        currentSearchTerm = searchTerm
    }

    func hidePopup(hideApp: Bool) {
        hidePopupCallCount += 1
        isVisible = false
    }

    func updateCandidates(_ candidates: [SnippetEntry]) {
        lastCandidates = candidates
    }

    func handleArrowKey(_ keyCode: UInt16) {
        mode = .selecting
    }

    func selectCurrentItem() {}

    func resetSelection() {
        mode = .typing
    }

    func cleanup() {
        isVisible = false
    }
}

// MARK: - Mock ClipboardManager (Issue795)

class MockClipboardManager: ClipboardManagerProtocol {

    // 테스트 검증용 속성
    var startMonitoringCallCount = 0
    var stopMonitoringCallCount = 0
    var copyCallCount = 0
    var lastCopiedText: String?
    var mockHistory: [String] = []

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    func getHistory(at index: Int) -> String? {
        guard index >= 0 && index < mockHistory.count else { return nil }
        return mockHistory[index]
    }

    func getAllHistory() -> [String] {
        return mockHistory
    }

    func copyToPasteboard(text: String) {
        copyCallCount += 1
        lastCopiedText = text
    }

    func runMaintenanceNow() {}
}
