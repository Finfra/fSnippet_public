import SwiftUI

// MARK: - Menu Bar View

/// fSnippetCli menu bar (Issue82 — grouped submenus + shared shortcut tokens).
/// Tree mirrors `_doc_design/menuBar_enhance.md` cliApp section (L82-105).
///
/// Time-based mutual exclusion is enforced by `MenuBarExtra(isInserted:)`
/// in `fSnippetCliApp.swift` — this view is only instantiated when paidApp is not running.
struct MenuBarView: View {
    @State private var isPaused: Bool = PreferencesManager.shared.bool(
        forKey: "history.isPaused", defaultValue: false)
    @State private var launchAtLoginEnabled: Bool = PreferencesManager.shared.bool(
        forKey: "start_at_login", defaultValue: false)
    var body: some View {
        // ─── About ───
        Button {
            AboutWindowManager.shared.showAbout()
        } label: {
            Label("About fSnippetCli", systemImage: "info.circle")
        }

        Divider()

        // ─── Top-level core actions ───
        Button("⚡ Snippet Popup") {
            NotificationCenter.default.post(
                name: NSNotification.Name("fSnippetShowPopup"), object: nil)
        }
        .keyboardShortcut(KeyEquivalent(" "), modifiers: [.control, .shift])

        Button("📋 Show Clipboard History") {
            HistoryViewerManager.shared.show()
        }
        .keyboardShortcut(";", modifiers: .command)

        // ─── 📜 Clipboard submenu ───
        Menu("📜 Clipboard") {
            Button(isPaused ? "Resume" : "Pause") {
                togglePauseAction()
            }
            .keyboardShortcut("p", modifiers: [.control, .option, .command])

            // Issue84 — Clipboard to Snippet (UI wired; backend deferred)
            Button("Clipboard to Snippet") {
                registerSnippetAction()
            }

            Button("Clear Clipboard History") {
                clearClipboardHistory()
            }
        }

        // ─── 🔧 Open Settings Window ───
        Button("🔧 Open Settings Window") {
            PaidAppManager.shared.handlePaidFeature()
        }
        .keyboardShortcut(";", modifiers: [.control, .shift, .command])

        Divider()

        // ─── 👻 Daemon submenu ───
        Menu("👻 Daemon") {
            Button("Reload Snippets") {
                reloadSnippets()
            }

            Button("Restart Daemon") {
                restartDaemon()
            }
        }

        // ─── ⚙️ Configuration submenu ───
        Menu("⚙️ Configuration") {
            Button("Open Config File") { openConfigFile() }
            Button("Open Data Folder") { openDataFolder() }
            Button("Open Log Folder") { openLogDirectory() }
        }

        Divider()

        // ─── Launch at Login (Phase 6 stub — brew services binding to be added) ───
        Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
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
