import SwiftUI
import AppKit

struct HistorySearchBar: View {
    @Binding var text: String
    var onCancel: () -> Void
    
    // CL078: Filter Bindings
    @Binding var selectedFilter: HistoryViewModel.FilterOption
    var availableApps: [String]
    
    // CL078: Filter Focus State (Hoisted)
    var isFilterFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            FocusAwareTextField(
                text: $text,
                placeholder: NSLocalizedString("history.search.placeholder", comment: "Search placeholder"),
                onExitCommand: onCancel
            )
            .frame(height: 20) // Ensure consistent height with previous layout
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // CL078: Filter Picker (Moved to right)
            Menu {
                Button(action: { selectedFilter = .all }) {
                    if selectedFilter == .all {
                        Label(NSLocalizedString("history.filter.all", comment: ""), systemImage: "checkmark")
                    } else {
                        Label(NSLocalizedString("history.filter.all", comment: ""), systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                Button(action: { selectedFilter = .images }) {
                    if selectedFilter == .images {
                        Label(NSLocalizedString("history.filter.images", comment: ""), systemImage: "checkmark")
                    } else {
                        Label(NSLocalizedString("history.filter.images", comment: ""), systemImage: "photo")
                    }
                }
                
                if !availableApps.isEmpty {
                    Divider()
                    Text(NSLocalizedString("history.filter.apps", comment: ""))
                    ForEach(availableApps, id: \.self) { appBundle in
                        Button(action: { selectedFilter = .app(appBundle) }) {
                            HStack {
                                if case .app(let b) = selectedFilter, b == appBundle {
                                    Image(systemName: "checkmark")
                                }
                                
                                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appBundle) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path))
                                    Text(appUrl.deletingPathExtension().lastPathComponent)
                                } else {
                                    Image(systemName: "app.badge")
                                    Text(appBundle.components(separatedBy: ".").last?.capitalized ?? appBundle)
                                }
                            }
                        }
                    }
                }
            } label: {
                Group {
                    if case .app(let bundleId) = selectedFilter,
                       let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: selectedFilter.iconName)
                            .foregroundColor(selectedFilter == .all ? .secondary : .accentColor)
                            .frame(width: 16)
                    }
                }
                .padding(.leading, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isFilterFocused.wrappedValue ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            .focused(isFilterFocused)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)

    }
}

// MARK: - Components

struct FocusAwareTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void = {}
    var onExitCommand: () -> Void = {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.placeholderString = placeholder
        textField.font = .systemFont(ofSize: 14)
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.onAction(_:))
        textField.tag = 987654 // CL085: Unique Tag for Force Focus Lookup
        
        return textField
    }
    
    func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        // Refinement 13: Guard Stale Updates
        // Prevent stale empty binding from wiping user input and killing focus
        if nsView.isFirstResponder && !nsView.stringValue.isEmpty && text.isEmpty {
            logD("🔍 [HistorySearchBar] Ignoring stale empty binding update while active.")
            return
        }
        
        // Update text content
        if nsView.stringValue != text {
            // CL085 Refinement 12: Preserve Editing Session
            // Setting `stringValue` directly aborts editing (detaches Field Editor).
            // If we are already editing (even just started via Direct Insertion), update editor directly.
            if let editor = nsView.currentEditor() {
                let range = NSRange(location: 0, length: editor.string.count)
                editor.replaceCharacters(in: range, with: text)
                
                logD("🔍 [HistorySearchBar] Updated active editor content via replaceCharacters")
                
                // Confirm cursor at end (Async to allow layout pass)
                DispatchQueue.main.async {
                     nsView.currentEditor()?.selectedRange = NSMakeRange(text.count, 0)
                }
            } else {
                nsView.stringValue = text
            }
        }
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusAwareTextField
        
        init(_ parent: FocusAwareTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onExitCommand()
                return true
            }
            return false
        }
        
        @objc func onAction(_ sender: Any) {
            parent.onCommit()
        }
    }
}

class CustomNSTextField: NSTextField {
    // Removed unnecessary binding callback (onFocusChange) logic
    
    var isFirstResponder: Bool {
        guard let window = self.window else { return false }
        return window.firstResponder == self || window.firstResponder == self.currentEditor()
    }

    // Crucial fix for CL088: Move cursor to end when becoming first responder
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        
        if success {
            if let editor = currentEditor() {
                editor.selectedRange = NSMakeRange(editor.string.count, 0)
            }
        }
        return success
    }
}
