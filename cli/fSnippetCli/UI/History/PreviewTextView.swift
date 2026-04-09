import SwiftUI
import Cocoa

struct PreviewTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    @Binding var shouldSelectFirstLine: Bool
    @Binding var hasSelection: Bool
    
    var onEscape: (Int) -> Void
    var onCommit: (String?) -> Void // Cmd+Enter (Edit Mode) - Optional partial text
    var onSave: ((String) -> Void)? // Cmd+S (Edit Mode - Save without Paste) -- CL045_10
    var onEnter: ((String) -> Void)? // Enter (View Mode - Paste Selection)
    var onTab: (() -> Void)? // Tab (View Mode -> Edit Mode)
    var onShiftTab: (() -> Void)? // Shift+Tab (Back to List)
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textView = CustomKeyEventTextView()
        textView.delegate = context.coordinator
        textView.onEscape = { range in
            onEscape(range.location)
        }
        textView.onCommit = onCommit
        textView.onSave = onSave
        
        // Initial setup
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .controlTextColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // If it starts as editable, attempt to grab focus when it appears
        if isEditable {
            DispatchQueue.main.async {
                self.attemptFocus(for: textView, retryCount: 5)
            }
        }
        
        scrollView.documentView = textView
        return scrollView
    }
    
    // Helper to attempt focusing the text view
    private func attemptFocus(for textView: NSTextView, retryCount: Int) {
        guard retryCount > 0 else {
            logE("📄 👁 [PreviewTextView] Focus FAILED after retries")
            return
        }
        
        if let window = textView.window {
            if window.isVisible {
                if window.firstResponder == textView {
                    logD("📄 [PreviewTextView] Focus ALREADY set")
                    return
                }
                
                if window.makeFirstResponder(textView) {
                    logD("📄 [PreviewTextView] Focus SET successfully (Retry: \(5 - retryCount))")
                    return
                }
            } else {
                 logW("📄 👁 [PreviewTextView] Window is not visible yet (Retry: \(5 - retryCount))")
            }
        } else {
            logW("📄 👁 [PreviewTextView] Window is NIL (Retry: \(5 - retryCount))")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.attemptFocus(for: textView, retryCount: retryCount - 1)
        }
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
            // Update key handler delegates if needed
            if let customTV = textView as? CustomKeyEventTextView {
                customTV.isEditableMode = isEditable
                customTV.onEnter = onEnter
                customTV.onSave = onSave
            }
            
            // CL052: Enhanced Direct Edit Focus Logic
            if isEditable {
                DispatchQueue.main.async {
                    self.attemptFocus(for: textView, retryCount: 5)
                }
            }
        } else {
             // Even if isEditable hasn't changed, update callbacks in case closures changed
             if let customTV = textView as? CustomKeyEventTextView {
                 customTV.onEnter = onEnter
                 customTV.onSave = onSave
             }
        }
        
        if textView.string != text {
            textView.string = text
            // Need to update coordinator's copy? No, binding handles it.
        }
        
        // CL055: Apply Initial Cursor Position (Post-Text Update & Async Scroll)
        if isEditable, let initialIndex = HistoryPreviewState.shared.initialCursorIndex {
            logD("📄 [PreviewTextView] Applying Initial Cursor Index (Post-Update): \(initialIndex)")
            
            // Validate index against current text length
            if initialIndex >= 0 && initialIndex <= textView.string.count {
                // Set selection immediately (Storage-based)
                textView.setSelectedRange(NSRange(location: initialIndex, length: 0))
                
                // Scroll async to allow layout (Layout-based)
                DispatchQueue.main.async {
                    textView.scrollRangeToVisible(NSRange(location: initialIndex, length: 0))
                }
            } else {
                 logW("📄 👁 [PreviewTextView] Initial index \(initialIndex) out of bounds (count: \(textView.string.count))")
            }
                // Clear consumption (Async to avoid view update cycle warning)
                DispatchQueue.main.async {
                    HistoryPreviewState.shared.initialCursorIndex = nil
                }
            }
        
        // Auto-select first line if requested
        if shouldSelectFirstLine {
            DispatchQueue.main.async {
                if let _ = textView.layoutManager,
                   let _ = textView.textContainer {
                    let range = (textView.string as NSString).paragraphRange(for: NSRange(location: 0, length: 0))
                    textView.setSelectedRange(range)
                    // Reset trigger via binding wrapper? 
                    // Can't mutate binding directly easily in updateNSView without state loop?
                    // Actually we can, but let's do it via coordinator or parent.
                    // Ideally parent resets it, but parent doesn't know when view updated.
                    // We can use a Task or async.
                    
                    // Actually, let's just do it here and assume parent observes change if we use binding properly.
                    // But we can't assign to binding in updateNSView easily if it triggers update.
                    // Let's rely on Coordinator or just do it.
                }
            }
            // Reset trigger (Must be done carefully)
            // We'll leave it to parent or use a separate mechanism.
            // Or better: use a Coordinator method.
            context.coordinator.selectFirstLine(textView: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PreviewTextView
        
        init(_ parent: PreviewTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let hasSel = textView.selectedRange().length > 0
            if parent.hasSelection != hasSel {
                // Determine if we need to dispatch to main logic or binding handles it safely
                // Binding writes might warn if done during view update, but delegate is fine.
                // Safest to do async if erratic, but usually direct set is fine in delegate.
                DispatchQueue.main.async {
                    self.parent.hasSelection = hasSel
                }
            }
        }
        
        func selectFirstLine(textView: NSTextView) {
            // Check if we need to select title
            // Use paragraphRange for first line
            let string = textView.string as NSString
            if string.length > 0 {
                let range = string.paragraphRange(for: NSRange(location: 0, length: 0))
                textView.setSelectedRange(range)
            }
            
            // Reset trigger
            DispatchQueue.main.async {
                self.parent.shouldSelectFirstLine = false
            }
        }
    }
}

class CustomKeyEventTextView: NSTextView {
    var onEscape: ((NSRange) -> Void)?
    var onCommit: ((String?) -> Void)? // Cmd+Enter (Edit Mode) - Passes optional selected text
    var onEnter: ((String) -> Void)? // Enter (for Paste Selection)
    var onSave: ((String) -> Void)? // Cmd+S (Edit Mode - Save without Paste) -- CL045_10
    // Tab/ShiftTab managed by Window Event Monitor
    var isEditableMode: Bool = true
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Cmd+S (Save)
        if event.keyCode == 1 && event.modifierFlags.contains(.command) { // S is keycode 1
            let string = self.string
            onSave?(string)
            return
        }
        
        // Esc (53)
        if event.keyCode == 53 {
            onEscape?(self.selectedRange())
            return // Consume event
        }
        
        // Enter (36)
        if event.keyCode == 36 {
            let isCmd = event.modifierFlags.contains(.command)
            if isCmd {
                // Cmd+Enter
                // Check if there is a selection
                let selectedRange = self.selectedRange()
                let string = self.string as NSString
                
                if selectedRange.length > 0 {
                    // Partial Paste - Safety Check
                    if selectedRange.location + selectedRange.length <= string.length {
                        let selectedText = string.substring(with: selectedRange)
                        onCommit?(selectedText)
                    } else {
                        // Fallback: Full Paste or Log Error?
                        // Just commit empty? Or fallback to full logic?
                        // Let's fallback to nil (Full Paste) for safety
                        onCommit?(nil)
                    }
                } else {
                    // Full Paste (Save & Paste)
                    onCommit?(nil)
                }
                return
            }
            
            // If NOT editable (Interaction Mode), Enter pastes selection
            if !isEditableMode {
                // Get selected text
                let selectedRange = self.selectedRange()
                let text = (self.string as NSString).substring(with: selectedRange)
                onEnter?(text)
                return
            }
        }
        
        // Select All (Cmd+A) - KeyCode 0
        if event.keyCode == 0 && event.modifierFlags.contains(.command) {
            self.selectAll(nil)
            return
        }
        

        
        super.keyDown(with: event)
    }
    

}
