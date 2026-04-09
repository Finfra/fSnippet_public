import Foundation

// MARK: - PreferencesManager Protocol
// 실제 구현: get<T>(_:), set(_:forKey:), string(forKey:defaultValue:), bool(forKey:defaultValue:)
protocol PreferencesManagerProtocol: AnyObject {
    func get<T>(_ key: String) -> T?
    func set(_ value: Any?, forKey key: String)
    func string(forKey key: String, defaultValue: String) -> String
    func bool(forKey key: String, defaultValue: Bool) -> Bool
    func loadConfig()
    func ensureStructure()
    func ensureStructureSync()
    func batchUpdate(_ block: @escaping (inout [String: Any]) -> Void)
}

// MARK: - TriggerKeyManager Protocol
protocol TriggerKeyManagerProtocol: AnyObject {
    func registerTriggerKeys()
    func syncToPSKeyManager()
}

// MARK: - ShortcutMgr Protocol
protocol ShortcutMgrProtocol: AnyObject {
    func isRegisteredShortcut(_ keyCombo: String) -> Bool
}

// MARK: - SnippetIndexManager Protocol
protocol SnippetIndexManagerProtocol: AnyObject {
    func search(query: String, maxResults: Int) -> [String]
    func invalidateCache()
}

// MARK: - RuleManager Protocol
// 실제 구현: loadRules(from:), getRule(for:)
protocol RuleManagerProtocol: AnyObject {
    @discardableResult
    func loadRules(from filePath: String) -> Bool
    func getRule(for collectionName: String) -> RuleManager.CollectionRule?
}

// MARK: - TextReplacer Protocol (Issue795)
// 핵심 텍스트 대체 인터페이스
protocol TextReplacerProtocol: AnyObject {
    func replaceTextAsync(
        abbreviation: String,
        with snippetContent: String,
        referenceFrame: NSRect?,
        snippetPath: String?,
        completion: @escaping (Bool, Error?) -> Void
    )
    @discardableResult
    func replaceTextSync(
        abbreviation: String, with snippetContent: String,
        referenceFrame: NSRect?, snippetPath: String?
    ) -> Bool
    func insertOnlyTextSync(_ content: String) -> Bool
    func cleanup()
    var lastErrorInfo: TextReplacerError? { get }
}

// MARK: - PopupController Protocol (Issue795)
// 스니펫 팝업 표시/숨김 및 후보 관리 인터페이스
protocol PopupControllerProtocol: AnyObject {
    var isVisible: Bool { get }
    var mode: PopupMode { get }
    var currentSearchTerm: String { get }
    func showPopup(
        with candidates: [SnippetEntry],
        searchTerm: String,
        cursorRect: CGRect?,
        onSelection: @escaping (SnippetEntry, String, NSRect?) -> Void
    )
    func updateSearchTerm(_ searchTerm: String)
    func hidePopup(hideApp: Bool)
    func updateCandidates(_ candidates: [SnippetEntry])
    func handleArrowKey(_ keyCode: UInt16)
    func selectCurrentItem()
    func resetSelection()
    func cleanup()
}

// MARK: - ClipboardManager Protocol (Issue795)
// 클립보드 히스토리 관리 인터페이스
protocol ClipboardManagerProtocol: AnyObject {
    func startMonitoring()
    func stopMonitoring()
    func getHistory(at index: Int) -> String?
    func getAllHistory() -> [String]
    func copyToPasteboard(text: String)
    func runMaintenanceNow()
}
