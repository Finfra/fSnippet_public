import SwiftUI
import Combine

class HistoryPreviewState: ObservableObject {
    static let shared = HistoryPreviewState()
    
    // NOTE: isEditing and isInteractive are now derived from ClipboardManager.shared.chvMode
    // Views should observe ClipboardManager.shared.chvMode
    
    @Published var currentText: String = "" {
        didSet {
            // CL048: Automatically sync lines whenever text changes
            self.lines = self.currentText.components(separatedBy: .newlines)
        }
    }
    @Published var currentItem: ClipboardItem?
    
    // CL048: Line-based rendering support
    @Published var lines: [String] = []
    @Published var selectedLineIndices: Set<Int> = []

    @Published var shouldSelectFirstLine: Bool = false
    
    // CL048: Selection State
    @Published var focusLineIndex: Int = 0
    @Published var anchorLineIndex: Int? // For range selection (Shift+Arrow)
    
    // CL048_5: Cursor Sync for Edit Mode
    @Published var initialCursorIndex: Int? = nil

    // Helper properties for backward compatibility / convenience (Read-only)
    var isEditing: Bool {
        return ClipboardManager.shared.chvMode == .previewEdit
    }
    
    var isInteracting: Bool {
        return ClipboardManager.shared.chvMode == .previewView
    }
    
    // For syncing with original content
    func startEditing(item: ClipboardItem) {
        self.currentItem = item
        self.currentText = item.text ?? ""
        self.shouldSelectFirstLine = false
        
        // Update Global Mode
        DispatchQueue.main.async {
            ClipboardManager.shared.chvMode = .previewEdit
        }
    }
    
    func startInteracting(item: ClipboardItem) {
        self.currentItem = item
        self.currentText = item.text ?? ""
        
        // CL048: Split text into lines
        self.lines = self.currentText.components(separatedBy: .newlines)
        
        // Default selection (CL057: Safety Check)
        self.focusLineIndex = 0
        if !self.lines.isEmpty {
            self.selectedLineIndices = [0]
        } else {
            self.selectedLineIndices = []
        }
        self.anchorLineIndex = nil
        
        // shouldSelectFirstLine is for PreviewTextView (Edit Mode) - Disable here
        self.shouldSelectFirstLine = false
        
        // Update Global Mode
        DispatchQueue.main.async {
            ClipboardManager.shared.chvMode = .previewView
        }
    }
    
    func switchToInteractiveMode(preservingLine: Int? = nil) {
        // CL048: Refresh lines from currentText (which might have been edited)
        self.lines = self.currentText.components(separatedBy: .newlines)
        
        // Use preservingLine if provided, else 0
        let targetLine = preservingLine ?? 0
        let clampedLine = max(0, min(self.lines.count - 1, targetLine))
        
        self.focusLineIndex = clampedLine
        if !self.lines.isEmpty {
            self.selectedLineIndices = [clampedLine]
        } else {
            self.selectedLineIndices = []
        }
        self.anchorLineIndex = nil
        
        self.shouldSelectFirstLine = false
        
        // Update Global Mode
        DispatchQueue.main.async {
            ClipboardManager.shared.chvMode = .previewView
        }
    }
    
    func stopEditing() {
        self.shouldSelectFirstLine = false
        self.selectedLineIndices = []
        self.focusLineIndex = 0
        self.anchorLineIndex = nil
        self.initialCursorIndex = nil
        // Optional: clear currentText or keep it if we want to remember draft?
        // For now, let's keep it until next startEditing overwrites it.
        
        // Note: Global Mode update to .list should be handled by caller (HistoryPreviewManager.stopEditing)
        // because stopEditing logic here is just state cleanup.
        // But for consistency:
        // If we are strictly "stopping editing" we usually go back to View mode?
        // But HistoryPreviewManager.stopEditing usually implies closing preview or going back to list.
        // Let's leave mode change to Manager to be safe or explicit.
    }
    
    // CL048: Navigation Logic
    func moveSelection(direction: Int, extendSelection: Bool) {
        guard !lines.isEmpty else { return }
        
        let newIndex = max(0, min(lines.count - 1, focusLineIndex + direction))
        
        if newIndex == focusLineIndex { return } // Boundary reached
        
        focusLineIndex = newIndex
        
        if extendSelection {
            // Multi-selection
            if anchorLineIndex == nil {
                // Should not happen if logic is correct, but safe fallback:
                // If we started extending from a single selection, the OTHER end was the implicit anchor.
                // But typically anchor is set when we START selecting?
                // Actually, if we were single selected at index X, and press Shift+Down, 
                // X is the anchor, (X+1) is the new focus.
                
                // Wait, if anchor is nil, we assume the PREVIOUS focus was the anchor?
                // No, when single selection exists, anchor should probably be reset to current focus 
                // OR we set anchor when shift is pressed?
                // Let's assume: When switchToInteractiveMode or Click, we set anchor = focus.
                // Or: simpler logic:
                // If anchor is nil, it means we were in single selection mode.
                // The anchor should have been the previous focus.
                // But we already moved focus. 
                // Let's fix this: The Anchor should be established whenever we have a single selection really.
                
                // Let's rely on `selectedLineIndices` containing the "start".
                // But simplicity: Single selection => Anchor = Focus.
                
                // Retrospective fix: We need to know where we started range selection.
                // If anchor is nil, set it to the OLD focus (before move).
                // Actually, let's just say:
                // Single Selection Mode: Anchor = Index.
            }
            // If anchor was nil, set it to the OLD focusLineIndex (before update)?
            // It's easier if we ensure anchor is valid or infer it.
            // Let's check `selectedLineIndices`. If it has 1 element, that was the anchor.
            
            let anchor = anchorLineIndex ?? (focusLineIndex - direction) 
            // focusLineIndex is already NEW. So previous was focusLineIndex - direction.
            self.anchorLineIndex = anchor
            
            // Calculate range between anchor and new focus
            let lower = min(anchor, newIndex)
            let upper = max(anchor, newIndex)
            self.selectedLineIndices = Set(lower...upper)
            
        } else {
            // Single selection
            self.selectedLineIndices = [newIndex]
            self.anchorLineIndex = nil
        }
    }
    
    // CL048: Mouse Selection Logic
    func selectLine(index: Int, modifiers: NSEvent.ModifierFlags) {
        guard index >= 0 && index < lines.count else { return }
        
        let isShift = modifiers.contains(.shift)
        let isCmd = modifiers.contains(.command)
        
        if isCmd {
            // Toggle Selection
            if selectedLineIndices.contains(index) {
                selectedLineIndices.remove(index)
            } else {
                selectedLineIndices.insert(index)
            }
            // Update focus and anchor
            focusLineIndex = index
            anchorLineIndex = index
            
        } else if isShift {
            // Range Selection
            // If we have an anchor, select from anchor to current
            let anchor = anchorLineIndex ?? focusLineIndex
            
            let lower = min(anchor, index)
            let upper = max(anchor, index)
            
            // Standard OS behavior: Shift click replaces selection with the range
            // (unless Command is also held, but let's keep it simple: Shift implies range from anchor)
            self.selectedLineIndices = Set(lower...upper)
            
            // Focus moves to the clicked line, but anchor remains at the start
            self.focusLineIndex = index
            // Anchor is preserved (it's the pivot)
            self.anchorLineIndex = anchor
            
        } else {
            // Single Selection
            self.selectedLineIndices = [index]
            self.focusLineIndex = index
            self.anchorLineIndex = index
        }
    }
    
    // Issue347: Delete Selected Lines
    func deleteSelectedLines() -> Bool {
        guard !selectedLineIndices.isEmpty, !lines.isEmpty else { return false }
        
        // 1. Sort indices in descending order to remove safely
        let indicesToRemove = selectedLineIndices.sorted(by: >)
        
        // 2. Remove lines
        for index in indicesToRemove {
            if index < lines.count {
                lines.remove(at: index)
            }
        }
        
        // 3. Update currentText
        currentText = lines.joined(separator: "\n")
        
        // 4. Restore Selection logic
        // Try to select the line at the same position as the first deleted line (or the one before if we deleted the end)
        // If we deleted everything, clear selection
        if lines.isEmpty {
            selectedLineIndices = []
            focusLineIndex = 0
            anchorLineIndex = nil
        } else {
            // Logic: Select the smallest index that was deleted, clamping to new count
            // E.g. deleted 5, 6 -> select new 5 (which was old 7)
            // If deleted last line 9 -> select new 8 (last)
            
            let targetIndex = indicesToRemove.last ?? 0 // The 'first' index in visual order (since sorted desc) is `.last`
            let newSelectionIndex = min(targetIndex, lines.count - 1)
            
            selectedLineIndices = [newSelectionIndex]
            focusLineIndex = newSelectionIndex
            anchorLineIndex = newSelectionIndex
        }
        
        return true
    }
}
