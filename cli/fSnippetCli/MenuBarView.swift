import Combine
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
    @State private var launchAtLoginEnabled: Bool = false  // Phase 6: brew services binding
    @State private var statusLine: String = "Status: Running · Port 3015"

    private let appLaunchTime: Date = Date()

    var body: some View {
        // ─── About ───
        Button {
            AboutWindowManager.shared.showAbout()
        } label: {
            Label("About fSnippetCli", systemImage: "info.circle")
        }

        Divider()

        // ─── Launch fSnippet (conditional: installed → launch / missing → product page) ───
        Button {
            launchOrOpenPaidAppPage()
        } label: {
            shortcutRow(label: "Launch fSnippet", shortcut: "⌃⇧⌘W")
        }

        Divider()

        // ─── Top-level core actions ───
        Button {
            NotificationCenter.default.post(
                name: NSNotification.Name("fSnippetShowPopup"), object: nil)
        } label: {
            shortcutRow(label: "Snippet Popup", shortcut: "⌃⇧Space")
        }

        Button {
            HistoryViewerManager.shared.show()
        } label: {
            shortcutRow(label: "Show History", shortcut: "⌘;")
        }

        // ─── 📜 Clipboard submenu ───
        Menu("📜 Clipboard") {
            Button {
                togglePauseAction()
            } label: {
                shortcutRow(
                    label: isPaused ? "Resume" : "Pause",
                    shortcut: "⌃⌥⌘P")
            }

            Button("Clear Clipboard History") {
                clearClipboardHistory()
            }
        }

        // ─── 👻 Daemon submenu ───
        Menu("👻 Daemon") {
            Button("Reload Snippets") {
                reloadSnippets()
            }

            Button {
                PaidAppDetector.launch()
            } label: {
                shortcutRow(label: "Open Main Window", shortcut: "⌃⇧⌘W")
            }

            Text(statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Restart Daemon") {
                showRestartDaemonStub()
            }
        }

        // ─── Settings ───
        Button {
            PaidAppDetector.openSettings()
        } label: {
            shortcutRow(label: "Settings...", shortcut: "⌃⇧⌘;")
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

    // MARK: - Shortcut Label Helper

    /// Renders a label-only shortcut (no SwiftUI keyboardShortcut binding).
    /// Global hotkey registration is owned solely by `ShortcutMgr` (Issue82 Phase1 SSOT).
    private func shortcutRow(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut).foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func launchOrOpenPaidAppPage() {
        if PaidAppDetector.installedURL() != nil {
            PaidAppDetector.launch()
        } else {
            if let url = URL(string: "https://finfra.kr/fSnippet") {
                NSWorkspace.shared.open(url)
            }
        }
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

    private func reloadSnippets() {
        // SnippetIndexManager rebuild is already wired via existing notification
        NotificationCenter.default.post(
            name: NSNotification.Name("fSnippetReloadSnippets"), object: nil)
    }

    private func showRestartDaemonStub() {
        // Phase 3.4 — Out of Scope §1: backend implementation deferred to follow-up issue
        let alert = NSAlert()
        alert.messageText = "Restart Daemon"
        alert.informativeText = "Pending implementation. Run `brew services restart fsnippet-cli` manually for now."
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func handleLaunchAtLoginToggle(_ enabled: Bool) {
        // Phase 6 stub: brew services enable/disable binding to be implemented next
        NSLog("[MenuBar] Launch at Login toggled: \(enabled) (Phase 6 binding pending)")
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
