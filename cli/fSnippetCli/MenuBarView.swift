import SwiftUI

// MARK: - Menu Bar View

/// fSnippetCli menu bar (Issue82 — grouped submenus + shared shortcut tokens).
/// Tree mirrors `_doc_design/menuBar_enhance.md` cliApp section (L82-105).
///
/// Issue845/Issue98: Always visible; icon and About entry adapt to paidApp status
/// via `AppStateManager.shared.paidAppStatus`.
struct MenuBarView: View {
    @StateObject private var appState = AppStateManager.shared
    @State private var isPaused: Bool = PreferencesManager.shared.bool(
        forKey: "history.isPaused", defaultValue: false)
    @State private var isApiPaused: Bool = false
    @State private var launchAtLoginEnabled: Bool = FileManager.default.fileExists(
        atPath: NSHomeDirectory() + "/Library/LaunchAgents/homebrew.mxcl.fsnippet-cli.plist")
    var body: some View {
        // ─── About (Issue103: paidApp 동작 시 fSnippet 모드로 분기) ───
        let isPaidMode = appState.paidAppStatus == .started
        Button {
            AboutWindowManager.shared.showAbout(isPaidAppMode: isPaidMode)
        } label: {
            Label(isPaidMode ? "About fSnippet" : "About fSnippetCli", systemImage: "info.circle")
        }

        Divider()

        // ─── Top-level core actions ───
        Button {
            NotificationCenter.default.post(
                name: NSNotification.Name("fSnippetShowPopup"), object: nil)
        } label: {
            Label("⚡ Snippet Popup", systemImage: "bolt.fill")
        }
        .keyboardShortcut(KeyEquivalent(" "), modifiers: [.control, .shift])

        Button {
            HistoryViewerManager.shared.show()
        } label: {
            Label("📋 Show Clipboard History", systemImage: "clock.arrow.circlepath")
        }
        .keyboardShortcut(";", modifiers: .command)

        // ─── 📜 Clipboard submenu ───
        Menu {
            Button {
                togglePauseAction()
            } label: {
                Label(
                    isPaused ? "Resume" : "Pause",
                    systemImage: isPaused ? "play.fill" : "pause.fill")
            }
            .keyboardShortcut("p", modifiers: [.control, .option, .command])

            // Issue84 — Clipboard to Snippet (UI wired; backend deferred)
            Button {
                registerSnippetAction()
            } label: {
                Label("Clipboard to Snippet", systemImage: "text.badge.plus")
            }

            Button {
                clearClipboardHistory()
            } label: {
                Label("Clear Clipboard History", systemImage: "trash")
            }
        } label: {
            Label("📜 Clipboard", systemImage: "doc.on.clipboard")
        }

        // ─── 🔧 Open Settings Window ───
        Button {
            // Issue105: 단축키와 동일하게 cliApp 자체 설정창 열기 (paidApp 분기 제거)
            SettingsWindowManager.shared.toggleSettings()
        } label: {
            Label("🔧 Open Settings Window", systemImage: "gear")
        }
        .keyboardShortcut(";", modifiers: [.control, .shift, .command])

        Divider()

        // ─── 👻 Daemon submenu ───
        Menu {
            Button {
                reloadSnippets()
            } label: {
                Label("Reload Snippets", systemImage: "arrow.clockwise")
            }

            Button {
                restartDaemon()
            } label: {
                Label("Restart Daemon", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                pauseResumeAPIAction()
            } label: {
                Label(
                    isApiPaused ? "Resume REST API" : "Pause REST API",
                    systemImage: isApiPaused ? "play.circle" : "pause.circle")
            }
        } label: {
            Label("👻 Daemon", systemImage: "terminal")
        }

        // ─── ⚙️ Configuration submenu ───
        Menu {
            Button { openConfigFile() } label: {
                Label("Open Config File", systemImage: "doc.text")
            }
            Button { openSnippetFolder() } label: {
                Label("Open Snippet Folder", systemImage: "folder.badge.gearshape")
            }
            Button { openDataFolder() } label: {
                Label("Open Data Folder", systemImage: "folder")
            }
            Button { openLogDirectory() } label: {
                Label("Open Log Folder", systemImage: "doc.text.magnifyingglass")
            }
        } label: {
            Label("⚙️ Configuration", systemImage: "slider.horizontal.3")
        }

        Divider()

        // ─── Launch at Login ───
        Toggle(isOn: $launchAtLoginEnabled) {
            Label("🚀 Launch at Login", systemImage: "rocket")
        }
        .onChange(of: launchAtLoginEnabled) { _, newValue in
            handleLaunchAtLoginToggle(newValue)
        }

        // ─── Quit ───
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    // MARK: - Actions

    private func pauseResumeAPIAction() {
        if APIServer.shared.isApiPaused {
            APIServer.shared.resumeAPI()
        } else {
            APIServer.shared.pauseAPI()
        }
        isApiPaused = APIServer.shared.isApiPaused
    }

    private func togglePauseAction() {
        let prefs = PreferencesManager.shared
        let newState = !isPaused
        prefs.set(newState, forKey: "history.isPaused")
        isPaused = newState

        NotificationCenter.default.post(
            name: NSNotification.Name("historyPauseStateChanged"),
            object: newState)
    }

    private func clearClipboardHistory() {
        ClipboardDB.shared.clearAll()
    }

    // Issue84 — UI wiring only; backend deferred (Out of Scope §1).
    // Hotkey path goes through ShortcutMgr dispatcher; menu click mirrors that toast.
    private func registerSnippetAction() {
        ToastManager.shared.showToast(
            message: "Register Snippet — pending implementation",
            iconName: "hammer")
    }

    private func reloadSnippets() {
        let basePath = PreferencesManager.shared.string(
            forKey: "snippet_base_path",
            defaultValue: "~/Documents/finfra/fSnippetData/snippets")
        SnippetIndexManager.shared.rebuildIndex(basePath: basePath) { count in
            NSLog("[MenuBar] Snippets reloaded: \(count) entries")
        }
    }

    private func restartDaemon() {
        // Issue83 — invoke `brew services restart fsnippet-cli` asynchronously.
        // The current process is the daemon itself; brew will SIGTERM us shortly after launch,
        // so we cannot observe completion here. Surface only pre-launch failures.
        DispatchQueue.global(qos: .userInitiated).async {
            let candidates = [
                "/opt/homebrew/bin/brew",  // Apple Silicon
                "/usr/local/bin/brew",     // Intel
            ]
            let brewPath = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            guard let path = brewPath else {
                DispatchQueue.main.async { Self.showRestartFailure(reason: "brew not found in standard locations") }
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["services", "restart", "fsnippet-cli"]

            let stderr = Pipe()
            process.standardError = stderr
            process.standardOutput = Pipe()

            do {
                try process.run()
                NSLog("[MenuBar] Restart Daemon dispatched: \(path) services restart fsnippet-cli")
                // brew restart kills this process; no further work needed.
            } catch {
                let data = stderr.fileHandleForReading.availableData
                let detail = String(data: data, encoding: .utf8) ?? error.localizedDescription
                DispatchQueue.main.async { Self.showRestartFailure(reason: detail) }
            }
        }
    }

    private static func showRestartFailure(reason: String) {
        let alert = NSAlert()
        alert.messageText = "Restart Daemon Failed"
        alert.informativeText = reason
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func handleLaunchAtLoginToggle(_ enabled: Bool) {
        // Issue61 reuse — same entry point as REST `PATCH /api/v2/behavior` (APIRouter:1032)
        PreferencesManager.shared.set(enabled, forKey: "start_at_login")
        DispatchQueue.global(qos: .background).async {
            SettingsObservableObject.shared.setLaunchAtLogin(enabled)
        }
        NSLog("[MenuBar] Launch at Login toggled: \(enabled) — brew services sync dispatched")
    }

    private func openConfigFile() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/finfra/fSnippetData/_config.yml")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("Config file not found: \(url.path)")
        }
    }

    private func openSnippetFolder() {
        let basePath = PreferencesManager.shared.string(
            forKey: "snippet_base_path",
            defaultValue: "~/Documents/finfra/fSnippetData/snippets")
        let url = Self.resolveSnippetURL(basePath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("Snippet folder not found: \(url.path)")
        }
    }

    // Resolves snippet_base_path against the data root directory when the path
    // is relative (e.g. "./snippets"). Tilde paths and absolute paths pass through.
    static func resolveSnippetURL(_ basePath: String) -> URL {
        let dataRoot = PreferencesManager.shared.configURL.deletingLastPathComponent()
        let expanded = (basePath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: expanded, relativeTo: dataRoot).standardizedFileURL
    }

    private func openDataFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/finfra/fSnippetData")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("Data folder not found: \(url.path)")
        }
    }

    private func openLogDirectory() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/finfra/fSnippetData/logs")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("Log directory not found: \(url.path)")
        }
    }
}
