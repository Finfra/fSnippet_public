import Foundation

extension Notification.Name {
    // 트리거키 관련
    static let triggerKeyManagerDidUpdateActiveTriggerKeys = Notification.Name(
        "triggerKeyManagerDidUpdateActiveTriggerKeys")
    static let triggerKeyManagerDidUpdateDefaultTriggerKey = Notification.Name(
        "triggerKeyManagerDidUpdateDefaultTriggerKey")
    static let triggerKeyDidChange = Notification.Name("triggerKeyDidChange")

    // 히스토리 관련
    static let historyPauseStateChanged = Notification.Name("historyPauseStateChanged")
    static let historyViewerDidShow = Notification.Name("historyViewerDidShow")
    static let historyViewerDidHide = Notification.Name("historyViewerDidHide")

    // 앱 제어 관련
    static let quitRequested = Notification.Name("quitRequested")

    // 설정 관련
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let logLevelDidChange = Notification.Name("logLevelDidChange")
    static let popupSearchScopeDidChange = Notification.Name("popupSearchScopeDidChange")
    static let popupRowsDidChange = Notification.Name("popupRowsDidChange")

    // 스니펫 관련
    static let snippetIndexDidUpdate = Notification.Name("snippetIndexDidUpdate")
    static let snippetFoldersDidChange = Notification.Name("snippetFoldersDidChange")
    static let ruleDidChange = Notification.Name("ruleDidChange")  // Issue689_1: Alfred Import 후 규칙 변경 감지

    // UI Size (Issue355)
    static let popupWidthDidChange = Notification.Name("popupWidthDidChange")

    // UI Size (Issue595)
    static let popupPreviewWidthDidChange = Notification.Name("popupPreviewWidthDidChange")

    // Window Management (Issue383)
    static let closeAuxiliaryWindows = Notification.Name("closeAuxiliaryWindows")

    // Issue392_2: Active Window Change Logic
    static let didChangeActiveWindow = Notification.Name("didChangeActiveWindow")

    // Settings Updates
    static let preferencesDidUpdate = Notification.Name("preferencesDidUpdate")
    static let preferencesDidLoadConfig = Notification.Name("preferencesDidLoadConfig")
}
