import Cocoa
import SwiftUI

struct HistoryPreviewView: View {
    let item: ClipboardItem

    @ObservedObject var state = HistoryPreviewState.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared  // ✅ CL050: Focus Mode State
    @ObservedObject var settings = SettingsObservableObject.shared  // CL076
    @State private var hasSelection: Bool = false

    @State private var eventMonitor: Any?
    @State private var isWindowKey: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(
                    systemName: item.type == .image
                        ? "photo" : (item.type == .fileList ? "folder" : "text.alignleft")
                )
                .foregroundColor(.secondary)
                Text(headerText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()

                // Edit Status
                if clipboardManager.chvMode == .previewEdit {
                    Text("EDITING")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                        .padding(.trailing, 4)
                }

                Text(item.dateString)  // Relative time
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(8)
            .background(
                ZStack {
                    Color(NSColor.controlBackgroundColor)
                    PopupUIConstants.clipboardBackgroundColor
                })

            Divider()

            // Content
            ZStack {
                if clipboardManager.chvMode == .previewEdit {
                    PreviewTextView(
                        text: $state.currentText,
                        isEditable: true,  // Always editable in .previewEdit
                        shouldSelectFirstLine: $state.shouldSelectFirstLine,
                        hasSelection: $hasSelection,
                        onEscape: { cursorIndex in
                            // Edit -> Interactive
                            let text = state.currentText
                            let swiftIndex =
                                text.utf16.index(
                                    text.utf16.startIndex, offsetBy: cursorIndex,
                                    limitedBy: text.utf16.endIndex) ?? text.utf16.endIndex
                            let safeIndex = String.Index(swiftIndex, within: text) ?? text.endIndex
                            let prefixString = String(text[..<safeIndex])
                            let currentLine =
                                prefixString.components(separatedBy: .newlines).count - 1

                            // CL099: Revert to original text on Escape (Issue 629_2)
                            if let originalText = state.currentItem?.text {
                                state.currentText = originalText
                            }

                            HistoryPreviewManager.shared.transitionToInteracting(
                                preservingLine: currentLine)
                        },
                        onCommit: { (selectedText: String?) in
                            if let text = selectedText {
                                // Partial Paste (Selection in Edit Mode)
                                logD(
                                    "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Partial Paste (Cmd+Enter with Selection)"
                                )
                                HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: false)
                                ClipboardManager.shared.copyToPasteboard(text: text)
                                HistoryViewerManager.shared.hideAndPaste()
                            } else {
                                // Full Paste (Commit Changes)
                                logD(
                                    "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Full Paste (Cmd+Enter, No Selection)"
                                )
                                guard let item = state.currentItem else { return }
                                let newItem = ClipboardItem(
                                    id: item.id,
                                    createdAt: item.createdAt,
                                    kind: item.kind,
                                    text: state.currentText,
                                    blobPath: item.blobPath,
                                    filelistJson: item.filelistJson,
                                    uti: item.uti,
                                    sizeBytes: item.sizeBytes,
                                    hash: item.hash,
                                    pinned: item.pinned,
                                    appBundle: item.appBundle
                                )
                                HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: false)
                                ClipboardManager.shared.copyToPasteboard(item: newItem)
                                HistoryViewerManager.shared.hideAndPaste()
                            }
                        },
                        onSave: { newText in
                            // CL045_10: Save (Cmd+S) without Paste
                            logD(
                                "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Save requested (Cmd+S)"
                            )

                            // 1. Update DB (Persistence)
                            if let currentId = state.currentItem?.id {
                                ClipboardDB.shared.updateItemContent(
                                    id: currentId, newText: newText)
                            } else {
                                logW("👓 👁 [HistoryPreviewView] Cannot save: No current item ID")
                            }

                            // 2. Update State (Memory)
                            HistoryPreviewState.shared.currentText = newText

                            // 3. Issue629_1: Transition to Interactive mode (.previewView)
                            HistoryPreviewManager.shared.transitionToInteracting(
                                preservingLine: state.focusLineIndex)

                            // 4. Feedback
                            ToastManager.shared.showToast(
                                message: LocalizedStringManager.shared.string("toast.saved"), iconName: "checkmark.circle.fill")
                        },
                        onEnter: { selectedText in
                            logD(
                                "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Partial Paste requested"
                            )
                            HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: false)
                            ClipboardManager.shared.copyToPasteboard(text: selectedText)
                            HistoryViewerManager.shared.hideAndPaste()
                        }
                    )
                    .padding(4)
                    .background(
                        ZStack {
                            Color(NSColor.textBackgroundColor)
                            PopupUIConstants.clipboardBackgroundColor
                        }
                    )
                    .overlay(Rectangle().stroke(Color.orange, lineWidth: 2))  // Always orange in Edit
                } else {
                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(
                            ZStack {
                                Color(NSColor.textBackgroundColor)
                                PopupUIConstants.clipboardBackgroundColor
                            })
                }
            }

            // Status Bar
            statusBarView
                .background(
                    ZStack {
                        Color(NSColor.windowBackgroundColor)
                        PopupUIConstants.clipboardBackgroundColor
                    })
        }
        .onAppear {
            // Add Window-Local Monitor for Tab/Shift+Tab
            // Only active when this view is visible (window is key)
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Strict Guard: Only handle events for the Preview Window
                guard let window = event.window, HistoryViewerManager.shared.isHistoryWindow(window)
                else {
                    return event
                }

                let isKeyWindow = (NSApp.keyWindow == window)

                // Monitor any key for debugging
                logD(
                    "👓 [chv:\(clipboardManager.chvMode)] : 👁 [PreviewMonitor] KeyCode: \(event.keyCode), Window: PreviewWindow, Mode: \(clipboardManager.chvMode)"
                )

                if event.keyCode == 1 {  // Cmd+S
                    if event.modifierFlags.contains(.command) {
                        if clipboardManager.chvMode == .previewView && isKeyWindow {
                            logD(
                                "👓 [HistoryPreviewView] Cmd+S pressed in Interactive View. Paid version only."
                            )
                            // 유료 버전 전용 기능 안내
                            PaidAppManager.shared.handlePaidFeature()
                            return nil  // Consume
                        }
                    }
                }

                if event.keyCode == 53 {  // Escape
                    if clipboardManager.chvMode == .previewView && isKeyWindow {
                        logD(
                            "👓 [HistoryPreviewView] Escape pressed in Preview View. Stopping interaction."
                        )
                        HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: true)
                        return nil  // Consume
                    }
                }

                if event.keyCode == 48 {  // Tab
                    if event.modifierFlags.contains(.shift) {
                        // Shift+Tab always allowed if window is key
                        if isKeyWindow && clipboardManager.chvMode == .previewView {
                            HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: true)
                            return nil
                        }
                    } else {
                        // Tab: Interactive -> Edit
                        // Only if we are focused (Key Window) and in .previewView
                        if isKeyWindow && clipboardManager.chvMode == .previewView {
                            // CL048_5: Calculate cursor index based on selection
                            var targetCursorIndex: Int? = nil
                            if let item = state.currentItem, item.type == .plainText {
                                let lines = state.lines
                                // Prefer focusLineIndex, fallback to first selected
                                let targetLineIndex = state.focusLineIndex

                                if targetLineIndex >= 0 && targetLineIndex < lines.count {
                                    // CL056: Robust Cursor Calculation using lineRange
                                    let text = state.currentText
                                    var currentLine = 0
                                    var currentIndex = text.startIndex

                                    // Traverse to the target line
                                    while currentLine < targetLineIndex
                                        && currentIndex < text.endIndex
                                    {
                                        let lineRange = text.lineRange(
                                            for: currentIndex..<currentIndex)
                                        currentIndex = lineRange.upperBound
                                        currentLine += 1
                                    }

                                    // Convert to Int index
                                    targetCursorIndex =
                                        NSRange(currentIndex..<currentIndex, in: text).location
                                    logD(
                                        "👓 [HistoryPreviewView] Calculated Cursor Index: \(targetCursorIndex!) for Line \(targetLineIndex)"
                                    )
                                }
                            }

                            if let item = state.currentItem {
                                HistoryPreviewManager.shared.startEditing(
                                    item: item, cursorIndex: targetCursorIndex)
                            } else {
                                HistoryPreviewManager.shared.startEditing()
                            }

                            // Removed simulated Auto-Tab: PreviewTextView native focus handling should manage this,
                            // and simulating a tab press breaks text selection.

                            return nil
                        }
                    }
                } else if event.keyCode == 126 {  // Arrow Up
                    if isKeyWindow && clipboardManager.chvMode == .previewView {
                        let extend = event.modifierFlags.contains(.shift)
                        state.moveSelection(direction: -1, extendSelection: extend)
                        return nil  // Consume
                    }
                } else if event.keyCode == 125 {  // Arrow Down
                    if isKeyWindow && clipboardManager.chvMode == .previewView {
                        let extend = event.modifierFlags.contains(.shift)
                        state.moveSelection(direction: 1, extendSelection: extend)
                        return nil  // Consume
                    }
                } else if event.keyCode == 36 {  // Enter
                    // CL071: Explicitly handle Enter and Cmd+Enter for Paste
                    let isCmd = event.modifierFlags.contains(.command)
                    logD(
                        "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Monitor saw Enter (Cmd: \(isCmd))"
                    )

                    if clipboardManager.chvMode != .previewEdit {
                        if let item = state.currentItem {
                            // Partial Paste Logic for View Mode
                            let selectedIndices = state.selectedLineIndices.sorted()

                            // Logic: If there is a selection, paste selection.
                            // EXCEPT if Cmd+Enter is pressed, maybe we force full paste?
                            // No, standardization: Cmd+Enter usually means "Submit/Paste"
                            // Let's keep logic: Selection -> Paste Selection, No Selection -> Paste Full Item.
                            // BUT, if Cmd+Enter is pressed, it should ALWAYS trigger paste regardless of minor state glitches.

                            if !selectedIndices.isEmpty {
                                // Extract selected lines
                                let lines = state.lines
                                let selectedText = selectedIndices.compactMap { index in
                                    (index >= 0 && index < lines.count) ? lines[index] : nil
                                }.joined(separator: "\n")

                                logD(
                                    "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Action: Paste Selected Lines (\(selectedIndices.count) lines)"
                                )

                                HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: false)
                                ClipboardManager.shared.copyToPasteboard(text: selectedText)
                                HistoryViewerManager.shared.hideAndPaste()
                            } else {
                                // Fallback to full item if nothing selected
                                logD(
                                    "👓 [chv:\(clipboardManager.chvMode)] : 👁 [HistoryPreviewView] Action: Paste Full Item (Interactive Fallback)"
                                )
                                HistoryPreviewManager.shared.stopEditing(shouldRestoreFocus: false)
                                ClipboardManager.shared.copyToPasteboard(item: item)
                                HistoryViewerManager.shared.hideAndPaste()
                            }
                        }
                        return nil  // Consume event
                    }
                } else if event.keyCode == 51 || event.keyCode == 117 {  // Delete (51) or Forward Delete (117)
                    if isKeyWindow && clipboardManager.chvMode == .previewView {
                        logD(
                            "👓 [HistoryPreviewView] Delete key (\(event.keyCode)) pressed. Attempting to delete selected lines."
                        )
                        if state.deleteSelectedLines() {
                            // Persist changes
                            if let currentId = state.currentItem?.id {
                                ClipboardDB.shared.updateItemContent(
                                    id: currentId, newText: state.currentText)
                                ToastManager.shared.showToast(
                                    message: LocalizedStringManager.shared.string("toast.line_deleted"), iconName: "trash")
                            }
                        }
                        return nil  // Consume event
                    }
                }
                return event
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            output in
            if let window = output.object as? NSWindow,
                window === HistoryViewerManager.shared.window
            {
                self.isWindowKey = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
            output in
            if let window = output.object as? NSWindow,
                window === HistoryViewerManager.shared.window
            {
                self.isWindowKey = false
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private var headerText: String {
        switch item.type {
        case .image:
            return "Image"
        case .fileList:
            return "Files"
        case .plainText:
            return "Text (\(item.content.count) chars)"
        case .other:
            return "Unknown"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .image:
            // Fix: Resolve absolute path from blob filename (CL053)
            if let blobFilename = item.blobPath,
                let blobsDir = ClipboardDB.shared.getBlobsDir()
            {
                let fullPath = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobFilename)
                    .path
                if !FileManager.default.fileExists(atPath: fullPath) {
                    Text("Image not found")
                        .foregroundColor(.secondary)
                        .padding()
                        .onAppear {
                            // ✅ Issue715: Handle missing image files
                            logW("🖼️ [HistoryPreviewView] Image file missing, removing item \(item.id ?? 0)")
                            if let id = item.id {
                                DispatchQueue.global(qos: .background).async {
                                    ClipboardDB.shared.deleteItem(id: id)
                                }
                            }
                        }
                } else if let nsImage = NSImage(contentsOfFile: fullPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                } else {
                    Text("Image load failed")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                Text("Image not found")
                    .foregroundColor(.secondary)
                    .padding()
            }

        case .fileList:
            if let files = try? JSONDecoder().decode(
                [String].self, from: item.content.data(using: .utf8) ?? Data())
            {
                List(files, id: \.self) { file in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(URL(fileURLWithPath: file).lastPathComponent)
                            .font(.caption)
                    }
                }
            } else {
                Text("Invalid File List")
                    .padding()
            }

        case .plainText:
            if clipboardManager.chvMode == .previewView {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(state.lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        state.selectedLineIndices.contains(index)
                                            ? PopupUIConstants.clipboardSelectionColor : Color.clear
                                    )
                                    .contentShape(Rectangle())  // Make entire row tappable
                                    .onTapGesture {
                                        // CL048: Mouse Interaction
                                        let modifiers = NSEvent.modifierFlags
                                        state.selectLine(index: index, modifiers: modifiers)

                                        // Ensure Interactive Mode (without resetting selection)
                                        HistoryPreviewManager.shared.ensureInteractiveMode()
                                    }
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: state.selectedLineIndices) { _, newIndices in
                        if let firstIndex = newIndices.min() {
                            withAnimation {
                                proxy.scrollTo(firstIndex, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                ScrollView {
                    Text(item.content)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .textSelection(.enabled)  // Allows copy if needed (though window ignores mouse)
                }
            }

        case .other:
            Text("No preview available")
                .foregroundColor(.secondary)
                .padding()
        }
    }

    @ViewBuilder
    private var statusBarView: some View {
        HStack {
            Image(systemName: statusIconName)
                .foregroundColor(statusColor)
                .font(.caption2)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            // Optional: Dynamic Shortcut Help
            Text(shortcutText)
                .font(.caption2)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top)
    }

    private var statusIconName: String {
        if clipboardManager.chvMode == .previewEdit {
            return "pencil.circle.fill"
        } else if clipboardManager.chvMode == .previewView && isWindowKey {
            return "eye.circle.fill"
        } else {
            return "doc.text.magnifyingglass"
        }
    }

    private var statusColor: Color {
        if clipboardManager.chvMode == .previewEdit {
            return .orange
        } else if clipboardManager.chvMode == .previewView && isWindowKey {
            return .orange
        } else {
            return .secondary
        }
    }

    private var statusText: String {
        var baseText = ""
        if clipboardManager.chvMode == .previewEdit {
            baseText = "Edit Mode"
        } else if clipboardManager.chvMode == .previewView && isWindowKey {
            baseText = "Interactive View"
        } else {
            baseText = "Preview"
        }

        // CL075: Append Image Size if available
        if let sizeString = imageSizeString {
            return "\(baseText) | \(sizeString)"
        }
        return baseText
    }

    // CL075: Calculate Image Size
    private var imageSizeString: String? {
        guard item.type == .image,
            let blobsDir = ClipboardDB.shared.getBlobsDir(),
            let blobPath = item.blobPath
        else { return nil }

        let fullPath = URL(fileURLWithPath: blobsDir).appendingPathComponent(blobPath).path
        if let rep = NSImageRep(contentsOfFile: fullPath) {
            return "\(rep.pixelsWide) x \(rep.pixelsHigh) px"
        }
        return nil
    }

    private var shortcutText: String {
        if clipboardManager.chvMode == .previewEdit {
            if hasSelection {
                return "Esc: Exit Edit  |  ⌘s: Save & View  |  ⌘⏎: Paste Selection"
            } else {
                return "Esc: Exit Edit  |  ⌘s: Save & View  |  ⌘⏎: Paste Content"
            }
        } else if clipboardManager.chvMode == .previewView && isWindowKey {
            return "Tab: Edit  |  Esc: Back to List  |  Shift+Tab: List  |  ⌘s: Save To Snippet (Paid Only)"
        } else {
            // Passive Preview (List has focus)
            return "Tab: Interactive View  |  ⌘s: Save To Snippet (Paid Only)"
        }
    }
}

// MARK: - Extensions for Preview Compatibility moved to ClipboardDB.swift
