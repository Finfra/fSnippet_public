import Cocoa
import Foundation
import SwiftUI

// MARK: - 팝업 키 단축키 구조체
struct PopupKeyShortcut: Codable, Equatable, CustomStringConvertible {
    var modifierFlags: UInt  // NSEvent.ModifierFlags rawValue
    var keyCode: UInt16  // 키 코드
    var displayString: String  // 표시용 문자열 (예: "⌃⌥P")

    static let `default` = PopupKeyShortcut(
        modifierFlags: 262144,  // Control 키 (원래 기본 스니펫 팝업키)
        keyCode: 50,  // 백틱 키 (`)
        displayString: "⌃`"
    )

    // CustomStringConvertible 구현
    var description: String {
        return displayString
    }

    // NSEvent.ModifierFlags로 변환
    var nsModifierFlags: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifierFlags)
    }

    // MARK: - Utility: String <-> PopupKeyShortcut Conversion

    /// "^⌥⌘;" 와 같은 문자열을 PopupKeyShortcut으로 변환
    /// "^⌥⌘;" 와 같은 문자열을 PopupKeyShortcut으로 변환
    static func from(hotkeyString: String) -> PopupKeyShortcut {
        var modifiers: NSEvent.ModifierFlags = []
        var keyStr = hotkeyString

        // Issue 449: 중괄호가 있으면 제거 (예: "{keypad_comma}")
        if keyStr.hasPrefix("{") && keyStr.hasSuffix("}") {
            keyStr = String(keyStr.dropFirst().dropLast())
        }

        if keyStr.contains("^") {
            modifiers.insert(.control)
            keyStr = keyStr.replacingOccurrences(of: "^", with: "")
        }
        if keyStr.contains("⌥") {
            modifiers.insert(.option)
            keyStr = keyStr.replacingOccurrences(of: "⌥", with: "")
        }
        if keyStr.contains("⌘") {
            modifiers.insert(.command)
            keyStr = keyStr.replacingOccurrences(of: "⌘", with: "")
        }
        if keyStr.contains("⇧") {
            modifiers.insert(.shift)
            keyStr = keyStr.replacingOccurrences(of: "⇧", with: "")
        }
        if keyStr.contains("⇪") {
            modifiers.insert(.capsLock)
            keyStr = keyStr.replacingOccurrences(of: "⇪", with: "")
        }

        // 만약을 대비해 표시용 수식어(예: ⌃) 제거
        for modChar in ["⌃", "⌥", "⌘", "⇧"] {
            keyStr = keyStr.replacingOccurrences(of: modChar, with: "")
        }

        // 특수 키 역매핑
        if keyStr == " " { keyStr = "Space" }

        // KeyCode 해결
        var keyCode: UInt16 = 0
        if let codes = TriggerKeyManager.reverseKeyMap[keyStr], let firstCode = codes.first {
            keyCode = firstCode
        }

        let displayStr = createDisplayString(modifiers: modifiers, code: keyCode, char: keyStr)
        return PopupKeyShortcut(
            modifierFlags: modifiers.rawValue,
            keyCode: keyCode,  // 이제 올바르게 해결됨
            displayString: displayStr
        )
    }

    /// 현재 단축키를 PreferencesManager 스타일의 문자열("^⌥⌘;")로 변환
    var toHotkeyString: String {
        var result = ""
        let flags = nsModifierFlags

        // Issue 298: 오른쪽 수식어 구분 지원
        // 오른쪽 수식어가 하나라도 있으면 상세 형식(예: "right_command+...") 사용
        // 그렇지 않으면 하위 호환성 및 미관을 위해 표준 기호(예: "⌘") 사용

        let hasRightModifiers =
            flags.contains(.deviceRightCommand) || flags.contains(.deviceRightShift)
            || flags.contains(.deviceRightOption) || flags.contains(.deviceRightControl)

        if hasRightModifiers {
            // EnhancedTriggerKey.from(keySpec:)에 적응 가능한 상세 형식 사용
            // "right_command+left_shift+..."와 같은 문자열 구성
            // 하지만 EnhancedTriggerKey 스타일은 "flags right_command"임
            // EnhancedTriggerKey.from이 파싱할 수 있는 형식 사용: "right_command+..."

            var parts: [String] = []
            if flags.contains(.command) {
                parts.append(flags.contains(.deviceRightCommand) ? "right_command" : "left_command")
            }
            if flags.contains(.shift) {
                parts.append(flags.contains(.deviceRightShift) ? "right_shift" : "left_shift")
            }
            if flags.contains(.option) {
                parts.append(flags.contains(.deviceRightOption) ? "right_option" : "left_option")
            }
            if flags.contains(.control) {
                parts.append(flags.contains(.deviceRightControl) ? "right_control" : "left_control")
            }
            if flags.contains(.capsLock) { parts.append("caps_lock") }

            result = parts.joined(separator: "+") + "+"

            // Issue 310: 수식어 전용 트리거(예: right_option)의 지속성 수정
            // 키가 수식어(54-62)인 경우 후행 "+"를 제거하고 keyPart를 추가하지 않음.
            if (54...62).contains(self.keyCode) {
                if result.hasSuffix("+") {
                    result.removeLast()
                }
                if result.isEmpty { return "" }
                return "{\(result)}"
            }
        } else {
            // 표준 기호 형식
            if flags.contains(.control) { result += "^" }
            if flags.contains(.option) { result += "⌥" }
            if flags.contains(.command) { result += "⌘" }
            if flags.contains(.shift) { result += "⇧" }
            if flags.contains(.capsLock) { result += "⇪" }
        }

        // Issue 400_3: 빈 단축키(KeyCode 0) 처리
        // keyCode가 0이고 수식어가 없으면(또는 빈 플래그만 있으면) "A" 대신 빈 문자열 반환
        if keyCode == 0 && flags.isEmpty {
            return ""
        }

        // displayString에서 Modifiers 제거하고 남은 키 추출 (Legacy 방식)
        // Issue 296: displayString이 특수문자(예: π)일 경우 복원에 실패하므로 keyCode 기반 역추적 사용

        var keyPart = "?"

        // Issue 464: 개선된 역방향 조회
        // 1. TriggerKeyManager의 모든 매핑 순회
        let candidates = TriggerKeyManager.reverseKeyMap.filter { $0.value.contains(keyCode) }.map {
            $0.key
        }

        // 2. 후보 필터링 및 정렬
        // "unknown_95"를 피하고 "keypad_comma"를 선호함.
        let bestCandidate = candidates.sorted { (key1, key2) -> Bool in
            let isUnknown1 = key1.hasPrefix("unknown_")
            let isUnknown2 = key2.hasPrefix("unknown_")

            if isUnknown1 != isUnknown2 {
                return !isUnknown1  // unknown이 아닌 것을 선호
            }

            let isKeypad1 = key1.hasPrefix("keypad_")
            let isKeypad2 = key2.hasPrefix("keypad_")

            if isKeypad1 != isKeypad2 {
                return isKeypad1  // keypad_ 선호
            }

            return key1.count < key2.count  // 동률일 경우 더 짧은 이름 (예: "space_bar" 대신 "Space")
        }.first

        if let best = bestCandidate {
            keyPart = best
        }

        // 역추적 실패 시 기존 방식(displayString 파싱) Fallback (구버전 호환)
        if keyPart == "?" {
            var fallback = displayString
            for modChar in ["⌃", "⌥", "⌘", "⇧"] {
                fallback = fallback.replacingOccurrences(of: modChar, with: "")
            }
            keyPart = fallback
        }

        // 특수 키 매핑 (Space 등) - Issue 427: "Space"를 명시적으로 표시하기 위해 제거됨
        // if keyPart == "Space" { keyPart = " " }

        result += keyPart

        // Issue 515: 저장 시 중괄호 강제
        // 감싸진 문자열 반환 (예: "{keypad_comma}" 또는 "{^A}")
        if result.isEmpty { return "" }
        if result.hasPrefix("{") && result.hasSuffix("}") { return result }
        return "{\(result)}"
    }

    private static func createDisplayString(
        modifiers: NSEvent.ModifierFlags, code: UInt16, char: String
    ) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.capsLock) { result += "⇪" }
        result += char

        // Issue 296: 특수 문자 표시(예: Option+P -> π)를 위해 KeyRenderingManager 사용
        // Issue 314_4: 파일에서 로드된 단축키에 대해 표준 표시 문자열(예: "⌥⇧V")을 강제하려면 keyString에 nil 전달.
        // 'char'(예: "V")를 전달하면 KeyRenderingManager는 "V"가 Option+Shift+V의 특수 결과라고 생각하는데, 이는 틀림.
        return KeyRenderingManager.shared.getDisplayString(
            modifiers: modifiers,
            keyString: nil,
            keyCode: code,
            standardDisplayString: result
        )
    }
}

// MARK: - Issue 178: Popup Search Scope

// MARK: - 설정 모델
struct SnippetSettings: Codable, Equatable {
    var basePath: String
    var basePathBookmark: String?  // Issue 194: Security Scoped Bookmark (Base64 Encoded)
    var appRootPath: String  // Issue 188: 앱 루트 경로 (설정 파일 등 저장 위치)
    var popupKeyShortcut: PopupKeyShortcut  // 팝업 키 단축키
    var defaultSymbol: String  // 기본 트리거키 (유저 설정 가능)
    var triggerBias: Int  // 트리거 바이어스 (+1: 한글자 더, -1: 한글자 덜, 0: 기본)
    // var triggerBiasAux: Int // Deprecated: Moved to AppSettingManager
    var popupSearchScope: PopupSearchScope  // Issue 178
    var popupHeight: Double  // Issue 178 (Deprecated, maintained for backward compatibility)
    var popupRows: Int  // Issue 245: Height by rows
    var folderSymbols: [String: String]  // 폴더별 Suffix 매핑 (기존 folderSymbols 유지)
    var folderPrefixes: [String: String]  // 폴더별 Prefix 매핑 (신규 추가)
    var folderPrefixShortcuts: [String: String]  // 폴더별 Prefix 단축키 매핑 (신규 추가 Issue 401)
    var excludedFiles: [String]  // 전역 제외 파일 목록
    var folderExcludedFiles: [String: [String]]  // 폴더별 제외 파일 매핑
    var popupQuickSelectModifierFlags: Int  // Issue 230: 팝업 빠른 선택 Modifier (Cmd/Opt/Ctrl)
    var statsRetentionUsageDays: Int  // Issue 376: 통계 저장 기간 (0: 무한대, n: 일)
    var appearanceMode: String  // Issue 386: 다크모드 설정 (system, dark, light)
    var settingsHotkey: PopupKeyShortcut  // Issue727: 설정창 열기 글로벌 단축키

    // MARK: - Clipboard History Settings (Integrated)
    var historyEnabledPlainText: Bool
    var historyRetentionDaysPlainText: Int
    var historyEnabledImages: Bool
    var historyRetentionDaysImages: Int
    var historyEnabledFileLists: Bool
    var historyRetentionDaysFileLists: Int
    var historyViewerHotkey: PopupKeyShortcut
    var historyPauseHotkey: PopupKeyShortcut
    var historyIgnoreImages: Bool
    var historyIgnoreFileLists: Bool
    var historyMoveDuplicatesToTop: Bool
    var historyShowStatusBar: Bool  // CL035
    var historyForceInputSource: String  // CL038
    var historyShowPreview: Bool  // CL042
    var historyPreviewHotkey: PopupKeyShortcut  // CL042
    var historyRegisterSnippetHotkey: PopupKeyShortcut  // CL042
    var historyViewerWidth: CGFloat
    var historyPreviewWidth: CGFloat

    // Issue 595: Popup Preview Width
    var popupPreviewWidth: CGFloat

    // Issue 649: 마지막 선택 스니펫 등록 폴더
    var lastSelectedFolder: String?

    // Issue 684: Alfred Import 규칙 파일 경로
    var alfredImportRulePath: String?
    var alfredImportRulePathBookmark: String?

    static var `default`: SnippetSettings {

        let appRootPath = PreferencesManager.resolveAppRootPath()
        let basePath = URL(fileURLWithPath: appRootPath).appendingPathComponent("snippets").path

        return SnippetSettings(
            basePath: basePath,
            basePathBookmark: nil,  // 기본값: 북마크 없음
            appRootPath: appRootPath,
            popupKeyShortcut: PopupKeyShortcut.default,
            defaultSymbol: "◊",  // 트리거 키
            triggerBias: 0,
            // triggerBiasAux: 0, // Deprecated
            popupSearchScope: .abbreviation,  // 기본값
            popupHeight: 300.0,  // 기본값 (사용 안 함)
            popupRows: 10,  // Issue 245 기본값
            folderSymbols: [:],
            folderPrefixes: [:],
            folderPrefixShortcuts: [:],
            excludedFiles: ["README.md", "_README.md", "z_old", ".gitignore", ".DS_Store"],
            folderExcludedFiles: [:],
            popupQuickSelectModifierFlags: Int(NSEvent.ModifierFlags.command.rawValue),  // 기본값 Command
            statsRetentionUsageDays: 30,  // Issue 376: 기본값 30일
            appearanceMode: "system",  // Issue 386: 기본값 system
            settingsHotkey: PopupKeyShortcut.from(hotkeyString: "^⇧⌘;"),  // Issue727: 기본값 Control+Shift+Command+;

            // 히스토리 기본값
            historyEnabledPlainText: true,
            historyRetentionDaysPlainText: 90,
            historyEnabledImages: true,
            historyRetentionDaysImages: 7,
            historyEnabledFileLists: true,
            historyRetentionDaysFileLists: 30,
            historyViewerHotkey: PopupKeyShortcut.from(hotkeyString: "^⌥⌘;"),
            historyPauseHotkey: PopupKeyShortcut.from(hotkeyString: "^⌥⌘P"),
            historyIgnoreImages: false,
            historyIgnoreFileLists: true,
            historyMoveDuplicatesToTop: true,
            historyShowStatusBar: true,  // 기본값 true
            historyForceInputSource: "keep",  // CL038 기본값
            historyShowPreview: true,  // CL042 기본값
            historyPreviewHotkey: PopupKeyShortcut.from(hotkeyString: ""),  // CL042 기본값 (비어 있음)
            historyRegisterSnippetHotkey: PopupKeyShortcut.from(hotkeyString: "⌘S"),  // CL042 기본값 (Cmd+S)
            historyViewerWidth: 350.0,
            historyPreviewWidth: 400.0,
            popupPreviewWidth: 400.0,  // Issue 595 기본값
            lastSelectedFolder: nil as String?,  // Issue 649
            alfredImportRulePath: nil as String?,
            alfredImportRulePathBookmark: nil as String?
        )
    }
}

// MARK: - 설정 매니저
class SettingsManager {
    static let shared = SettingsManager()

    // Issue 621_1: 메모리 캐싱 도입
    private var cachedSettings: SnippetSettings?
    private let cacheLock = NSLock()

    private init() {
        // 설정 변경 알림 구독하여 캐시 무효화
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(invalidateCache),
            name: .settingsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func invalidateCache() {
        cacheLock.lock()
        cachedSettings = nil
        cacheLock.unlock()
    }

    // 개별 UserDefaults 키들 (사람이 읽을 수 있는 형태) -> Snake Case로 변경 (YAML 통일성)
    private let basePathKey = "snippet_base_path"
    private let basePathBookmarkKey = "snippet_base_path_bookmark"  // Issue 194
    private let appRootPathKey = "appRootPath"  // Issue 188
    private let defaultSymbolKey = "snippet_trigger_key"
    private let triggerBiasKey = "snippet_trigger_bias"
    private let triggerBiasAuxKey = "snippet_trigger_bias_aux"  // Restored

    // Issue 178 Keys
    private let popupSearchScopeKey = "snippet_popup_search_scope"
    private let popupHeightKey = "snippet_popup_height"
    private let popupRowsKey = "snippet_popup_rows"  // Issue 245
    private let popupPreviewWidthKey = "snippet_popup_preview_width"  // Issue 595
    private let lastSelectedFolderKey = "snippet_last_selected_folder"  // Issue 649
    private let alfredImportRulePathKey = "alfred_import_rule_path"
    private let alfredImportRulePathBookmarkKey = "alfred_import_rule_path_bookmark"

    // 팝업 키 관련
    private let popupModifierFlagsKey = "snippet_popup_modifier_flags"
    private let popupKeyCodeKey = "snippet_popup_key_code"
    private let popupDisplayStringKey = "snippet_popup_hotkey"
    private let previousPopupDisplayStringKey = "snippet_popup_display_string"  // Issue258 Legacy

    // Issue 230: Quick Select Modifier
    private let popupQuickSelectModifierFlagsKey = "snippet_popup_quick_select_modifier_flags"

    // Issue 376: Stats Retention (Usage Days)
    private let statsRetentionUsageDaysKey = "snippet_stats_retention_usage_days"
    // Issue 386: Appearance Mode
    private let appearanceModeKey = "appearance_mode"
    // Issue727: 설정창 열기 단축키
    private let settingsHotkeyKey = "settings.hotkey"
    // 유산 (Issue 238)
    private let legacyStatsRetentionMonthsKey = "snippet_stats_retention_months"

    // 배열/딕셔너리 관련
    private let excludedFilesKey = "snippet_excluded_files"

    // 클립보드 히스토리 키 (YAML 매핑)
    private let historyEnabledPlainTextKey = "history.enable.plainText"
    private let historyRetentionDaysPlainTextKey = "history.retentionDays.plainText"
    private let historyEnabledImagesKey = "history.enable.images"
    private let historyRetentionDaysImagesKey = "history.retentionDays.images"
    private let historyEnabledFileListsKey = "history.enable.fileLists"
    private let historyRetentionDaysFileListsKey = "history.retentionDays.fileLists"
    private let historyViewerHotkeyKey = "history.viewer.hotkey"
    private let historyIgnoreImagesKey = "history.ignore.images"
    private let historyIgnoreFileListsKey = "history.ignore.fileLists"
    private let historyMoveDuplicatesToTopKey = "history.moveDuplicatesToTop"
    private let historyPauseHotkeyKey = "history.pause.hotkey"
    private let historyShowStatusBarKey = "history.showStatusBar"  // CL035
    private let historyForceInputSourceKey = "history.forceInputSource"  // CL038
    private let historyShowPreviewKey = "history.showPreview"  // CL042
    private let historyPreviewHotkeyKey = "history.preview.hotkey"  // CL042
    private let historyRegisterSnippetHotkeyKey = "history.registerSnippet.hotkey"  // CL042
    private let historyViewerWidthKey = "history.viewer.width"

    // Issue Fix: Rename key to avoid ambiguity
    private let historyPreviewWidthKey = "history.viewer_preview.width"
    private let legacyHistoryPreviewWidthKey = "history.preview.width"

    // 딕셔너리는 개별 키로 분해하지 않고 plist 형태로 저장
    private let folderSymbolsKey = "snippet_folder_symbols"
    private let folderPrefixesKey = "snippet_folder_prefixes"
    private let folderPrefixShortcutsKey = "snippet_folder_prefix_shortcuts"
    private let folderExcludedFilesKey = "snippet_folder_excluded_files"

    // 마이그레이션을 위한 유산 키
    private let legacyBasePathKey = "snippetBasePath"
    private let legacyDefaultSymbolKey = "snippetDefaultSymbol"
    private let legacyTriggerBiasKey = "snippetTriggerBias"
    private let legacyExcludedFilesKey = "snippetExcludedFiles"
    private let legacyPopupModifierFlagsKey = "snippetPopupModifierFlags"
    private let legacyPopupKeyCodeKey = "snippetPopupKeyCode"
    private let legacyPopupDisplayStringKey = "snippetPopupDisplayString"

    // Issue 442: 로그 스팸 방지
    private var lastLoggedAuxBias: Int?

    // Issue 474_7: 경로를 표준화하고 상대 경로로 변환하는 헬퍼
    // Issue 669: 명시적 상대 경로("./")로 저장하도록 보장
    // Issue 669_1: 하위 폴더가 아닌 경우에도 상대 경로("../") 계산 지원
    func makePathRelative(path: String, root: String) -> String {
        let pathUrl = URL(fileURLWithPath: path).standardized
        let rootUrl = URL(fileURLWithPath: root).standardized

        if pathUrl.path == rootUrl.path {
            logV("🪓 🚧 [SettingsManager] Canonical Relative Path: '\(path)' -> './'")
            return "./"
        }

        if pathUrl.path.hasPrefix(rootUrl.path + "/") {
            let relative = String(pathUrl.path.dropFirst(rootUrl.path.count + 1))
            let explicitRelative = "./\(relative)"
            logV(
                "🪓 🚧 [SettingsManager] Canonical Relative Path: '\(path)' -> '\(explicitRelative)'")
            return explicitRelative
        }

        let pathComponents = pathUrl.pathComponents
        let rootComponents = rootUrl.pathComponents

        var commonPrefixCount = 0
        for i in 0..<min(pathComponents.count, rootComponents.count) {
            if pathComponents[i] == rootComponents[i] {
                commonPrefixCount += 1
            } else {
                break
            }
        }

        if commonPrefixCount > 1 {
            let goUpCount = rootComponents.count - commonPrefixCount
            let goDownComponents = pathComponents[commonPrefixCount...]

            let ups = Array(repeating: "..", count: goUpCount).joined(separator: "/")
            let relativePath: String
            if goDownComponents.isEmpty {
                relativePath = ups
            } else {
                relativePath = ups + "/" + goDownComponents.joined(separator: "/")
            }

            logV("🪓 🚧 [SettingsManager] Canonical Relative Path: '\(path)' -> '\(relativePath)'")
            return relativePath
        }

        // 상대 경로화 할 수 없으면 원본 반환
        return path
    }

    func load() -> SnippetSettings {
        cacheLock.lock()
        if let cached = cachedSettings {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let prefs = PreferencesManager.shared
        let defaults = UserDefaults.standard  // 마이그레이션 소스

        // 기본값으로 시작
        var settings = SnippetSettings.default

        // 1. 앱 루트 경로: 환경변수 → 기본 경로 (resolveAppRootPath 사용)
        settings.appRootPath = PreferencesManager.resolveAppRootPath()

        // 2. 기본 경로
        if let path = prefs.get(basePathKey) as String? {
            settings.basePath = path
        } else if let legacyPath = defaults.string(forKey: legacyBasePathKey) {
            settings.basePath = legacyPath
            // Issue 474_7: 저장 전 가능한 경우 레거시 경로를 상대 경로로 변환
            let relativeLegacy = makePathRelative(path: legacyPath, root: settings.appRootPath)
            prefs.set(relativeLegacy, forKey: basePathKey)
        }

        // Issue 474_2, 669: 상대 경로(./) 확인 및 앱 루트 기준 해결
        if settings.basePath.hasPrefix("./")
            || (!settings.basePath.hasPrefix("/") && !settings.basePath.hasPrefix("~"))
        {
            // 앱 루트(fSnippetData) 기준 상대 경로로 가정
            let appRootUrl = URL(fileURLWithPath: settings.appRootPath)

            var strippedPath = settings.basePath
            if strippedPath.hasPrefix("./") {
                strippedPath.removeFirst(2)
            }

            settings.basePath = appRootUrl.appendingPathComponent(strippedPath).standardized.path
            //logD("🪓 🚧 [Settings] Relative Path Resolved: \(settings.basePath)")
        }

        // [Issue199] 기본 경로 물결표 확장 (샌드박스 우회)
        // settings.basePath가 ~로 시작하면 절대 경로로 변환하여 저장 (메모리 상에서만)
        if settings.basePath.hasPrefix("~") {
            let userName = NSUserName()
            settings.basePath = settings.basePath.replacingOccurrences(
                of: "~", with: "/Users/\(userName)")
        }

        // 3. 기본 경로 북마크 (Issue 194)
        if let bookmark = prefs.get(basePathBookmarkKey) as String? {
            settings.basePathBookmark = bookmark
        }

        // MARK: - Safe Path Validation
        // [Issue Fix] SettingsManager에서는 파일 존재 여부를 검사하지 않습니다.
        // 샌드박스 환경에서 북마크 해석 없이 접근하면 실패할 수 있으며,
        // 이로 인해 올바른 경로가 기본값으로 강제 리셋되는 문제가 발생합니다.
        // 검증은 SnippetFileManager에서 북마크 해결 후 수행합니다.
        /*
        let expandedPath = (settings.basePath as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expandedPath) {
            logW("🪓 🚧 ⚠️ [Settings] 저장된 Snippet 경로가 존재하지 않습니다: \(settings.basePath) (Expanded: \(expandedPath))")
            logW("🪓 🚧 ⚠️ [Settings] 기본 경로로 Fallback: \(SnippetSettings.default.basePath)")
            settings.basePath = SnippetSettings.default.basePath
            // Issue 474_7: 폴백 경로 상대화
            // Issue 474_8: 검증 실패 시 사용자 설정을 덮어쓰지 않음.
            // 앱 실행을 위해 메모리 상에서만 기본값을 사용하고, 사용자가 수정할 수 있도록 파일은 보존함.
            // prefs.set(relativeFallback, forKey: basePathKey)
             logW("🪓 🚧 🛡️ [SettingsManager] Issue474_8: 설정 파일 보호를 위해 Default Path 덮어쓰기 방지됨.")
        }
        */ //logW("🪓 🚧 🛡️ [SettingsManager] Issue474_8: 설정 파일 보호를 위해 Default Path 덮어쓰기 방지됨.")

        // 2. 기본 트리거 키
        if let symbol = prefs.get(defaultSymbolKey) as String? {
            settings.defaultSymbol = migrateLegacyKeypadName(symbol)  // Issue 419: 마이그레이션
        } else if let legacySymbol = defaults.string(forKey: legacyDefaultSymbolKey) {
            settings.defaultSymbol = migrateLegacyKeypadName(legacySymbol)  // Issue 419: 마이그레이션
            prefs.set(settings.defaultSymbol, forKey: defaultSymbolKey)
        }

        // 3. 트리거 바이어스 (Issue 수정: 누락된 설정 로드)
        if let bias = prefs.get(triggerBiasKey) as Int? {
            settings.triggerBias = bias
        } else if let legacyBias = defaults.object(forKey: legacyTriggerBiasKey) as? Int {
            settings.triggerBias = legacyBias
            prefs.set(legacyBias, forKey: triggerBiasKey)
        }

        // 4. 트리거 바이어스 Aux (Issue 436: Plist 전용)
        // 개발자 제어 항목이므로 UserDefaults만 엄격히 검증
        // 하지만 다른 설정과의 일관성을 위해 defaults를 직접 확인함.
        // 보통 _config.yml에 저장되지 않지만, 사용자가 넣으면 덮어쓸 수 있음?
        // 이 "Aux" 값에 대해서는 Plist를 주요 소스로 유지.

        // 4. 트리거 바이어스 Aux (Issue 436: AppSettingManager)
        // 진실 공급원: appSetting.json (AppSettingManager)
        // settings.triggerBiasAux = AppSettingManager.shared.tuning.triggerBiasAux // 사용 안 함

        // 5. _rule.yml 로드 (기존 로직)

        // ... existing code ...

        // Issue86: _rule.yml 로드 및 설정 반영
        // RuleManager.loadRuleFile(at:)이 내부적으로 _rule.md -> _rule.yml 순서로 확인
        if RuleManager.shared.loadRuleFile(at: settings.basePath) {
            logV("🪓 🚧 [Settings] 규칙 파일 로드 성공: 폴더 설정 동기화")
            let rules = RuleManager.shared.getAllRules()
            var newSymbols: [String: String] = [:]
            var newPrefixes: [String: String] = [:]
            var newPrefixShortcuts: [String: String] = [:]

            for rule in rules {
                // Issue 419: 레거시 NumKey -> keypad_ 마이그레이션
                let migratedSuffix = migrateLegacyKeypadName(rule.suffix)

                // Issue 406: 빈 접미사 저장 허용 (명시적 없음)
                newSymbols[rule.name] = migratedSuffix

                // 통합: 중괄호에 따라 규칙 접두사를 텍스트 또는 단축키 버킷으로 분리
                if !rule.prefix.isEmpty {
                    if rule.prefix.hasPrefix("{") && rule.prefix.hasSuffix("}") {
                        // It is a shortcut
                        newPrefixShortcuts[rule.name] = rule.prefix
                    } else {
                        // It is text
                        newPrefixes[rule.name] = rule.prefix
                    }
                }
            }
            settings.folderSymbols = newSymbols
            settings.folderPrefixes = newPrefixes
            settings.folderPrefixShortcuts = newPrefixShortcuts
        } else {
            // ...
        }

        // 최대 너비 제한 (Issue 394 최적화 - 거대 할당 방지)
        // (특정 너비 설정 선호로 제거됨)

        // MARK: - 팝업 키 로드 (Issue 429 수정)
        // 환경설정에서 팝업 키 로드
        let popupKeyStr = prefs.string(forKey: popupDisplayStringKey)
        let popupMods = prefs.get(popupModifierFlagsKey) as Int?
        let popupCode = prefs.get(popupKeyCodeKey) as Int?

        if !popupKeyStr.isEmpty {
            // 저장된 구성 요소가 있으면 재구성
            if let mods = popupMods, let code = popupCode {
                settings.popupKeyShortcut = PopupKeyShortcut(
                    modifierFlags: UInt(mods), keyCode: UInt16(code), displayString: popupKeyStr)
            } else {
                // 폴백: 구성 요소가 없으면 문자열 파싱 (레거시 또는 단순 저장)
                settings.popupKeyShortcut = PopupKeyShortcut.from(hotkeyString: popupKeyStr)
            }
        } else if let legacyDisplay = defaults.string(forKey: legacyPopupDisplayStringKey) {
            // Migration
            settings.popupKeyShortcut = PopupKeyShortcut.from(hotkeyString: legacyDisplay)

            // Save to new keys immediately
            prefs.set(Int(settings.popupKeyShortcut.modifierFlags), forKey: popupModifierFlagsKey)
            prefs.set(Int(settings.popupKeyShortcut.keyCode), forKey: popupKeyCodeKey)
            prefs.set(settings.popupKeyShortcut.displayString, forKey: popupDisplayStringKey)
        }

        // MARK: - 히스토리 설정 로드 (Issue 428 수정)
        // 1. 불리언
        settings.historyEnabledPlainText = prefs.bool(
            forKey: historyEnabledPlainTextKey, defaultValue: true)
        settings.historyEnabledImages = prefs.bool(
            forKey: historyEnabledImagesKey, defaultValue: true)
        settings.historyEnabledFileLists = prefs.bool(
            forKey: historyEnabledFileListsKey, defaultValue: true)
        settings.historyIgnoreImages = prefs.bool(
            forKey: historyIgnoreImagesKey, defaultValue: false)
        settings.historyIgnoreFileLists = prefs.bool(
            forKey: historyIgnoreFileListsKey, defaultValue: true)
        settings.historyMoveDuplicatesToTop = prefs.bool(
            forKey: historyMoveDuplicatesToTopKey, defaultValue: true)
        settings.historyShowStatusBar = prefs.bool(
            forKey: historyShowStatusBarKey, defaultValue: true)
        settings.historyShowPreview = prefs.bool(forKey: historyShowPreviewKey, defaultValue: true)

        // 2. 정수
        settings.historyRetentionDaysPlainText = prefs.get(historyRetentionDaysPlainTextKey) ?? 90

        // MARK: - Popup Settings Load (Issue Fix: Missing Keys)
        if let rows = prefs.get(popupRowsKey) as Int? {
            settings.popupRows = rows
        }

        if let scopeRaw = prefs.get(popupSearchScopeKey) as String?,
            let scope = PopupSearchScope(rawValue: scopeRaw)
        {
            settings.popupSearchScope = scope
        }

        if let modFlags = prefs.get(popupQuickSelectModifierFlagsKey) as Int? {
            // Issue742: Option 키는 더 이상 지원하지 않음 → Command로 fallback
            let optionRaw = Int(NSEvent.ModifierFlags.option.rawValue)
            if modFlags == optionRaw {
                settings.popupQuickSelectModifierFlags = Int(NSEvent.ModifierFlags.command.rawValue)
            } else {
                settings.popupQuickSelectModifierFlags = modFlags
            }
        }
        settings.historyRetentionDaysImages = prefs.get(historyRetentionDaysImagesKey) ?? 7
        settings.historyRetentionDaysFileLists = prefs.get(historyRetentionDaysFileListsKey) ?? 30

        // 3. 너비
        if let vWidth = prefs.get(historyViewerWidthKey) as Double? {
            settings.historyViewerWidth = CGFloat(vWidth)
        }

        // Issue Fix: Migrate 'history.preview.width' -> 'history.viewer_preview.width'
        if let pWidth = prefs.get(historyPreviewWidthKey) as Double? {
            // New key exists, use it
            settings.historyPreviewWidth = CGFloat(pWidth)
        } else if let legacyPWidth = prefs.get(legacyHistoryPreviewWidthKey) as Double? {
            // New key missing, try legacy key
            settings.historyPreviewWidth = CGFloat(legacyPWidth)

            // Migrate immediately
            logI("🪓 [Settings] Migrating 'history.preview.width' -> 'history.viewer_preview.width'")
            prefs.set(legacyPWidth, forKey: historyPreviewWidthKey)
            prefs.set(nil, forKey: legacyHistoryPreviewWidthKey)  // Remove old key
        }

        // Issue 595: Load Popup Preview Width
        if let ppWidth = prefs.get(popupPreviewWidthKey) as Double? {
            settings.popupPreviewWidth = CGFloat(ppWidth)
        }

        // Issue 649: Load last selected folder
        if let lastFolder = prefs.string(forKey: lastSelectedFolderKey) as String?,
            !lastFolder.isEmpty
        {
            settings.lastSelectedFolder = lastFolder
        }

        // Issue 684: Alfred Import 규칙 파일 로드
        if let importPath = prefs.get(alfredImportRulePathKey) as String? {
            settings.alfredImportRulePath = importPath

            // 상대 경로 해결
            if importPath.hasPrefix("./")
                || (!importPath.hasPrefix("/") && !importPath.hasPrefix("~"))
            {
                let appRootUrl = URL(fileURLWithPath: settings.appRootPath)
                var stripped = importPath
                if stripped.hasPrefix("./") { stripped.removeFirst(2) }
                settings.alfredImportRulePath =
                    appRootUrl.appendingPathComponent(stripped).standardized.path
            }
        }

        if let importBookmark = prefs.get(alfredImportRulePathBookmarkKey) as String? {
            settings.alfredImportRulePathBookmark = importBookmark
        }

        // 4. 단축키
        // Issue727: 설정창 단축키
        let settingsKey = prefs.string(forKey: settingsHotkeyKey)
        if !settingsKey.isEmpty {
            settings.settingsHotkey = PopupKeyShortcut.from(hotkeyString: settingsKey)
        }

        let viewerKey = prefs.string(forKey: historyViewerHotkeyKey)
        if !viewerKey.isEmpty {
            settings.historyViewerHotkey = PopupKeyShortcut.from(hotkeyString: viewerKey)
        }

        let pauseKey = prefs.string(forKey: historyPauseHotkeyKey)
        if !pauseKey.isEmpty {
            settings.historyPauseHotkey = PopupKeyShortcut.from(hotkeyString: pauseKey)
        }

        let previewKey = prefs.string(forKey: historyPreviewHotkeyKey)
        if !previewKey.isEmpty {
            settings.historyPreviewHotkey = PopupKeyShortcut.from(hotkeyString: previewKey)
        }

        let regKey = prefs.string(forKey: historyRegisterSnippetHotkeyKey)
        if !regKey.isEmpty {
            settings.historyRegisterSnippetHotkey = PopupKeyShortcut.from(hotkeyString: regKey)
        }

        // CL038: 입력 소스
        let inputSource = prefs.string(forKey: historyForceInputSourceKey)
        if !inputSource.isEmpty {
            settings.historyForceInputSource = inputSource
        }

        // Issue 386: Appearance Mode (누락된 로직 복구)
        // 기본값은 "system" (SnippetSettings.default에서 설정됨)
        if let mode = prefs.get(appearanceModeKey) as String? {
            settings.appearanceMode = mode
        }

        // logI("🪓 [SettingsManager.load] Final Settings Loaded - Root: \(settings.appRootPath), Base: \(settings.basePath), Theme: \(settings.appearanceMode)")

        cacheLock.lock()
        cachedSettings = settings
        cacheLock.unlock()

        return settings
    }

    // Issue 419: 키 이름 마이그레이션 헬퍼
    private func migrateLegacyKeypadName(_ name: String) -> String {
        let migrationMap: [String: String] = [
            "NumKey0": "keypad_0", "NumKey1": "keypad_1", "NumKey2": "keypad_2",
            "NumKey3": "keypad_3", "NumKey4": "keypad_4", "NumKey5": "keypad_5",
            "NumKey6": "keypad_6", "NumKey7": "keypad_7", "NumKey8": "keypad_8",
            "NumKey9": "keypad_9", "NumKey.": "keypad_period", "NumKey*": "keypad_multiply",
            "NumKey+": "keypad_plus", "NumKey-": "keypad_minus", "NumKey/": "keypad_divide",
            "NumKey=": "keypad_equals", "NumKey,": "keypad_comma", "NumEnter": "keypad_enter",
            "NumClear": "keypad_num_lock", "NumLock": "keypad_num_lock",
        ]
        return migrationMap[name] ?? name
    }

    // Issue 583_1: Serial Queue for async saving
    private let saveQueue = DispatchQueue(label: "com.nowage.fSnippet.SettingsManager.saveQueue")

    func save(_ settings: SnippetSettings) {
        // Issue 583_1: Perform save asynchronously on a serial queue to avoid blocking Main Thread
        saveQueue.async { [weak self] in
            guard let self = self else { return }

            let prefs = PreferencesManager.shared

            // Issue 474_7: AppRoot 내부인 경우 상대 경로로 변환 (견고성)
            let basePathToSave = self.makePathRelative(
                path: settings.basePath, root: settings.appRootPath)

            // Batch Update 적용 (Issue: 설정 저장 최적화)
            prefs.batchUpdate { config in
                // 기본 설정
                config[self.basePathKey] = basePathToSave
                config[self.basePathBookmarkKey] = settings.basePathBookmark
                config[self.defaultSymbolKey] = settings.defaultSymbol
                config[self.triggerBiasKey] = settings.triggerBias
                config[self.popupSearchScopeKey] = settings.popupSearchScope.rawValue
                config[self.popupRowsKey] = settings.popupRows
                config[self.excludedFilesKey] = settings.excludedFiles

                // 팝업 키
                config[self.popupModifierFlagsKey] = Int(settings.popupKeyShortcut.modifierFlags)
                config[self.popupKeyCodeKey] = Int(settings.popupKeyShortcut.keyCode)
                config[self.popupDisplayStringKey] = settings.popupKeyShortcut.displayString
                config[self.popupQuickSelectModifierFlagsKey] =
                    settings.popupQuickSelectModifierFlags

                // Issue 376, 386
                config[self.statsRetentionUsageDaysKey] = settings.statsRetentionUsageDays
                config[self.appearanceModeKey] = settings.appearanceMode

                // History Settings
                config[self.historyEnabledPlainTextKey] = settings.historyEnabledPlainText
                config[self.historyRetentionDaysPlainTextKey] =
                    settings.historyRetentionDaysPlainText
                config[self.historyEnabledImagesKey] = settings.historyEnabledImages
                config[self.historyRetentionDaysImagesKey] = settings.historyRetentionDaysImages
                config[self.historyEnabledFileListsKey] = settings.historyEnabledFileLists
                config[self.historyRetentionDaysFileListsKey] =
                    settings.historyRetentionDaysFileLists
                config[self.historyIgnoreImagesKey] = settings.historyIgnoreImages
                config[self.historyIgnoreFileListsKey] = settings.historyIgnoreFileLists
                config[self.historyMoveDuplicatesToTopKey] = settings.historyMoveDuplicatesToTop
                config[self.historyShowStatusBarKey] = settings.historyShowStatusBar
                config[self.historyForceInputSourceKey] = settings.historyForceInputSource
                config[self.historyShowPreviewKey] = settings.historyShowPreview

                // Hotkeys
                config[self.settingsHotkeyKey] = settings.settingsHotkey.toHotkeyString  // Issue727
                config[self.historyViewerHotkeyKey] = settings.historyViewerHotkey.toHotkeyString
                config[self.historyPauseHotkeyKey] = settings.historyPauseHotkey.toHotkeyString
                config[self.historyPreviewHotkeyKey] = settings.historyPreviewHotkey.toHotkeyString
                config[self.historyRegisterSnippetHotkeyKey] =
                    settings.historyRegisterSnippetHotkey.toHotkeyString

                // Dimensions
                config[self.historyViewerWidthKey] = settings.historyViewerWidth
                config[self.historyPreviewWidthKey] = settings.historyPreviewWidth
                config[self.popupPreviewWidthKey] = settings.popupPreviewWidth
                config[self.lastSelectedFolderKey] = settings.lastSelectedFolder

                // Issue 684: Alfred Import 규칙 파일 저장
                if let importPath = settings.alfredImportRulePath {
                    config[self.alfredImportRulePathKey] = self.makePathRelative(
                        path: importPath, root: settings.appRootPath)
                } else {
                    config[self.alfredImportRulePathKey] = nil
                }
                config[self.alfredImportRulePathBookmarkKey] = settings.alfredImportRulePathBookmark

                // Dictionary
                config[self.folderExcludedFilesKey] = settings.folderExcludedFiles
            }

            logI("🪓 🚧 [SettingsManager] 모든 설정 항목(히스토리 포함) Batch Save 완료")

            // Issue 621_1: 설정 저장 시 캐시 업데이트 보장 (Notification이 늦을 경우 대비)
            self.invalidateCache()

            // Issue86: _rule.yml 업데이트
            // 경로 없이 호출하면 현재 로드된 (_rule.md 또는 _rule.yml) 파일에 저장됨

            // 기존 룰 조회
            let currentRules = RuleManager.shared.getAllRulesDict()

            // UI 설정 기반으로 CollectionRule 목록 생성
            var newCollections: [RuleManager.CollectionRule] = []
            // Issue 606: Safety - Include existing rules to prevent accidental deletion
            let allFolderNames = Set(settings.folderSymbols.keys)
                .union(settings.folderPrefixes.keys)
                .union(settings.folderPrefixShortcuts.keys)
                .union(currentRules.keys)

            for name in allFolderNames {
                // Issue317: 주석 보존
                let existingRule = currentRules[name]

                // Regression Fix (Issue 606): Fallback to existing rule values if not present in settings
                // This prevents overwriting existing rules with empty values when they are not in UserDefaults.
                let prefix = settings.folderPrefixes[name] ?? existingRule?.prefix ?? ""
                let suffix = settings.folderSymbols[name] ?? existingRule?.suffix ?? ""

                // Bias and Description are optional in CollectionRule
                let bias = currentRules[name]?.triggerBias
                let description = currentRules[name]?.description

                let prefixComment = existingRule?.prefixComment
                let suffixComment = existingRule?.suffixComment
                let triggerBiasComment = existingRule?.triggerBiasComment
                let descriptionComment = existingRule?.descriptionComment

                // ✅ Issue Fix: 빈 규칙(이름만 있음) 저장 방지
                // 모든 필드가 비어있거나/nil이거나/기본값이면, 이 규칙을 건너뜀.
                let isSuffixEmpty = suffix.isEmpty || suffix == settings.defaultSymbol
                let isPrefixEmpty = prefix.isEmpty
                let isDescriptionEmpty = description == nil || description!.isEmpty
                let isTriggerBiasEmpty = bias == nil

                if isSuffixEmpty && isPrefixEmpty && isDescriptionEmpty && isTriggerBiasEmpty {
                    continue
                }

                newCollections.append(
                    RuleManager.CollectionRule(
                        name: name,
                        suffix: suffix,
                        prefix: prefix,
                        description: description,
                        triggerBias: bias,
                        // 주석 전달
                        prefixComment: prefixComment,
                        suffixComment: suffixComment,
                        triggerBiasComment: triggerBiasComment,
                        descriptionComment: descriptionComment
                    )
                )
            }

            // Issue 606: Check if rules actually changed
            var areRulesChanged = false
            if currentRules.count != newCollections.count {
                areRulesChanged = true
            } else {
                for newRule in newCollections {
                    if let oldRule = currentRules[newRule.name], oldRule == newRule {
                        continue
                    }
                    areRulesChanged = true
                    break
                }
            }

            if !areRulesChanged {
                logD("🪓    [SettingsManager] _rule.yml 변경 사항 없음 - 저장 건너뜀 (Timestamp 보존)")
            } else {
                // 규칙 파일 저장 (경로 nil = 자동 감지된 경로 사용)
                if RuleManager.shared.saveRules(to: nil, newCollections: newCollections) {
                    logV("🪓 🚧 [Settings] 전체 규칙 저장 및 파일 업데이트 완료")

                    // Issue 315: Trigger Bias 등의 설정 변경 시 KeyEventMonitor가 즉시 재시작되도록 강제 알림
                    // PreferencesManager.set()이 값이 같으면 알림을 스킵할 수 있으므로, 여기서 명시적으로 전송
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .settingsDidChange, object: settings)
                        logV("🪓 🚧 [Settings] .settingsDidChange 알림 강제 전송 완료")
                    }
                } else {
                    logE("🪓 🚧 ❌ [Settings] 규칙 파일 업데이트 실패")
                }
            }
        }
    }

    /// 단일 규칙 업데이트 (Issue112: 이름 변경 지원 포함)
    func updateRule(_ rule: RuleManager.CollectionRule, oldName: String? = nil) {
        // 1. 현재 설정 로드
        var settings = load()
        var currentRules = RuleManager.shared.getAllRulesDict()

        let targetName = rule.name

        // 2. 이름 변경 처리
        if let oldName = oldName, oldName != rule.name {
            logV("🪓 🚧 [Settings] 규칙 이름 변경 시도: \(oldName) -> \(rule.name)")

            // 물리적 폴더 이름 변경
            if SnippetFileManager.shared.renameFolder(oldName: oldName, newName: rule.name) {
                // 성공 시 기존 설정 제거
                settings.folderSymbols.removeValue(forKey: oldName)
                settings.folderPrefixes.removeValue(forKey: oldName)
                currentRules.removeValue(forKey: oldName)
            } else {
                // 실패 시 원래 이름 유지 (변경 취소)
                logE("🪓 🚧 ⚠️ 물리적 폴더 변경 실패로 인해 규칙 이름 변경을 취소합니다.")
                return  // 또는 에러 처리
            }
        }

        // 3. UI 설정 동기화
        settings.folderSymbols[targetName] = rule.suffix
        settings.folderPrefixes[targetName] = rule.prefix
        // settings.folderPrefixShortcuts.removeValue(forKey: targetName) // Removed property

        // 4. 전체 규칙 저장 및 파일 업데이트
        currentRules[targetName] = rule

        logD("🪓 🚧 [SettingsManager.updateRule] Updating Rule: '\(targetName)'")
        logD("🪓     - Prefix: '\(rule.prefix)', Suffix: '\(rule.suffix)'")
        logD("🪓     - (PrefixShortcut/SuffixShortcut fields removed from CollectionRule)")

        let newCollections = Array(currentRules.values)

        // 경로 nil = 자동 감지된 경로 사용
        if RuleManager.shared.saveRules(to: nil, newCollections: newCollections) {
            logV("🪓 🚧 [Settings] 단일 규칙 업데이트 완료: \(targetName)")
            // UserDefaults 저장 (동기화)
            save(settings)
        } else {
            logE("🪓 🚧 ❌ [Settings] 단일 규칙 업데이트 실패: \(targetName)")
        }
    }

    /// 폴더 삭제 (Issue197: 폴더 및 모든 규칙/설정 삭제)
    func deleteFolder(_ folderName: String) {
        logV("🪓 🚧 [Settings] 폴더 삭제 요청: \(folderName)")

        // 1. 물리적 폴더 삭제
        if SnippetFileManager.shared.deleteFolder(folderName: folderName) {
            // 2. 설정 정리
            var settings = load()
            var currentRules = RuleManager.shared.getAllRulesDict()

            settings.folderSymbols.removeValue(forKey: folderName)
            settings.folderPrefixes.removeValue(forKey: folderName)
            settings.folderPrefixShortcuts.removeValue(forKey: folderName)
            currentRules.removeValue(forKey: folderName)

            // 3. 규칙 파일 저장
            let newCollections = Array(currentRules.values)
            if RuleManager.shared.saveRules(to: nil, newCollections: newCollections) {
                logV("🪓 🚧 [Settings] 규칙 파일 업데이트 완료 (삭제 반영)")
            }

            // 4. UserDefaults 저장
            save(settings)

            logV("🪓 🚧 [Settings] 폴더 삭제 및 설정 정리 완료: \(folderName)")
        } else {
            logE("🪓 🚧 ❌ [Settings] 폴더 삭제 실패: \(folderName)")
        }
    }

    /// 폴더 생성 (Issue199: 폴더 생성 및 설정 추가)
    func createFolder(folderName: String, prefix: String, suffix: String) -> Bool {
        logV("🪓 🚧 file_folder [Settings] 폴더 생성 요청: \(folderName)")

        // 1. 물리적 폴더 생성
        if SnippetFileManager.shared.createFolder(folderName: folderName) {
            // 2. 설정 추가
            var settings = load()
            var currentRules = RuleManager.shared.getAllRulesDict()

            settings.folderSymbols[folderName] = suffix
            if !prefix.isEmpty {
                settings.folderPrefixes[folderName] = prefix
            }

            // 3. 규칙 파일 생성/업데이트
            // 새로운 CollectionRule 생성
            // Issue 316: Updated CollectionRule init (comments fields added, shortcuts removed)
            let newRule = RuleManager.CollectionRule(
                name: folderName, suffix: suffix, prefix: prefix, description: nil,
                triggerBias: nil, prefixComment: nil, suffixComment: nil, triggerBiasComment: nil,
                descriptionComment: nil)
            currentRules[folderName] = newRule

            let newCollections = Array(currentRules.values)
            if RuleManager.shared.saveRules(to: nil, newCollections: newCollections) {
                logV("🪓 🚧 [Settings] 규칙 파일 업데이트 완료 (생성 반영)")
            }

            // 4. UserDefaults 저장
            save(settings)

            logV("🪓 🚧 [Settings] 폴더 생성 및 설정 완료: \(folderName)")
            return true
        } else {
            logE("🪓 🚧 ❌ [Settings] 폴더 생성 실패: \(folderName)")
            return false
        }
    }

    /// 기존 바이너리 인코딩된 설정들을 제거하는 마이그레이션
    func cleanupLegacySettings() {
        let defaults = UserDefaults.standard
        let legacyKeys = [
            "snippetSettings",  // 기존 JSON 통합 설정
            "snippetPopupKeyShortcut",  // 기존 JSON 팝업 키 설정
            "ActiveTriggerKeys",  // TriggerKeyManager에서 사용하는 바이너리 키
            "snippetTriggerKey",  // deprecated된 triggerKey 필드
            "snippet_popup_display_string",  // Issue 258 Legacy
            "snippet_default_symbol",  // Issue 290 Migrated
            "DefaultTriggerKey",
            "LogLevel",
            "autoStart",
            "debugLogging",
            "hideFromMenuBar",
            "logLevel",
            "performanceMonitoring",
            "showNotifications",
            "snippetBasePath",
            "snippetDefaultSymbol",
            "snippetExcludedFiles",
            "snippetFolderExcludedFiles",
            "snippetFolderPrefixes",
            "snippetFolderSymbols",
            "snippetPopupDisplayString",
            "snippetPopupKeyCode",
            "snippetPopupModifierFlags",
            "snippetRootFolder",
            "snippetTriggerBias",
            "snippet_popup_preview_width",
            "snippet_trigger_bias",
            "snippet_trigger_bias_aux",
            "snippet_trigger_bias_aux_v2",
            "triggerBias",
        ]

        var removedKeys: [String] = []
        for key in legacyKeys {
            if defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                removedKeys.append(key)
            }
        }

        if !removedKeys.isEmpty {
            defaults.synchronize()
            logV("🪓 🚧 [SettingsManager.cleanup] 레거시 바이너리 설정 정리 완료: \(removedKeys)")
        }
    }

    // Issue: Real-time save for history widths
    func saveHistoryWidths(viewerWidth: Double, previewWidth: Double) {
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            let prefs = PreferencesManager.shared

            prefs.batchUpdate { config in
                config[self.historyViewerWidthKey] = viewerWidth
                config[self.historyPreviewWidthKey] = previewWidth
            }
            // logV("🪓 [SettingsManager] History widths saved: viewer=\(viewerWidth), preview=\(previewWidth)")
        }
    }
}
