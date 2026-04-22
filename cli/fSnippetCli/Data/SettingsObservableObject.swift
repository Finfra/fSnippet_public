import Cocoa
import Combine
import Foundation
import SwiftUI

/// SwiftUI와 호환되는 Observable Settings 객체
class SettingsObservableObject: ObservableObject {
    static let shared = SettingsObservableObject()
    @Published var settings: SnippetSettings {
        didSet {
            logV("📡 Settings didSet!")

            // 저장 프로세스에 의한 변경이면 무시 (Loop 방지)
            if isSaving { return }

            if !isInitializing {
                // Issue: saveUISettings() only saves UI prefs, but history widths are in SnippetSettings.
                // Use debouncedSave() to save both and handle slider dragging.
                debouncedSave()
            }
        }
    }

    // Auto-Save 관련 (Issue 108)
    private var saveWorkItem: DispatchWorkItem?

    // 초기화 중인지 여부 (Issue: Circular Dependency 방지)
    private var isInitializing = true

    // 저장 중인지 여부 (Issue: Infinite Loop 방지)
    private var isSaving = false
    // 추가 UI 전용 설정들
    // Issue47 (2026-04-19): SMAppService 경로 obsolete — brew services 배타 원칙 준수.
    // prefs/API backward compat 용으로 값 자체는 저장/반환되나, 실제 Login Item 등록은 하지 않음.
    @Published var autoStart: Bool = false
    @Published var hideFromMenuBar: Bool = false
    @Published var showInAppSwitcher: Bool = false {
        didSet {
            if !isInitializing {
                NSApp.setActivationPolicy(showInAppSwitcher ? .regular : .accessory)

                // 앱 전환기 정책 변경 시 포커스(Key Window)를 잃는 현상 방지
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.isVisible }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }
    @Published var showNotifications: Bool = true
    @Published var playReadySound: Bool = false
    @Published var debugLogging: Bool = false {
        didSet {
            if !isInitializing {
                // [Issue225] Logger Master Switch 동기화
                Logger.shared.isFileLoggingEnabled = debugLogging
            }
        }
    }
    @Published var performanceMonitoring: Bool = false {
        didSet {
            if !isInitializing {
                PerformanceLogger.shared.setEnabled(performanceMonitoring)
            }
        }
    }
    @Published var loadedSnippetCount: Int = 0

    // MARK: - Issue 741: REST API 설정
    @Published var apiEnabled: Bool = false {
        didSet {
            if !isInitializing {
                saveUISettings()
                if apiEnabled {
                    APIServer.shared.start(forceEnabled: true)
                } else {
                    APIServer.shared.stop()
                }
            }
        }
    }
    @Published var apiPort: Int = 3015
    @Published var apiAllowExternal: Bool = false
    @Published var apiAllowedCIDR: String = "127.0.0.1/32"

    // MARK: - Issue 61: launchAtLogin ↔ brew services plist 연동
    @Published var launchAtLogin: Bool = false

    // MARK: - Issue 359: 언어 설정
    @Published var language: String = "system" {
        didSet {
            if !isInitializing {
                saveUISettings()
                logI("📡 [Settings] Language changed to: \(language) -> Save complete")
            }
        }
    }

    // MARK: - Issue 386: 외관 모드
    @Published var appearanceMode: String = "system" {
        didSet {
            if !isInitializing {
                saveUISettings()
                AppAppearance.shared.apply(appearanceMode)
                logI("📡 [Settings] Appearance changed to: \(appearanceMode) -> Save complete")
            }
        }
    }

    // MARK: - Issue727: 설정창 열기 단축키
    @Published var settingsHotkey: PopupKeyShortcut = PopupKeyShortcut.from(
        hotkeyString: "^⇧⌘;")
    {
        didSet {
            if !isInitializing {
                saveUISettings()
            }
        }
    }

    // MARK: - Issue 178: 팝업 설정

    @Published var popupSearchScope: PopupSearchScope = .abbreviation {
        didSet {
            if !isInitializing {
                saveUISettings()
                logV("📡 [PopupSettings] 검색 범위 변경됨: \(popupSearchScope) -> 저장 완료")
                NotificationCenter.default.post(
                    name: .popupSearchScopeDidChange, object: popupSearchScope)
            }
        }
    }

    // MARK: - Issue 277: 트리거 키 (단일 슬롯)
    @Published var triggerKeyShortcut: PopupKeyShortcut = PopupKeyShortcut(
        modifierFlags: 0, keyCode: 0, displayString: "")
    {
        didSet {
            if !isInitializing {
                saveUISettings()
                logV("📡 [TriggerSettings] 트리거키 변경됨: \(triggerKeyShortcut.displayString) -> 저장 완료")
            }
        }
    }

    @Published var popupRows: Int = 10 {
        didSet {
            logI("📡 [Settings] popupRows changed: \(oldValue) -> \(popupRows)")
            if !isInitializing {
                saveUISettings()
                logV("📡 [PopupSettings] 행 수 변경됨: \(popupRows) -> 저장 완료")
                logI("📡 [Settings] popupRowsDidChange 알림 전송: \(popupRows)")
                NotificationCenter.default.post(name: .popupRowsDidChange, object: popupRows)
            }
        }
    }

    @Published var popupHeight: CGFloat = 300.0  // 기본값 (legacy)
    @Published var popupWidth: CGFloat = 350.0 {  // Issue355: 구성 가능한 너비 (기본값 350.0)
        didSet {
            if !isInitializing {
                NotificationCenter.default.post(name: .popupWidthDidChange, object: popupWidth)
            }
        }
    }

    // Issue 595: 팝업 미리보기 너비 추가
    @Published var popupPreviewWidth: CGFloat = 400.0 {
        didSet {
            if !isInitializing {
                saveUISettings()
                logV("📡 [PopupSettings] 미리보기 너비 변경됨: \(popupPreviewWidth) -> 저장 완료")
                NotificationCenter.default.post(
                    name: .popupPreviewWidthDidChange, object: popupPreviewWidth)
            }
        }
    }

    // Issue24: 설정 GUI(드래프트 모드) 제거에 따라 단순화 — 항상 현재값 반환
    var effectivePopupWidth: CGFloat { popupWidth }
    var effectivePopupPreviewWidth: CGFloat { popupPreviewWidth }

    // Issue 230: 빠른 선택 수정자
    @Published var popupQuickSelectModifierFlags: Int = Int(NSEvent.ModifierFlags.command.rawValue)
    {
        didSet {
            if !isInitializing {
                saveUISettings()
                logV(
                    "📡 [PopupSettings] Quick Select Modifier 변경됨: \(popupQuickSelectModifierFlags) -> 저장 완료"
                )
            }
        }
    }

    // Issue 376
    @Published var statsRetentionUsageDays: Int = 30 {
        didSet {
            if !isInitializing {
                saveUISettings()
                logV("📡 [StatsSettings] 저장 기간 변경됨: \(statsRetentionUsageDays)일(사용일) -> 저장 완료")
            }
        }
    }

    // MARK: - 클립보드 히스토리 설정 (통합됨)
    @Published var historyEnabledPlainText: Bool = true { didSet { syncHistorySetting() } }
    @Published var historyRetentionDaysPlainText: Int = 90 { didSet { syncHistorySetting() } }
    @Published var historyEnabledImages: Bool = true { didSet { syncHistorySetting() } }
    @Published var historyRetentionDaysImages: Int = 7 { didSet { syncHistorySetting() } }
    @Published var historyEnabledFileLists: Bool = true { didSet { syncHistorySetting() } }
    @Published var historyRetentionDaysFileLists: Int = 30 { didSet { syncHistorySetting() } }
    @Published var historyIgnoreImages: Bool = false { didSet { syncHistorySetting() } }
    @Published var historyIgnoreFileLists: Bool = true { didSet { syncHistorySetting() } }
    @Published var historyMoveDuplicatesToTop: Bool = true { didSet { syncHistorySetting() } }
    @Published var historyViewerHotkey: PopupKeyShortcut = PopupKeyShortcut.from(
        hotkeyString: "^⌥⌘;")
    { didSet { syncHistorySetting() } }
    @Published var historyPauseHotkey: PopupKeyShortcut = PopupKeyShortcut.from(
        hotkeyString: "^⌥⌘P")
    { didSet { syncHistorySetting() } }
    @Published var historyShowStatusBar: Bool = true { didSet { syncHistorySetting() } }  // CL035
    @Published var historyForceInputSource: String = "keep" { didSet { syncHistorySetting() } }  // CL038
    @Published var historyShowPreview: Bool = true { didSet { syncHistorySetting() } }  // CL042
    @Published var historyPreviewHotkey: PopupKeyShortcut = PopupKeyShortcut.from(hotkeyString: "")
    { didSet { syncHistorySetting() } }  // CL042
    @Published var historyRegisterSnippetHotkey: PopupKeyShortcut = PopupKeyShortcut.from(
        hotkeyString: "⌘S")
    { didSet { syncHistorySetting() } }  // CL042
    @Published var historyImageDetailIsFloating: Bool = false { didSet { syncHistorySetting() } }  // CL067
    // CL076
    @Published var historyViewerWidth: CGFloat = 350.0 { didSet { saveHistoryWidths() } }
    @Published var historyPreviewWidth: CGFloat = 400.0 { didSet { saveHistoryWidths() } }

    private func saveHistoryWidths() {
        // 1. 메모리 상의 설정 동기화
        if settings.historyViewerWidth != historyViewerWidth {
            settings.historyViewerWidth = historyViewerWidth
        }
        if settings.historyPreviewWidth != historyPreviewWidth {
            settings.historyPreviewWidth = historyPreviewWidth
        }

        // 2. 파일에 즉시 부분 저장 (드래프트 모드 무시)
        // 사용자가 슬라이더 조작 시 실시간으로 반영되기를 원함.
        settingsManager.saveHistoryWidths(
            viewerWidth: Double(historyViewerWidth),
            previewWidth: Double(historyPreviewWidth)
        )
    }

    // Issue 425: 스니펫 목록 너비 (UI 전용)
    @Published var snippetListNameWidth: CGFloat = 150.0 {
        didSet {
            if !isInitializing {
                saveUISettings()
            }
        }
    }
    @Published var snippetListAbbrWidth: CGFloat = 120.0 {
        didSet {
            if !isInitializing {
                saveUISettings()
            }
        }
    }

    private func syncHistorySetting() {
        if !isInitializing {
            debouncedSave()
        }
    }

    @Published var logLevel: LogLevel = .info

    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.settings = settingsManager.load()
        loadUISettings()
        loadLogLevel()
        updateSnippetCount()

        // 설정 변경 감지
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .sink { [weak self] _ in
                self?.updateSnippetCount()
            }
            .store(in: &cancellables)

        // 초기화 완료
        isInitializing = false
    }

    // MARK: - 공개 메서드

    /// 앱 시작 시 초기 설정 적용 (Circular Dependency 방지용)
    func applyInitialSettings() {
        logV("📡 [SettingsObservableObject] 초기 설정 적용 시작")

        // 0. Appearance Mode 적용 (Issue 386)
        AppAppearance.shared.apply(appearanceMode)

        // 1. AutoStart: Issue47 (2026-04-19) — SMAppService 경로 obsolete.
        //    자동 기동은 `brew services start fsnippet-cli` 사용.

        // 2. Logger 설정 적용
        PerformanceLogger.shared.setEnabled(performanceMonitoring)
        // [Issue225] Logger Master Switch 초기화
        Logger.shared.isFileLoggingEnabled = debugLogging

        // 3. 앱 전환기 표시 옵션 적용
        NSApp.setActivationPolicy(showInAppSwitcher ? .regular : .accessory)

        // 4. Language 설정 적용 (Issue14)
        applyLanguageSetting()

        logV("📡 [SettingsObservableObject] 초기 설정 적용 완료")
    }

    /// 언어 설정을 AppleLanguages에 적용 (Issue14)
    private func applyLanguageSetting() {
        let normalizedLang = Self.normalizeLanguageCode(language)
        let defaults = UserDefaults.standard
        if normalizedLang == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([normalizedLang], forKey: "AppleLanguages")
        }
        defaults.synchronize()
        logI("📡 [Settings] Language applied at startup: \(language) -> \(normalizedLang)")
    }

    /// 국가 코드 등 잘못된 언어 코드를 Apple 표준(ISO 639-1)으로 정규화 (Issue14)
    static func normalizeLanguageCode(_ code: String) -> String {
        // 흔한 오류: 국가 코드(ISO 3166-1)를 언어 코드로 사용
        let countryToLanguage: [String: String] = [
            "kr": "ko",  // 하위 호환: 구형 config의 "kr" 값 → "ko" 자동 변환
            "jp": "ja",  // 일본(JP) → 일본어(ja)
            "cn": "zh-Hans",  // 중국(CN) → 중국어 간체
            "tw": "zh-Hant",  // 대만(TW) → 중국어 번체
            "us": "en",  // 미국(US) → 영어
            "gb": "en",  // 영국(GB) → 영어
            "br": "pt",  // 브라질(BR) → 포르투갈어
        ]
        let lowered = code.lowercased()
        return countryToLanguage[lowered] ?? code
    }

    func saveSettings() {
        settingsManager.save(settings)
        saveUISettings()
    }

    // MARK: - 자동 저장 메서드 (Issue 108)

    /// 변경사항을 Debounce하여 자동 저장
    /// 변경사항을 Debounce하여 자동 저장 (delay: 0이면 즉시 저장)
    func debouncedSave(delay: TimeInterval = 0.5) {
        // 기존 작업 취소 (드래그 중에는 계속 취소됨)
        saveWorkItem?.cancel()

        // 새 작업 생성
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            logV("📡 [AutoSave] 변경사항 자동 저장 실행 (delay: \(delay))")

            // ✅ Issue140: UI 설정도 함께 저장
            self.saveUISettings()
            self.settingsManager.saveAndUpdate(self.settings)

            // ✅ Issue140: 로그 레벨 변경 시 Logger에 즉시 반영
            Logger.shared.currentLogLevel = self.logLevel

            logV("📡 [AutoSave] 저장 완료 (UI 설정 포함)")
        }

        saveWorkItem = workItem
        if delay == 0 {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    // MARK: - Issue 387: 초기화 메서드

    /// 스니펫 데이터만 초기화 (설정은 유지) - Issue 387
    func resetSnippetsDataOnly() {
        logI("📡 [Reset] 스니펫 데이터만 초기화 실행")

        // 저장 중 플래그를 설정하여 didSet에 의한 재부팅 방지
        isSaving = true
        defer { isSaving = false }

        let fileManager = FileManager.default
        let snippetsPath = SnippetFileManager.shared.rootFolderURL.path

        do {
            // 스니펫 폴더 내 모든 파일 삭제
            if fileManager.fileExists(atPath: snippetsPath) {
                let fileURLs = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: snippetsPath), includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                logI("📡 [Reset] 스니펫 폴더 내용 삭제 완료")
            }

            // Issue 690: 초기화 후 번들의 기본 설정 파일들(_rule.yml, _rule_for_import.yml) 복원
            restoreDefaultConfigFiles(to: snippetsPath)

            // 인덱스 및 메모리 내 스니펫 초기화
            SnippetFileManager.shared.clearAllSnippets()
            SnippetIndexManager.shared.clearIndex()

            // 규칙 데이터 및 관련 환경설정 초기화 (버그 수정: 잔여 규칙이 저장되는 문제 방지)
            RuleManager.shared.clearRules()
            settings.folderSymbols.removeAll()
            settings.folderPrefixes.removeAll()
            settings.folderPrefixShortcuts.removeAll()
            settings.folderExcludedFiles.removeAll()

            // Issue759: 스니펫 재로드 (내부에서 규칙 재로드 + 인덱스 리빌드 자동 수행)
            SnippetFileManager.shared.loadAllSnippets(reason: "Reset")

            // 카운트 업데이트
            updateSnippetCount()

            logI("📡 [Reset] 스니펫 데이터 초기화 완료")
        } catch {
            logE("📡 ❌ [Reset] 스니펫 데이터 초기화 실패: \(error)")
        }
    }

    /// 번들의 기본 설정 파일들을 스니펫 폴더로 복사 (Issue 690)
    private func restoreDefaultConfigFiles(to destinationPath: String) {
        let fileManager = FileManager.default
        let configFiles = ["_rule.yml", "_rule_for_import.yml"]

        for fileName in configFiles {
            let nameOnly = (fileName as NSString).deletingPathExtension
            let extOnly = (fileName as NSString).pathExtension

            guard let bundleURL = Bundle.main.url(forResource: nameOnly, withExtension: extOnly)
            else {
                logW("📡 ⚠️ [Reset] 번들에서 \(fileName)을 찾을 수 없습니다.")
                continue
            }

            let destURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(fileName)

            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: bundleURL, to: destURL)
                logI("📡 [Reset] \(fileName) 복원 완료 -> \(destURL.path)")
            } catch {
                logE("📡 ❌ [Reset] \(fileName) 복원 실패: \(error)")
            }
        }
    }

    /// 설정만 초기화 (스니펫 파일 유지) - Issue 189
    // Issue 193 리팩토링: 'resetToDefaults'에 'includeSnippets: false'를 전달하여 구현
    func resetSettingsOnly() {
        logI("📡 [Soft Reset] 설정 초기화 실행")

        let fileManager = FileManager.default
        let configURL = PreferencesManager.shared.configURL

        var bundleURL = Bundle.main.url(forResource: "_config", withExtension: "yml")
        if bundleURL == nil {
            bundleURL = Bundle.main.url(forResource: "config", withExtension: "yaml")
        }

        if let sourceURL = bundleURL {
            do {
                if fileManager.fileExists(atPath: configURL.path) {
                    try fileManager.removeItem(at: configURL)
                }
                try fileManager.copyItem(at: sourceURL, to: configURL)
                logI("📡 [Soft Reset] 기본 설정 파일 덮어쓰기 완료 (\(configURL.path))")
            } catch {
                logE("📡 ❌ [Soft Reset] 설정 파일 덮어쓰기 실패: \(error)")
            }
        } else {
            logW("📡 ⚠️ [Soft Reset] 번들에서 설정 파일을 찾을 수 없습니다.")
        }

        // 스니펫은 삭제하지 않음
        resetToDefaults(includeSnippets: false)
        logI("📡 [Soft Reset] 설정 초기화 완료 (스니펫 폴더 유지)")
    }

    // Issue 193: 리팩토링 - 'includeSnippets' 파라미터 추가
    // includeSnippets가 true면 공장 초기화 (기존 동작)
    // includeSnippets가 false면 설정만 초기화 (스니펫 파일 유지)
    func resetToDefaults(includeSnippets: Bool = true) {
        // Issue 676: Prevent didSet from scheduling an auto-save that would overwrite the newly copied _config.yml
        isSaving = true
        defer { isSaving = false }

        settings = .default
        autoStart = false
        hideFromMenuBar = false
        showInAppSwitcher = false
        showNotifications = true
        debugLogging = false
        performanceMonitoring = false
        playReadySound = false

        // 로그 레벨 기본값 설정
        #if DEBUG
            logLevel = .verbose
        #else
            logLevel = .info
        #endif

        // [CL063] 완전 초기화는 클립보드 히스토리 및 통계 포함
        if includeSnippets {
            logI("📡 [Reset] 클립보드 히스토리 및 통계 데이터 삭제 진행")
            ClipboardDB.shared.clearAll()
            SnippetUsageManager.shared.deleteAllHistory()
        }

        // Issue 193: UserDefaults 완전 초기화
        cleanupUserDefaults(preservePaths: !includeSnippets)

        // Issue 188: 초기화 시 폴더 구조 재생성 (includeSnippets에 따라 파일 삭제 여부 결정)
        resetFolderStructure(preserveSnippets: !includeSnippets)

        // 그 다음 설정 저장 (config.yaml 생성)
        // [수정] Issue 189: 설정을 저장하지 않고 재시작하여 AppInitializer가 초기 설정을 진행하도록 함 (Alert 표시 등)
        // saveSettings()

        // 앱 재시작 (변경 사항을 완전히 적용하기 위함)
        restartApp()
    }

    /// 앱 재시작
    func restartApp() {
        logI("📡 [Reset] 앱 재시작 요청")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let bundleURL = Bundle.main.bundleURL
            logI("📡 [Reset] 번들 경로: \(bundleURL.path)")

            // NSWorkspace 대신 /usr/bin/open -n 사용 (더 확실한 재시작)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-n", bundleURL.path]

            do {
                try task.run()
                logI("📡 [Reset] open -n 명령 실행 성공, 앱 종료")
                NSApp.terminate(nil)
            } catch {
                logE("📡 ❌ [Reset] open -n 실행 실패: \(error)")
            }
        }
    }

    /// 폴더 구조 초기화 및 재생성 (Issue 188)
    /// preserveSnippets: true이면 앱 루트 삭제 시 snippets 폴더는 보존하거나 삭제하지 않음.
    private func resetFolderStructure(preserveSnippets: Bool) {
        let fileManager = FileManager.default
        let appRootPath = (settings.appRootPath as NSString).expandingTildeInPath
        let snippetsPath = (settings.basePath as NSString).expandingTildeInPath
        let logsPath = (appRootPath as NSString).appendingPathComponent("logs")
        let configPath = (appRootPath as NSString).appendingPathComponent("config.yaml")  // config.yaml도 명시적 처리

        logI("📡 [Reset] 폴더 구조 초기화 시작: \(appRootPath) (스니펫 보존: \(preserveSnippets))")

        // 1. 기존 폴더 제거 logic refactoring
        // 스니펫을 보존해야 한다면 전체 삭제를 하면 안됨.

        if preserveSnippets {
            // 스니펫 보존 모드: config.yaml, logs 폴더만 삭제

            // 1) config.yaml (Legacy) 삭제
            if fileManager.fileExists(atPath: configPath) {
                do {
                    try fileManager.removeItem(atPath: configPath)
                    logI("📡 [Reset] 설정 파일(config.yaml) 제거 완료")
                } catch {
                    logE("📡 ❌ [Reset] 설정 파일 제거 실패: \(error)")
                }
            }

            // 1-2) _config.yml 삭제 (이 경우 스니펫은 보존하지만, 설정은 날려야하므로)
            // 참고: resetSettingsOnly()에서 이미 복사해 둔 경우엔 이 로직을 실행하지 않기 위해 플래그로 분기해야 함
            // 하지만 현재 resetFolderStructure는 resetSettingsOnly 직후에 불리므로, _config.yml을 여기서 날리면 안됨!
            // 고로 새 버전 '_config.yml'은 여기서 삭제하지 않음. (resetSettingsOnly() 에서 알아서 복사함)

            // 2) logs 폴더 삭제 (로그는 뭐 지워도 됨)
            if fileManager.fileExists(atPath: logsPath) {
                do {
                    try fileManager.removeItem(atPath: logsPath)
                    logI("📡 [Reset] 로그 폴더 제거 완료")
                } catch {
                    logE("📡 ❌ [Reset] 로그 폴더 제거 실패: \(error)")
                }
            }

            // 앱 루트 자체가 없으면 생성해줘야 함 (아래 2번 단계에서 처리)

        } else {
            // 전체 초기화 모드 (기존 로직): 앱 루트 통째로 날림
            if fileManager.fileExists(atPath: appRootPath) {
                do {
                    try fileManager.removeItem(atPath: appRootPath)
                    logI("📡 [Reset] 기존 앱 루트 폴더 제거 완료")
                } catch {
                    logE("📡 ❌ [Reset] 기존 앱 루트 폴더 제거 실패: \(error)")
                    // 실패하더라도 계속 진행 시도
                }
            }
        }

        // 2. 앱 루트 폴더 생성 (없으면 생성)
        if !fileManager.fileExists(atPath: appRootPath) {
            do {
                try fileManager.createDirectory(
                    atPath: appRootPath, withIntermediateDirectories: true, attributes: nil)
                logI("📡 [Reset] 앱 루트 폴더 생성 완료")
            } catch {
                logE("📡 ❌ [Reset] 앱 루트 폴더 생성 실패: \(error)")
                return
            }
        }

        // 3. 하위 폴더 생성 (snippets, logs)
        // snippetsPath가 없으면 생성 (preserveSnippets여도 폴더가 없으면 만들어야 함)
        do {
            if !fileManager.fileExists(atPath: snippetsPath) {
                try fileManager.createDirectory(
                    atPath: snippetsPath, withIntermediateDirectories: true, attributes: nil)
                logI("📡 [Reset] snippets 폴더 생성 완료")
            }

            if !fileManager.fileExists(atPath: logsPath) {
                try fileManager.createDirectory(
                    atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
                logI("📡 [Reset] logs 폴더 생성 완료")
            }
        } catch {
            logE("📡 ❌ [Reset] 하위 폴더 생성 실패: \(error)")
        }

        // 4. 검증 로그
        logI("📡 [Reset] 검증 완료")
    }

    /// UserDefaults 정리 (Issue 193)
    private func cleanupUserDefaults(preservePaths: Bool = false) {
        let defaults = UserDefaults.standard
        var keysToRemove = [
            "start_at_login",
            "hide_menu_bar_icon",
            "show_notifications",
            "debug_logging",
            "log_level",
            "ActiveTriggerKeys",
            "snippet_excluded_files",
            "snippet_trigger_key",
            "snippet_trigger_bias",
            "snippet_popup_modifier_flags",
            "snippet_popup_key_code",
            "snippet_popup_display_string",
            "AppleLanguages",  // Issue 359/Bugfix: language lock 방지
        ]

        if !preservePaths {
            keysToRemove.append(contentsOf: ["appRootPath", "snippet_base_path"])
        }

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        logI("📡 [Reset] UserDefaults 키 삭제 완료: \(keysToRemove.count)개")
    }

    func updateSnippetCount() {
        // SnippetFileManager에서 로드된 Snippet 수 가져오기
        DispatchQueue.main.async {
            self.loadedSnippetCount = SnippetFileManager.shared.snippetMap.count
        }
    }

    // MARK: - Private Methods

    // MARK: - Private Methods

    private func loadUISettings() {
        let prefs = PreferencesManager.shared
        let defaults = UserDefaults.standard

        // 1. Auto Start
        if let val = prefs.get("start_at_login") as Bool? {
            autoStart = val
        } else {
            let legacy = defaults.bool(forKey: "autoStart")
            autoStart = legacy
            prefs.set(legacy, forKey: "start_at_login")
        }

        // 2. Hide from Menu Bar
        if let val = prefs.get("hide_menu_bar_icon") as Bool? {
            hideFromMenuBar = val
        } else {
            let legacy = defaults.bool(forKey: "hideFromMenuBar")
            hideFromMenuBar = legacy
            prefs.set(legacy, forKey: "hide_menu_bar_icon")
        }

        // 2.5 Show in App Switcher
        if let val = prefs.get("show_in_app_switcher") as Bool? {
            showInAppSwitcher = val
        } else {
            let legacy = defaults.bool(forKey: "showInAppSwitcher")
            showInAppSwitcher = legacy
            prefs.set(legacy, forKey: "show_in_app_switcher")
        }

        // 3. Show Notifications (Default true)
        if let val = prefs.get("show_notifications") as Bool? {
            showNotifications = val
        } else {
            // UserDefaults returns false if not set, but we want default true if never set?
            // Actually defaults.bool returns false if missing.
            // If "showNotifications" key exists, use it.
            if defaults.object(forKey: "showNotifications") != nil {
                let legacy = defaults.bool(forKey: "showNotifications")
                showNotifications = legacy
                prefs.set(legacy, forKey: "show_notifications")
            } else {
                // Not in legacy either, use default
                showNotifications = true
                prefs.set(true, forKey: "show_notifications")
            }
        }

        // 3.1 Ready Sound
        if let val = prefs.get("play_ready_sound") as Bool? {
            playReadySound = val
        }

        // 4. Language (Issue 359)
        // 4. Language (Issue 359)
        language = prefs.string(forKey: "language", defaultValue: "system")

        // 4.5 REST API 설정 (Issue 741)
        apiEnabled = prefs.bool(forKey: "api_enabled", defaultValue: false)
        apiPort = prefs.get("api_port") ?? 3015
        apiAllowExternal = prefs.bool(forKey: "api_allow_external", defaultValue: false)
        apiAllowedCIDR = prefs.string(forKey: "api_allowed_cidr", defaultValue: "127.0.0.1/32")

        // 4.7 Launch at Login 설정 (Issue 61)
        launchAtLogin = prefs.bool(forKey: "launch_at_login", defaultValue: false)

        // 5. Appearance Mode (Issue 386)
        // PreferencesManager -> SnippetSettings via SettingsManager.load()
        let loadedSettings = SettingsManager.shared.load()
        self.appearanceMode = loadedSettings.appearanceMode

        // 4. Debug Logging
        if let val = prefs.get("debug_logging") as Bool? {
            debugLogging = val
        } else {
            let legacy = defaults.bool(forKey: "debugLogging")
            debugLogging = legacy
            prefs.set(legacy, forKey: "debug_logging")
        }

        // 5. Performance Monitoring
        if let val = prefs.get("performance_monitoring") as Bool? {
            performanceMonitoring = val
        } else {
            let legacy = defaults.bool(forKey: "performanceMonitoring")
            performanceMonitoring = legacy
            prefs.set(legacy, forKey: "performance_monitoring")
        }

        // 6. Popup Settings (Issue 178)
        // SettingsManager에서 로드
        let coreSettings = SettingsManager.shared.load()
        // Issue355: Load Popup Width (UI-Only Setting)
        let loadedWidth: Double = PreferencesManager.shared.get("snippet_popup_width") ?? 350.0
        logI("📡 [Settings] Loaded loadedWidth from prefs: \(loadedWidth) (Default: 350.0)")
        self.popupWidth = CGFloat(loadedWidth)

        // Issue 595: Load Popup Preview Width
        let loadedPreviewWidth: Double =
            PreferencesManager.shared.get("snippet_popup_preview_width") ?? 400.0
        logI(
            "📡 [Settings] Loaded loadedPreviewWidth from prefs: \(loadedPreviewWidth) (Default: 400.0)"
        )
        self.popupPreviewWidth = CGFloat(loadedPreviewWidth)

        // Issue184: Load Search Scope
        self.popupSearchScope = coreSettings.popupSearchScope
        self.popupRows = coreSettings.popupRows  // Issue 245
        logI("📡 [Settings] loadUISettings 완료: popupRows=\(self.popupRows)")

        // Issue 230
        self.popupQuickSelectModifierFlags = coreSettings.popupQuickSelectModifierFlags

        // Issue 376
        self.statsRetentionUsageDays = coreSettings.statsRetentionUsageDays

        // Issue727: Settings Hotkey
        self.settingsHotkey = coreSettings.settingsHotkey

        // Integrated History Load
        self.historyEnabledPlainText = coreSettings.historyEnabledPlainText
        self.historyRetentionDaysPlainText = coreSettings.historyRetentionDaysPlainText
        self.historyEnabledImages = coreSettings.historyEnabledImages
        self.historyRetentionDaysImages = coreSettings.historyRetentionDaysImages
        self.historyEnabledFileLists = coreSettings.historyEnabledFileLists
        self.historyRetentionDaysFileLists = coreSettings.historyRetentionDaysFileLists
        self.historyIgnoreImages = coreSettings.historyIgnoreImages
        self.historyIgnoreFileLists = coreSettings.historyIgnoreFileLists
        self.historyMoveDuplicatesToTop = coreSettings.historyMoveDuplicatesToTop
        self.historyViewerHotkey = coreSettings.historyViewerHotkey
        self.historyPauseHotkey = coreSettings.historyPauseHotkey
        self.historyShowStatusBar = coreSettings.historyShowStatusBar  // CL035
        self.historyForceInputSource = coreSettings.historyForceInputSource  // CL038
        self.historyShowPreview = coreSettings.historyShowPreview  // CL042
        self.historyPreviewHotkey = coreSettings.historyPreviewHotkey  // CL042
        self.historyRegisterSnippetHotkey = coreSettings.historyRegisterSnippetHotkey  // CL042
        self.historyImageDetailIsFloating = defaults.bool(forKey: "history.imageDetail.isFloating")  // CL067

        // Issue Fix: Load History Widths from Core Settings
        self.historyViewerWidth = coreSettings.historyViewerWidth
        self.historyPreviewWidth = coreSettings.historyPreviewWidth

        // Issue 425: Load Snippet List Widths
        self.snippetListNameWidth = CGFloat(
            PreferencesManager.shared.get("snippet_list_name_width") ?? 150.0)
        self.snippetListAbbrWidth = CGFloat(
            PreferencesManager.shared.get("snippet_list_abbr_width") ?? 120.0)

        // Trigger Key Load
        // Start by getting active keys (filtering out suffix/implicit ones if needed, but Manager handles storage)
        // Since we want SINGLE key behavior in UI, we take the first valid user key or default.
        // But activeTriggerKeys returns EnhancedTriggerKey objects. We need to convert to PopupKeyShortcut for UI.
        let activeKeys = TriggerKeyManager.shared.activeTriggerKeys.filter {
            !["delta_key", "ring_key", "not_key"].contains($0.id)
        }
        if let primaryKey = activeKeys.first {
            // EnhancedTriggerKey -> PopupKeyShortcut
            // Note: EnhancedTriggerKey doesn't store keyCode/modifiers directly in a way compatible with PopupKeyShortcut struct easily without mapping.
            // But wait, EnhancedTriggerKey has 'keyCode' and 'modifierFlags'.
            self.triggerKeyShortcut = PopupKeyShortcut(
                modifierFlags: primaryKey.modifierFlagsUInt,
                keyCode: primaryKey.hardwareKeyCode ?? 0, displayString: primaryKey.displayName)
        } else {
            self.triggerKeyShortcut = PopupKeyShortcut(
                modifierFlags: 0, keyCode: 0, displayString: "Click to Add...")
        }

        // 초기 상태 적용 — AutoStart: Issue47 (2026-04-19) SMAppService 경로 obsolete,
        // `brew services` 로 일원화. 별도 등록 호출 없음.
    }

    private func loadLogLevel() {
        let prefs = PreferencesManager.shared
        let defaults = UserDefaults.standard

        var logLevelString = "INFO"

        if let val = prefs.get("log_level") as String? {
            logLevelString = val
        } else if let legacy = defaults.string(forKey: "LogLevel") {
            logLevelString = legacy
            prefs.set(legacy, forKey: "log_level")
        } else {
            #if DEBUG
                logLevelString = "VERBOSE"
            #else
                logLevelString = "INFO"
            #endif
        }

        if let level = LogLevel.allCases.first(where: {
            $0.description.lowercased() == logLevelString.lowercased()
        }) {
            logLevel = level
        } else {
            // Fallback
            #if DEBUG
                logLevel = .verbose
            #else
                logLevel = .info
            #endif
        }

        // Logger에 반영
        logger.currentLogLevel = logLevel
    }

    func saveUISettings() {
        // 루프 방지: saveUISettings가 settings를 수정할 때 didSet이 트리거되어 다시 저장하려는 것을 방지
        if isSaving { return }
        isSaving = true
        defer { isSaving = false }

        logD("📡 [SettingsObservableObject] saveUISettings entered")
        let prefs = PreferencesManager.shared

        // Update AppleLanguages to force language change on next launch (Issue14: 정규화 적용)
        let normalizedLang = Self.normalizeLanguageCode(language)
        let defaults = UserDefaults.standard
        if normalizedLang == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([normalizedLang], forKey: "AppleLanguages")
        }
        defaults.synchronize()  // Ensure immediate save for restart logic

        // Batch Update 적용 (Issue: 설정 저장 최적화)
        prefs.batchUpdate { config in
            config["start_at_login"] = self.autoStart
            config["hide_menu_bar_icon"] = self.hideFromMenuBar
            config["show_in_app_switcher"] = self.showInAppSwitcher
            config["show_notifications"] = self.showNotifications
            config["play_ready_sound"] = self.playReadySound

            // Issue 359
            config["language"] = self.language

            // Issue 386
            config["appearance_mode"] = self.appearanceMode

            config["debug_logging"] = self.debugLogging
            config["performance_monitoring"] = self.performanceMonitoring
            config["log_level"] = self.logLevel.description
            config["history.imageDetail.isFloating"] = self.historyImageDetailIsFloating  // CL067

            // Issue 425: Save Snippet List Widths
            config["snippet_list_name_width"] = Double(self.snippetListNameWidth)
            config["snippet_list_abbr_width"] = Double(self.snippetListAbbrWidth)

            // Issue355: Save Popup Width
            config["snippet_popup_width"] = Double(self.popupWidth)

            // Issue 595: Save Popup Preview Width
            config["snippet_popup_preview_width"] = Double(self.popupPreviewWidth)

            // Issue Fix: Save History Widths Explicitly
            config["history.viewer.width"] = Double(self.historyViewerWidth)
            // Issue Fix (User Request): Rename key
            config["history.viewer_preview.width"] = Double(self.historyPreviewWidth)

            // Issue 741: REST API 설정
            config["api_enabled"] = self.apiEnabled
            config["api_port"] = self.apiPort
            config["api_allow_external"] = self.apiAllowExternal
            config["api_allowed_cidr"] = self.apiAllowedCIDR

            // Issue 61: Launch at Login 설정
            config["launch_at_login"] = self.launchAtLogin

            // Trigger Key Save logic is handled by SettingsManager.shared.save()
        }

        // Issue 386: Apply Appearance Mode (Side effect)
        AppAppearance.shared.apply(appearanceMode)

        // Trigger Key Manager Update (Side effect)
        if triggerKeyShortcut.keyCode != 0 {
            let newKeySpec = triggerKeyShortcut.toHotkeyString
            logD(
                "📡 [SettingsObservableObject] Saving Trigger Key to snippet_default_symbol: \(newKeySpec)"
            )
            // 2. Update TriggerKeyManager
            TriggerKeyManager.shared.updateDefaultTriggerKey(to: newKeySpec)
        } else {
            logD("📡 [SettingsObservableObject] Trigger Key Code is 0, skipping save.")
        }

        // Issue 178: Popup Settings -> SettingsManager를 통해 저장 (Direct update to settings)
        // var coreSettings = SettingsManager.shared.load() // Incorrect: this loaded fresh settings but didn't save them back.

        // SettingsObservableObject holds the source of truth for UI settings in `settings` struct.
        // We must update `settings` before calling saveAndUpdate(settings).

        settings.popupSearchScope = popupSearchScope
        settings.popupRows = popupRows  // Issue 245
        // Issue 230
        settings.popupQuickSelectModifierFlags = popupQuickSelectModifierFlags

        // Issue 376
        settings.statsRetentionUsageDays = statsRetentionUsageDays

        // Integrated History Save
        settings.historyEnabledPlainText = historyEnabledPlainText
        settings.historyRetentionDaysPlainText = historyRetentionDaysPlainText
        settings.historyEnabledImages = historyEnabledImages
        settings.historyRetentionDaysImages = historyRetentionDaysImages
        settings.historyEnabledFileLists = historyEnabledFileLists
        settings.historyRetentionDaysFileLists = historyRetentionDaysFileLists
        settings.historyIgnoreImages = historyIgnoreImages
        settings.historyIgnoreFileLists = historyIgnoreFileLists
        settings.historyMoveDuplicatesToTop = historyMoveDuplicatesToTop
        settings.historyViewerHotkey = historyViewerHotkey
        settings.historyPauseHotkey = historyPauseHotkey
        settings.historyShowStatusBar = historyShowStatusBar  // CL035
        settings.historyForceInputSource = historyForceInputSource  // CL038
        settings.historyShowPreview = historyShowPreview  // CL042
        settings.historyPreviewHotkey = historyPreviewHotkey  // CL042
        settings.historyRegisterSnippetHotkey = historyRegisterSnippetHotkey  // CL042

        // Issue 426: Sync UI settings to struct before saving to prevent overwrite with stale data
        // Explicitly sync Trigger Key
        if triggerKeyShortcut.keyCode != 0 {
            settings.defaultSymbol = triggerKeyShortcut.toHotkeyString
        }

        // Issue Fix: Sync Popup Key Shortcut - Removed (Directly bound in View)
        // settings.popupKeyShortcut = popupKeyShortcut

        // Explicitly sync Appearance Mode
        settings.appearanceMode = appearanceMode
        // Issue727: Sync Settings Hotkey
        settings.settingsHotkey = settingsHotkey

        // Issue Fix: Sync History Widths
        settings.historyViewerWidth = historyViewerWidth
        settings.historyPreviewWidth = historyPreviewWidth

        SettingsManager.shared.saveAndUpdate(settings)

        // Issue 243_4: Refactored — 설정 변경은 즉시 저장됨

        // (중복 제거) 기존 loadUISettings 내에서 처리
    }

    // MARK: - Issue 238: Statistics
    func deleteAllStatistics() {
        SnippetUsageManager.shared.deleteAllHistory()
        logI("📡 [Settings] 통계 데이터 삭제 요청됨")
    }

    // MARK: - Issue 61: launchAtLogin ↔ brew services plist 연동

    /// launchAtLogin 설정 변경 — brew services plist 연동
    /// - enabled: true → brew services start, false → brew services stop
    /// - 호출 전제: 반드시 background 스레드에서 호출 (process.waitUntilExit 사용)
    func setLaunchAtLogin(_ enabled: Bool) {
        logI("📡 [Settings] launchAtLogin 변경 요청: \(enabled)")

        // 1. _config.yml 저장
        let prefs = PreferencesManager.shared
        prefs.set(enabled, forKey: "launch_at_login")

        // 2. brew services 동기화 (현재 스레드에서 블로킹 — background 스레드에서 호출 가정)
        if enabled {
            startBrewService()
        } else {
            stopBrewService()
        }

        // 3. @Published 상태 갱신 — 반드시 메인 스레드에서 실행
        DispatchQueue.main.async {
            self.launchAtLogin = enabled
            logI("📡 [Settings] launchAtLogin 설정 완료: \(enabled)")
        }
    }

    /// brew services start 실행 (헬퍼 메서드)
    private func startBrewService() {
        // brew 경로 찾기 (Apple Silicon: /opt/homebrew/bin/brew)
        let brewCandidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        for brewPath in brewCandidates {
            if FileManager.default.fileExists(atPath: brewPath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = ["services", "start", "fsnippet-cli"]

                do {
                    try process.run()
                    process.waitUntilExit()
                    let rc = process.terminationStatus
                    if rc == 0 {
                        logI("📡 [Settings] ✅ brew services start 성공")
                    } else {
                        logW("📡 [Settings] ⚠️ brew services start 실패 (rc=\(rc))")
                    }
                    return
                } catch {
                    logE("📡 [Settings] ❌ brew 실행 실패: \(error.localizedDescription)")
                }
            }
        }

        logW("📡 [Settings] ⚠️ brew 바이너리를 찾을 수 없음")
    }

    /// brew services stop 실행 (헬퍼 메서드)
    private func stopBrewService() {
        let brewCandidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        for brewPath in brewCandidates {
            if FileManager.default.fileExists(atPath: brewPath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = ["services", "stop", "fsnippet-cli"]

                do {
                    try process.run()
                    process.waitUntilExit()
                    let rc = process.terminationStatus
                    if rc == 0 {
                        logI("📡 [Settings] ✅ brew services stop 성공")
                    } else {
                        logW("📡 [Settings] ⚠️ brew services stop 실패 (rc=\(rc))")
                    }
                    return
                } catch {
                    logE("📡 [Settings] ❌ brew 실행 실패: \(error.localizedDescription)")
                }
            }
        }

        logW("📡 [Settings] ⚠️ brew 바이너리를 찾을 수 없음")
    }
}

// MARK: - Enhanced SettingsManager

extension SettingsManager {
    /// 설정 변경 시 자동으로 Snippet 시스템 업데이트
    func saveAndUpdate(_ settings: SnippetSettings) {
        let oldSettings = SettingsManager.shared.load()

        logD("📡 [saveAndUpdate] 이전 트리거 바이어스: \(oldSettings.triggerBias)")
        logD("📡 [saveAndUpdate] 새 트리거 바이어스: \(settings.triggerBias)")

        SettingsManager.shared.save(settings)

        logD("📡 [saveAndUpdate] 설정 저장 완료")

        // 기본 경로가 변경된 경우 Snippet 시스템 재로드
        if oldSettings.basePath != settings.basePath {
            SnippetFileManager.shared.updateRootFolder(settings.basePath)
            SnippetFileManager.shared.loadAllSnippets()
            SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)
        }

        // 트리거키가 변경된 경우 사용자에게 재시작 여부 묻기
        if oldSettings.defaultSymbol != settings.defaultSymbol {
            logV(
                "📡 [Issue38] 트리거키 변경 감지 - 재시작 필요 (기존: '\(oldSettings.defaultSymbol)' → 새: '\(settings.defaultSymbol)')"
            )

            // 사용자에게 재시작 여부 묻기
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "앱 재시작 필요"
                alert.informativeText =
                    "트리거키가 '\(oldSettings.defaultSymbol)'에서 '\(settings.defaultSymbol)'로 변경되었습니다.\n\n새로운 트리거키를 적용하려면 앱을 재시작해야 합니다.\n지금 재시작하시겠습니까?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "재시작")
                alert.addButton(withTitle: "나중에")

                let response = alert.runModal()

                if response == .alertFirstButtonReturn {
                    logV("📡 [Issue38] 사용자가 재시작 선택")

                    // 설정 변경 알림 (재시작 전에 보냄)
                    NotificationCenter.default.post(name: .settingsDidChange, object: settings)

                    // 앱 재시작
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        logV("📡 [Issue38] 앱 재시작 중...")

                        // 현재 앱의 경로 가져오기
                        let bundleURL = Bundle.main.bundleURL

                        // NSWorkspace를 사용하여 앱 재실행
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.createsNewApplicationInstance = true
                        configuration.activates = true

                        NSWorkspace.shared.openApplication(
                            at: bundleURL, configuration: configuration
                        ) { (app, error) in
                            if let error = error {
                                logE("📡 ❌ [Issue38] 앱 재시작 실패: \(error)")
                            } else {
                                logV("📡 [Issue38] 새 인스턴스 실행 성공")
                                // 현재 앱 종료
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    NSApp.terminate(nil)
                                }
                            }
                        }
                    }
                } else {
                    logV("📡 ⏸️ [Issue38] 사용자가 나중에 재시작 선택")

                    // 설정은 저장되었지만 적용되지 않음을 사용자에게 알림
                    let infoAlert = NSAlert()
                    infoAlert.messageText = "설정 저장됨"
                    infoAlert.informativeText =
                        "트리거키 설정이 저장되었습니다.\n새로운 트리거키 '\(settings.defaultSymbol)'는 다음 앱 실행 시 적용됩니다."
                    infoAlert.alertStyle = .informational
                    infoAlert.addButton(withTitle: "확인")
                    infoAlert.runModal()

                    // 다른 설정은 즉시 적용되도록 알림 전송
                    NotificationCenter.default.post(name: .settingsDidChange, object: settings)
                }
            }
        } else {
            logV("📡 [Issue38] 설정 변경 알림 전송 중... (트리거키 변경 없음)")

            // 트리거키 외 다른 설정 변경은 즉시 적용
            NotificationCenter.default.post(name: .settingsDidChange, object: settings)

            logV("📡 [Issue38] 설정 변경 알림 전송 완료!")
        }
    }

    /// 설정 검증 (Issue794: SettingsValidator로 위임)
    func validateSettings(_ settings: SnippetSettings) -> [String] {
        return SettingsValidator.validate(settings)
    }
    // migrateSettingsIfNeeded function removed
    /// 앱 재시작 (Self-Relaunch)
    func restartApp() {
        logI("📡 [Settings] 앱 재시작 요청됨...")

        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                logE("📡 ❌ [Settings] 앱 재시작 실패: \(error.localizedDescription)")
            } else {
                logI("📡 [Settings] 새 인스턴스 실행 성공, 현재 앱 종료")
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

// MARK: - Settings Validation (Issue794: 통합 검증)

struct SettingsValidator {

    /// 통합 설정 검증 — SettingsManager.validateSettings() 대체
    static func validate(_ settings: SnippetSettings) -> [String] {
        var errors: [String] = []

        // 기본 경로 검증
        if !validateBasePath(settings.basePath) {
            errors.append("Snippet 폴더가 존재하지 않습니다: \(settings.basePath)")
        }

        // 특수기호 검증
        let symbolError = validateSymbol(settings.defaultSymbol)
        if let error = symbolError {
            errors.append(error)
        }

        return errors
    }

    static func validateBasePath(_ path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    static func validateTriggerKey(_ key: String) -> Bool {
        return !key.isEmpty && key.count <= 3
    }

    /// 심볼 검증 — 유효하면 nil, 실패하면 에러 메시지 반환
    /// Issue809: {right_command} 등 오른쪽 수식어 형식({…}) 허용
    static func validateSymbol(_ symbol: String) -> String? {
        if symbol.isEmpty {
            return "기본 특수기호가 비어있습니다."
        }
        // {right_command}, {right_option} 등 오른쪽 수식어 형식 허용
        if symbol.hasPrefix("{") && symbol.hasSuffix("}") {
            return nil
        }
        if symbol.count > 5 {
            return "기본 특수기호가 너무 깁니다. (\(symbol.count)자, 최대 5자)"
        }
        return nil
    }

    static func sanitizePath(_ path: String) -> String {
        return (path as NSString).expandingTildeInPath
    }
}
