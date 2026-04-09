import Cocoa

/// 메뉴바 관리 전용 클래스
class MenuBarManager {
    static let shared = MenuBarManager()
    private var statusItem: NSStatusItem?
    // private let settingsWindowManager = SettingsWindowManager.shared // 원형 의존성 방지를 위해 제거됨
    private let notificationManager = NotificationManager()

    /// 메뉴바 아이템 설정
    /// NOTE: MenuBarExtra(SwiftUI)가 메뉴바 아이콘을 관리하므로, NSStatusItem은 생성하지 않음
    func setupMenuBar() {
        // MenuBarExtra가 메뉴바를 관리하므로 중복 NSStatusItem 생성하지 않음
        logV("🔝 메뉴바 설정: MenuBarExtra가 관리 (NSStatusItem 생성 생략)")
    }

    /// 메뉴바 표시 상태 업데이트
    func updateMenuBarVisibility(hide: Bool) {
        if hide {
            // Issue723, Issue735: LSUIElement 상태여도 사용자가 원하면 숨기기 허용
            removeMenuBar()
        } else {
            if statusItem == nil {
                setupMenuBar()
            }
        }
    }

    /// 메뉴바 아이템 제거
    func removeMenuBar() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    // MARK: - Private Methods

    /// bolt.fill 이미지를 대각선으로 잘라 아래 부분을 투명하게 만듦
    private func createDiagonalCutImage(from sourceImage: NSImage) -> NSImage {
        let size = sourceImage.size
        let image = NSImage(size: size, flipped: false) { rect in
            // 사다리꼴 클리핑: 위쪽 전체를 보존하고 아래쪽만 대각선으로 깎음
            // 좌표계: (0,0)=좌하단, (w,h)=우상단
            // 왼쪽은 30% 높이에서, 오른쪽은 70% 높이에서 대각선으로 잘라냄
            let clipPath = NSBezierPath()
            clipPath.move(to: NSPoint(x: 0, y: rect.height * 0.3))       // 왼쪽 30%
            clipPath.line(to: NSPoint(x: rect.width, y: rect.height * 0.7))  // 오른쪽 70%
            clipPath.line(to: NSPoint(x: rect.width, y: rect.height))     // 오른쪽 상단
            clipPath.line(to: NSPoint(x: 0, y: rect.height))              // 왼쪽 상단
            clipPath.close()
            clipPath.setClip()

            sourceImage.draw(in: rect)
            return true
        }
        return image
    }

    private func createMenuBarMenu() -> NSMenu {
        let menu = NSMenu()
        // Issue730: 단축키 표시가 짤리지 않도록 최소 너비 보장
        menu.minimumWidth = 250

        // Issue731: About 메뉴 (비활성 → 활성화)
        let aboutItem = NSMenuItem(
            title: NSLocalizedString("menu.about", comment: ""),
            action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Issue730: 설정 메뉴에도 단축키 동적 반영
        let settingsHotkey = PreferencesManager.shared.string(forKey: "settings.hotkey")
        let (settingsKey, settingsModifiers) = parseKeySpec(settingsHotkey)
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.settings", comment: ""), action: #selector(showSettings),
            keyEquivalent: settingsKey)
        settingsItem.keyEquivalentModifierMask = settingsModifiers
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 도구 섹션
        menu.addItem(NSMenuItem.separator())

        // Issue730: PreferencesManager에서 단축키를 읽어 동적으로 반영
        let historyHotkey = PreferencesManager.shared.string(forKey: "history.viewer.hotkey")
        let (historyKey, historyModifiers) = parseKeySpec(historyHotkey)
        let historyItem = NSMenuItem(
            title: NSLocalizedString("statusbar.clipboard_history", comment: ""),
            action: #selector(showHistory), keyEquivalent: historyKey)
        historyItem.keyEquivalentModifierMask = historyModifiers
        historyItem.target = self
        menu.addItem(historyItem)

        // 일시정지/재개 토글
        let isPaused = PreferencesManager.shared.bool(
            forKey: "history.isPaused", defaultValue: false)
        let pauseTitle =
            isPaused
            ? NSLocalizedString("statusbar.resume_clipboard", comment: "")
            : NSLocalizedString("statusbar.pause_clipboard", comment: "")
        
        // Issue: 메뉴바에도 클립보드 수집 일시정지 단축키 표시
        let pauseHotkey = PreferencesManager.shared.string(forKey: "history.pause.hotkey")
        let (pauseKey, pauseModifiers) = parseKeySpec(pauseHotkey)
        
        let pauseItem = NSMenuItem(
            title: pauseTitle, action: #selector(togglePause), keyEquivalent: pauseKey)
        pauseItem.keyEquivalentModifierMask = pauseModifiers
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(
            title: NSLocalizedString("menu.reload_snippets", comment: ""),
            action: #selector(reloadSnippets), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let statsItem = NSMenuItem(
            title: NSLocalizedString("menu.status_info", comment: ""), action: #selector(showStats),
            keyEquivalent: "")
        statsItem.target = self
        menu.addItem(statsItem)

        let clearLogsItem = NSMenuItem(
            title: NSLocalizedString("statusbar.clear_logs", comment: ""),
            action: #selector(clearLogs), keyEquivalent: "")
        clearLogsItem.target = self
        menu.addItem(clearLogsItem)

        // 종료 섹션
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("statusbar.quit", comment: ""), action: #selector(quitApp),
            keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - KeySpec 파싱

    /// keySpec 문자열(예: "^⌥⌘;", "⌘;")을 NSMenuItem용 (keyEquivalent, modifierMask)로 변환
    private func parseKeySpec(_ spec: String) -> (String, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        // Issue730: config.yml에서 "{⌥⌘;}" 형태로 저장될 수 있으므로 중괄호 제거
        var remaining = spec.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")

        while !remaining.isEmpty {
            let ch = remaining.first!
            switch ch {
            case "^":
                modifiers.insert(.control)
                remaining.removeFirst()
            case "⌥":
                modifiers.insert(.option)
                remaining.removeFirst()
            case "⌘":
                modifiers.insert(.command)
                remaining.removeFirst()
            case "⇧":
                modifiers.insert(.shift)
                remaining.removeFirst()
            default:
                return (remaining, modifiers)
            }
        }
        return ("", modifiers)
    }

    // MARK: - 메뉴 액션

    @objc private func menuBarButtonClicked() {
        // 메뉴바 버튼 클릭 처리 (현재는 빈 구현)
    }

    @objc private func showAbout() {
        AboutWindowManager.shared.showAbout()
    }

    @objc private func showSettings() {
        SettingsWindowManager.shared.showSettings()
    }

    @objc private func showHistory() {
        logV("🔝 메뉴바에서 Clipboard History 호출")
        HistoryViewerManager.shared.show()
    }

    @objc private func handlePauseStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let menu = self.createMenuBarMenu()
            self.statusItem?.menu = menu
            logV("🔝 [MenuBar] Pause state changed - Menu updated")
        }
    }

    @objc private func togglePause() {
        let current = PreferencesManager.shared.bool(
            forKey: "history.isPaused", defaultValue: false)
        let newState = !current
        PreferencesManager.shared.set(newState, forKey: "history.isPaused")
        logI("🔝 [MenuBar] Clipboard collection paused: \(newState)")

        // 상태 변화 전파 (모든 UI 동기화)
        NotificationCenter.default.post(
            name: NSNotification.Name("historyPauseStateChanged"), object: newState)

        // HUD 알림 표시 (ToastManager 사용)
        let message =
            newState
            ? NSLocalizedString("toast.clipboard_paused", comment: "")
            : NSLocalizedString("toast.clipboard_resumed", comment: "")
        let icon = newState ? "pause.fill" : "play.fill"
        ToastManager.shared.showToast(message: message, iconName: icon)

        // 레거시 알림도 병행 (Notification Center)
        let msg =
            newState
            ? NSLocalizedString("notification.clipboard_paused", comment: "")
            : NSLocalizedString("notification.clipboard_resumed", comment: "")
        notificationManager.showNotification(title: "fSnippet", message: msg)
    }

    @objc private func reloadSnippets() {
        let settings = SettingsManager.shared.load()

        SnippetFileManager.shared.updateRootFolder(settings.basePath)
        SnippetFileManager.shared.loadAllSnippets()
        SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)

        logV("🔝 스니펫 다시 로드 완료")

        // 알림 표시
        notificationManager.showNotification(
            title: "fSnippet",
            message: NSLocalizedString("notification.reload_success", comment: "")
        )
    }

    @objc private func showStats() {
        let fileManager = SnippetFileManager.shared
        let indexManager = SnippetIndexManager.shared
        let stats = indexManager.getIndexStats()

        let message =
            String(
                format: NSLocalizedString("alert.status.folder", comment: ""),
                fileManager.rootFolderURL.path) + "\n"
            + String(
                format: NSLocalizedString("alert.status.loaded_count", comment: ""),
                fileManager.snippetMap.count) + "\n"
            + NSLocalizedString("alert.status.index_stats", comment: "") + "\n"
            + String(
                format: NSLocalizedString("alert.status.index_total", comment: ""), stats.total)
            + "\n"
            + String(
                format: NSLocalizedString("alert.status.index_active", comment: ""), stats.active)
            + "\n"
            + String(
                format: NSLocalizedString("alert.status.index_cache", comment: ""),
                stats.cache.entries, stats.cache.maxSize)

        notificationManager.showAlert(
            title: NSLocalizedString("alert.status.title", comment: ""), message: message)
    }

    @objc private func clearLogs() {
        logV("🔝 메뉴바에서 로그 클리어 요청됨")
        clearLogFile()
        logV("🔝 clearLogFile() 호출 완료")

        // 알림 표시
        notificationManager.showNotification(
            title: "fSnippet",
            message: NSLocalizedString("notification.logs_cleared", comment: "")
        )
    }

    @objc private func quitApp() {
        // 폴더 감시 중지
        SnippetFileManager.shared.stopFolderWatching()

        // 앱 종료를 AppDelegate에 알림
        NotificationCenter.default.post(name: .quitRequested, object: nil)

        NSApp.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
