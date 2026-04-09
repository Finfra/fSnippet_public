import Cocoa
import SwiftUI

/// About 창 관리 클래스
class AboutWindowManager {
    static let shared = AboutWindowManager()
    private var window: NSWindow?

    /// About 창이 표시 중인지 확인
    var isAboutWindowVisible: Bool {
        return window?.isVisible == true
    }

    /// About 창 표시
    func showAbout() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)

        let newWindow = AboutWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentViewController = hostingController
        newWindow.title = "About fSnippet"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
        logV("ℹ️ About 창 표시")
    }
}

// MARK: - About NSWindow (⌘W 지원 + LSUIElement 포커스)

class AboutWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            close()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - About SwiftUI View

struct AboutView: View {
    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    private let productPageURL = URL(string: "https://finfra.kr/product/fSnippet/en/index.html")!
    private let githubURL = URL(string: "https://github.com/finfra/fSnippet_public")!

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 80, height: 80)
                }
                Text("fSnippet")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                linkRow(
                    systemImage: "globe",
                    title: "Product Page",
                    subtitle: "finfra.kr",
                    url: productPageURL
                )
                Divider().padding(.leading, 56)
                linkRow(
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub Repository",
                    subtitle: "github.com/finfra/fSnippet_public",
                    url: githubURL
                )
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )

            Text("© 2025 Finfra. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        }
        .padding(24)
        .frame(minWidth: 380, minHeight: 380)
    }

    @ViewBuilder
    private func linkRow(systemImage: String, title: String, subtitle: String, url: URL) -> some View {
        Button(action: {
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
