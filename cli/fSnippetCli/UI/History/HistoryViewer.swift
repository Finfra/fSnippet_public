import Foundation
import SwiftUI

struct HistoryViewer: View {
    @ObservedObject var viewModel: HistoryViewModel
    @ObservedObject var settings = SettingsObservableObject.shared  // ✅ CL027: Settings for Modifier Key
    @ObservedObject var previewState = HistoryPreviewState.shared  // ✅ CL045_9: Observer for Focus State
    @ObservedObject var clipboardManager = ClipboardManager.shared  // ✅ CL050: Focus Mode State
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteConfirmation = false
    @State private var showingHelpPopover = false  // ✅ Issue 356: Helper Popover State

    // CL078: Filter Focus State
    @FocusState private var isFilterFocused: Bool

    @State private var eventMonitor: Any?  // ✅ Event Monitor State
    @State private var isFirstLatch = true  // 팝업 열림 직후 Delete/Backspace 오입력 방지 래치

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HistorySearchBar(
                text: $viewModel.searchText,
                onCancel: {
                    // CL085/CL091: Handling Esc in TextField (onExitCommand)
                    // Strategy: If text exists, clear it. If empty, hide window.
                    // Focus ALWAYS stays on SearchBar.
                    if !viewModel.searchText.isEmpty {
                        viewModel.searchText = ""
                    } else {
                        HistoryViewerManager.shared.hide()
                    }
                },
                selectedFilter: $viewModel.selectedFilter,
                availableApps: viewModel.availableApps,
                isFilterFocused: $isFilterFocused  // CL078: Bind focus state
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            // .padding(.top, 40) // [UI Refinement] Unified padding moved to UnifiedHistoryViewer

            Divider()

            // List
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        HistoryRowView(
                            item: item,
                            isSelected: viewModel.selectedIds.contains(item.id ?? -1),
                            isListActive: clipboardManager.chvMode == .list,  // ✅ CL050: Check chvMode
                            shortcut: getShortcut(for: index),  // ✅ CL027_2: Pass dynamic shortcut
                            onDelete: {
                                viewModel.selectedIds = [item.id!]
                                viewModel.deleteSelectedItems()
                            }
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        // CL091: List Click Focus Guard
                        // Clicking the list selects the item but MUST return focus to SearchBar immediately.
                        .onTapGesture {
                            // CL091: List Click Focus Guard (Moved from simultaneousGesture)
                            // Clicking the list selects the item but MUST return focus to SearchBar immediately.
                            DispatchQueue.main.async {
                                if let window = NSApp.keyWindow,
                                    HistoryViewerManager.shared.isHistoryWindow(window)
                                {
                                    forceFocusToSearchBar(in: window)
                                }
                            }

                            // Selection Logic
                            let isCmd = NSEvent.modifierFlags.contains(.command)
                            let isShift = NSEvent.modifierFlags.contains(.shift)

                            if !isCmd && !isShift {
                                // 일반 클릭: 선택 후 바로 붙여넣기 (기존 동작 복원)
                                confirmSelection(item)
                            } else {
                                // Modifier 클릭: 다중 선택 토글
                                viewModel.toggleSelection(
                                    id: item.id!, isCommandPressed: isCmd, isShiftPressed: isShift)
                            }
                        }
                        .background(
                            // ✅ CL037: Invisible button for shortcuts (works even when SearchBar is focused)
                            Group {
                                if index < 9 {
                                    Button(action: { confirmSelection(item) }) {
                                        EmptyView()
                                    }
                                    .keyboardShortcut(
                                        getSwiftUIKeyEquivalent(for: index),
                                        modifiers: getSwiftUIModifiers()
                                    )
                                    .opacity(0)
                                }
                            }
                        )
                        .onAppear {
                            // 마지막 항목 근처에 도달하면 다음 페이지 로드
                            if item.id == viewModel.items.last?.id {
                                viewModel.fetchNextPage()
                            }
                        }
                        .contextMenu {
                            Button("menu.copy") { confirmSelection(item) }
                            if item.type == .image {
                                Button("Save Image") {
                                    viewModel.saveImageLocally(item: item)
                                }
                            } else {
                                Button("menu.register") {
                                    viewModel.registerAndEditAsSnippet(item: item)
                                }
                            }
                            Button("menu.delete", role: .destructive) {
                                viewModel.selectedIds = [item.id!]
                                viewModel.deleteSelectedItems()
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .onChange(of: viewModel.lastSelectedId) { _, newId in
                    if let id = newId {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            // .overlay for toastMessage removed in Issue272 (Unified to ToastManager)

        }
        .safeAreaInset(edge: .bottom) {
            if settings.historyShowStatusBar {
                footerView
            }
        }
        .padding(.bottom, 0)  // ✅ CL069: Remove bottom margin
        .edgesIgnoringSafeArea([.top, .bottom])
        .onReceive(NotificationCenter.default.publisher(for: .historyViewerDidShow)) { _ in
            logV(
                "🕰️ [chv:\(clipboardManager.chvMode)] : 📋 [HistoryViewer] historyViewerDidShow"
            )

            // Issue801: 팝업 열림 시 래치 설정 (Delete/Backspace 오입력 방지)
            isFirstLatch = true

            // CL091: Enforce Search Focus on Open
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                logV("🕰️ [HistoryViewer] didShow -> Force Search Focus")
                clipboardManager.chvMode = .list
                if let window = NSApp.keyWindow, HistoryViewerManager.shared.isHistoryWindow(window)
                {
                    forceFocusToSearchBar(in: window)
                }
            }

            // ✅ CL037: Local Event Monitor for robust key handling
            if eventMonitor == nil {
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in

                    // Fix Create: Ignore events targeting the Preview Window
                    if HistoryPreviewManager.shared.isPreviewWindow(event.window) {
                        return event
                    }

                    // CL054: Strict Event Guard
                    if clipboardManager.chvMode == .deactive {
                        return event
                    }

                    // Fix: Bypass OTHER keys if not in List Mode
                    if clipboardManager.chvMode != .list {
                        if event.window != NSApp.keyWindow {
                            return event
                        }
                    }

                    // Strict Window Check: Only handle events for the History Window
                    guard let evtWindow = event.window,
                        HistoryViewerManager.shared.isHistoryWindow(evtWindow)
                    else {
                        return event
                    }

                    if handleKeyEvent(event) {
                        return nil  // Consumed
                    }
                    return event
                }
            }

            // ✅ CL038: Force Input Source
            InputSourceManager.shared.applyForceInputSource()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyViewerDidHide)) { _ in
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }

            // ✅ CL038: Restore Input Source
            InputSourceManager.shared.restoreInputSource()
        }
        // ✅ CL048_7: Fix Tab Transition
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            output in
            if let window = output.object as? NSWindow,
                HistoryViewerManager.shared.isHistoryWindow(window)
            {
                logV(
                    "🕰️ [chv:\(clipboardManager.chvMode)] : 📋 [HistoryViewer] Window Became Key -> Force Focus SearchBar"
                )
                clipboardManager.chvMode = .list
                // CL091: Always Focus Search Bar when Window becomes active
                DispatchQueue.main.async {  // Async to allow AppKit to finish its activation cycle
                    forceFocusToSearchBar(in: window)
                }
            }
        }
        .confirmationDialog(
            String(
                format: NSLocalizedString("alert.delete_items.title", comment: ""),
                viewModel.selectedIds.count),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("alert.common.delete", role: .destructive) {
                viewModel.deleteSelectedItems()
                HistoryViewerManager.shared.hide()
            }
            Button("alert.common.cancel", role: .cancel) {}
        } message: {
            Text("alert.delete_items.message")
        }
        // CL066: Filtered Delete Confirmation
        .confirmationDialog(
            "Delete all items matching query?",
            isPresented: $viewModel.showingFilteredDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(viewModel.filteredDeleteCount) Items", role: .destructive) {
                viewModel.confirmFilteredDelete()
                HistoryViewerManager.shared.hide()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will permanently delete \(viewModel.filteredDeleteCount) items that match '\(viewModel.searchText)'. This finding logic is exactly same as your search result.\nThis action cannot be undone."
            )
        }
        .onChange(of: showingDeleteConfirmation) { _, newValue in }
        .onChange(of: viewModel.showingFilteredDeleteConfirmation) { _, newValue in }
        .edgesIgnoringSafeArea([.top, .bottom])  // ✅ CL069: Ignore safe area for top and bottom
    }

    private func isSearchFieldActive(in window: NSWindow? = nil) -> Bool {
        // Refinement 15: Rely solely on AppKit FirstResponder (Single Source of Truth)
        let targetWindow = window ?? NSApp.keyWindow

        if let window = targetWindow, HistoryViewerManager.shared.isHistoryWindow(window) {
            if let responder = window.firstResponder {
                if responder is NSTextView || responder is NSTextField {
                    return true
                }
            }
        }
        return false
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Configurable Hotkeys (Priority Over Navigation/Hardcoded)

        // 1. Register as Snippet (Or Save Image for image items) — 유료 버전 전용
        if TriggerKeyManager.shared.isHotkeyMatch(
            event: event, hotkeyString: settings.historyRegisterSnippetHotkey.toHotkeyString)
        {
            if clipboardManager.chvMode == .list {
                PaidAppManager.shared.handlePaidFeature(
                    relativeTo: HistoryViewerManager.shared.window?.frame)
                return true
            }
            // If in .previewView or .previewEdit, let the event pass to the child views (HistoryPreviewView / PreviewTextView)
            // They have their own dedicated handling for Cmd+S.
        }

        // 2. Toggle Preview (CL042_2)
        if TriggerKeyManager.shared.isHotkeyMatch(
            event: event, hotkeyString: settings.historyPreviewHotkey.toHotkeyString)
        {
            if let selectedItem = viewModel.items.first(where: { $0.id == viewModel.selectedId }) {
                HistoryPreviewManager.shared.togglePreview(with: selectedItem)
                return true
            } else {
                HistoryPreviewManager.shared.togglePreview(with: nil)
                return true
            }
        }

        switch event.keyCode {
        case 0:  // A
            // CL073: Fix Cmd+A (Select All) in Search Bar
            if event.modifierFlags.contains(.command) {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                return true
            }
            return false

        case 9:  // V - Issue802: Cmd+V → 검색창에 붙여넣기
            if event.modifierFlags.contains(.command) {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                return true
            }
            return false

        case 125:  // Down
            if clipboardManager.chvMode != .list { return false }
            if isFilterFocused { return false }

            isFirstLatch = false  // Issue801: 네비게이션 키로 래치 해제
            let extend = event.modifierFlags.contains(.shift)
            viewModel.selectNext(extending: extend)
            return true  // Consume event so TextField doesn't move cursor

        case 126:  // Up
            if clipboardManager.chvMode != .list { return false }
            if isFilterFocused { return false }

            isFirstLatch = false  // Issue801: 네비게이션 키로 래치 해제
            let extend = event.modifierFlags.contains(.shift)
            viewModel.selectPrevious(extending: extend)
            return true  // Consume event so TextField doesn't move cursor

        case 36:  // Enter
            if clipboardManager.chvMode != .list { return false }
            // CL049: Multi-Selection Enter
            if let selectedItem = viewModel.items.first(where: { $0.id == viewModel.selectedId }) {
                confirmSelection(selectedItem)
            } else if !viewModel.selectedIds.isEmpty {
                if let firstId = viewModel.selectedIds.first,
                    let item = viewModel.items.first(where: { $0.id == firstId })
                {
                    confirmSelection(item)
                }
            }
            return true

        case 51, 117:  // Backspace (51), Forward Delete (117)
            if clipboardManager.chvMode != .list { return false }

            logD("📋 [Issue801] Delete/BS pressed — latch=\(isFirstLatch), searchText='\(viewModel.searchText)', selectedIds=\(viewModel.selectedIds.count)")

            // Issue803: 검색창에 텍스트가 있으면 텍스트 삭제만 수행
            // return true로 이벤트를 소비하여 아이템 삭제와 동시 실행 방지
            if !viewModel.searchText.isEmpty {
                logD("📋 [Issue803] → 텍스트 있음, deleteBackward 전달 후 이벤트 소비")
                if event.keyCode == 117 {
                    NSApp.sendAction(#selector(NSText.deleteForward(_:)), to: nil, from: nil)
                } else {
                    NSApp.sendAction(#selector(NSText.deleteBackward(_:)), to: nil, from: nil)
                }
                return true  // 이벤트 소비 → 중복 처리 방지
            }

            // Issue801: 래치가 걸려있으면 아이템 삭제 차단 (오입력 방지)
            // 단, 멀티 셀렉트(2개 이상)는 의도적 조작이므로 래치 무시
            if isFirstLatch && viewModel.selectedIds.count <= 1 {
                logD("📋 [Issue801] → 래치 ON + 단일선택, 삭제 차단")
                return true  // 이벤트 소비
            }

            // 텍스트 비어있고 래치 해제됨 → 아이템 삭제
            if !viewModel.selectedIds.isEmpty {
                logD("📋 [Issue803] → 아이템 삭제 실행 (latch=\(isFirstLatch), count=\(viewModel.selectedIds.count))")
                viewModel.deleteSelectedItems()
                return true
            }
            return true  // 텍스트 비어있고 선택 없음 → 이벤트 소비 (안전)

        case 48:  // Tab
            isFirstLatch = false  // Issue801: 네비게이션 키로 래치 해제
            logI("🕰️ [HistoryViewer] Tab pressed. Mode: \(clipboardManager.chvMode)")

            if clipboardManager.chvMode == .list {
                if let selectedItem = viewModel.items.first(where: { $0.id == viewModel.selectedId }
                ) {
                    if selectedItem.type == .image {
                        ImageDetailManager.shared.showImageDetail(item: selectedItem)
                        return true
                    }
                    HistoryPreviewManager.shared.startInteracting(item: selectedItem)
                    return true
                }
            }
            return false

        case 49:  // Space
            // 이미지 항목 선택 시 Space로 이미지 상세 보기 (macOS Quick Look 스타일)
            if clipboardManager.chvMode == .list {
                if let selectedItem = viewModel.items.first(where: { $0.id == viewModel.selectedId }),
                   selectedItem.type == .image {
                    ImageDetailManager.shared.showImageDetail(item: selectedItem)
                    return true
                }
            }
            return false

        case 35:  // P
            // Toggle pause. Allow if Cmd pressed or if not typing?
            // "P" is a valid search char.
            // If Cmd+P -> Toggle Pause?
            if event.modifierFlags.contains(.command) {
                viewModel.togglePause()
                return true
            }
            // If just P, let it type.
            return false

        case 53:  // Esc
            // CL091: Let Preview modes handle Escape themselves
            if clipboardManager.chvMode == .previewEdit || clipboardManager.chvMode == .previewView
            {
                return false
            }

            // CL091: Clear text or Close
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
                // Keep focus
                return true
            }

            HistoryViewerManager.shared.hide()
            return true

        default:
            // CL091: All other keys => Let them bubble to the TextField (Search)
            // Since we are always focused, typing happens naturally.

            // Check if we need to force focus if lost?
            // The Event Monitor runs before the view.
            // If the view lost focus (e.g. glitch), we might want to catch it here.

            // For now, assume onAppear/didBecomeKey handles focus enough.
            if !isSearchFieldActive(in: event.window) {
                // If by some chance we lost focus, grab it back and insert text?
                // This mimics the "Refinement 11" logic but as a safety net.
                if let chars = event.characters, !chars.isEmpty,
                    let firstChar = chars.first, !firstChar.isNewline
                {

                    if let window = event.window {
                        logV("🕰️ [HistoryViewer] Lost Focus Detected during typing. Restoring.")
                        forceFocusToSearchBar(in: window, textToInsert: String(firstChar))
                        return true
                    }
                }
            }

            return false
        }
    }

    // Helper to bypass SwiftUI FocusState flakiness
    private func forceFocusToSearchBar(in window: NSWindow, textToInsert: String? = nil) {
        guard let contentView = window.contentView else { return }

        func findValidatedTextField(in view: NSView) -> NSTextField? {
            // CL085: Use Tag 987654 (Defined in HistorySearchBar.swift)
            if view.tag == 987654, let tf = view as? NSTextField {
                return tf
            }
            for sub in view.subviews {
                if let found = findValidatedTextField(in: sub) {
                    return found
                }
            }
            return nil
        }

        if let textField = findValidatedTextField(in: contentView) {
            logV("🕰️ [HistoryViewer] Force Focus to SearchBar.")
            window.makeFirstResponder(textField)

            if let text = textToInsert {
                if let editor = window.fieldEditor(true, for: textField) as? NSTextView {
                    editor.insertText(text, replacementRange: editor.selectedRange)
                }
            }
        }
    }

    // ✅ CL027_2: Helper for Visual Shortcut
    private func getShortcut(for index: Int) -> String? {
        guard index < 9 else { return nil }  // Only support 1-9

        let modifierRaw = settings.popupQuickSelectModifierFlags
        let modifier = NSEvent.ModifierFlags(rawValue: UInt(modifierRaw))

        var symbol = ""
        if modifier.contains(.command) {
            symbol = "⌘"
        } else if modifier.contains(.option) {
            symbol = "⌥"
        } else if modifier.contains(.control) {
            symbol = "⌃"
        } else if modifier.contains(.shift) {
            symbol = "⇧"
        }

        return "\(symbol)\(index + 1)"
    }

    // 헬퍼: KeyEquivalent 생성
    private func getSwiftUIKeyEquivalent(for index: Int) -> KeyEquivalent {
        let keys: [KeyEquivalent] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        return keys[index]
    }

    // 헬퍼: SwiftUI EventModifiers 변환
    private func getSwiftUIModifiers() -> EventModifiers {
        let modifierRaw = settings.popupQuickSelectModifierFlags
        let nsModifier = NSEvent.ModifierFlags(rawValue: UInt(modifierRaw))

        var modifiers = EventModifiers()
        if nsModifier.contains(.command) { modifiers.insert(.command) }
        if nsModifier.contains(.option) { modifiers.insert(.option) }
        if nsModifier.contains(.control) { modifiers.insert(.control) }
        if nsModifier.contains(.shift) { modifiers.insert(.shift) }

        return modifiers
    }

    private func getModifierSymbol() -> String {
        let modifierRaw = settings.popupQuickSelectModifierFlags
        let modifier = NSEvent.ModifierFlags(rawValue: UInt(modifierRaw))

        if modifier.contains(.command) {
            return "⌘"
        } else if modifier.contains(.option) {
            return "⌥"
        } else if modifier.contains(.control) {
            return "⌃"
        } else if modifier.contains(.shift) {
            return "⇧"
        }
        return ""
    }

    private func confirmSelection(_ item: ClipboardItem) {
        if viewModel.selectedIds.count > 1 && viewModel.selectedIds.contains(item.id ?? -1) {
            viewModel.copySelectedItems()
        } else {
            viewModel.copyToClipboard(item: item)
        }
        closeViewer()
    }

    private func closeViewer() {
        HistoryViewerManager.shared.hideAndPaste()
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text(
                    String(
                        format: NSLocalizedString("viewer.footer.items", comment: ""),
                        viewModel.items.count)
                )
                .font(.caption2)
                .foregroundColor(.secondary)

                // CL098: Display Search Duration
                if viewModel.searchDuration > 0.01 {
                    Text(String(format: "(%.2fs)", viewModel.searchDuration))
                        .font(.caption2)
                        .foregroundColor(
                            viewModel.searchDuration > 0.5 ? .orange : .secondary.opacity(0.7))
                }

                if !viewModel.selectedIds.isEmpty {
                    Text(
                        " • \(String(format: NSLocalizedString("viewer.footer.selected", comment: ""), viewModel.selectedIds.count))"
                    )
                    .font(.caption2)
                    .foregroundColor(.blue)
                }

                // Pause Toggle
                Button(action: { viewModel.togglePause() }) {
                    HStack(spacing: 4) {
                        Image(
                            systemName: viewModel.isPaused
                                ? "pause.circle.fill" : "play.circle.fill")
                        Text(
                            viewModel.isPaused
                                ? NSLocalizedString("viewer.status.paused", comment: "")
                                : NSLocalizedString("viewer.status.active", comment: ""))
                    }
                    .font(.caption2.bold())
                    .foregroundColor(viewModel.isPaused ? .red : .green)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
                .instantTooltip(
                    viewModel.isPaused
                        ? NSLocalizedString("viewer.help.resume", comment: "")
                        : NSLocalizedString("viewer.help.pause", comment: ""))

                Spacer()
                Spacer()

                // ✅ Issue 356: Help Icon with Popover
                Button(action: { showingHelpPopover.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingHelpPopover, arrowEdge: .top) {
                    helpPopoverContent
                        .padding()
                }
                .instantTooltip("Show Keyboard Shortcuts")

                // 개별 로우에 버튼이 있으므로 하단 버튼은 유지하되 다중 선택 시에만 유용하게 작동함
                if viewModel.selectedIds.count > 1 {
                    Button(action: { viewModel.deleteSelectedItems() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)
                    .instantTooltip("alert.common.delete")
                }

                // CL066: Filtered Delete Button
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.prepareFilteredDelete() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.slash")
                            Text("viewer.button.delete_matches")
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 12)
                    .instantTooltip("viewer.help.delete_matches")
                }
            }
            .padding(.top, 4)  // Reduced top padding
            .padding(.bottom, 0)  // ✅ CL069: Zero bottom padding
            .padding(.horizontal, 12)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))  // Native Look
        }
    }

    // ✅ Issue 356: Help Popover Content
    private var helpPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("viewer.help.shortcuts")
                .font(.headline)
                .padding(.bottom, 4)

            Group {
                shortcutRow(
                    key: NSLocalizedString("viewer.key.tab", comment: ""),
                    action: NSLocalizedString("viewer.action.preview_edit", comment: ""))
                shortcutRow(
                    key: NSLocalizedString("viewer.key.enter", comment: ""),
                    action: NSLocalizedString("viewer.action.copy_paste", comment: ""))
                shortcutRow(
                    key: "\(getModifierSymbol())1-9",
                    action: NSLocalizedString("viewer.action.quick_select", comment: ""))
                shortcutRow(
                    key: NSLocalizedString("viewer.key.backspace", comment: ""),
                    action: NSLocalizedString("viewer.action.delete", comment: ""))
            }

            Group {
                shortcutRow(
                    key: settings.historyRegisterSnippetHotkey.displayString,
                    action: NSLocalizedString("viewer.action.register", comment: ""))
                shortcutRow(
                    key: settings.historyPauseHotkey.displayString,
                    action: NSLocalizedString("viewer.action.toggle_pause", comment: ""))
                shortcutRow(
                    key: NSLocalizedString("viewer.key.esc", comment: ""),
                    action: NSLocalizedString("viewer.action.close", comment: ""))
            }
        }
        .fixedSize()
    }

    private func shortcutRow(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .fontWeight(.bold)
                .frame(width: 80, alignment: .trailing)
            Text(":")
            Text(action)
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }
}

struct HistoryViewer_Previews: PreviewProvider {
    static var previews: some View {
        HistoryViewer(viewModel: HistoryViewModel())
    }
}
