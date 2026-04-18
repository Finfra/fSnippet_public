import Foundation

/// SingleShortcutMapper
///
/// Unified encoder/decoder for Single Keywords (Single Shortcuts).
/// Uses `SharedKeyMap` as the Single Source of Truth to provide mapping between:
/// - Key Name (e.g. "keypad_comma", "f1")
/// - Key Code (e.g. 95, 122)
/// - Symbol (e.g. "🔢,", "F1")
/// - Visual Count (e.g. 0, 1)
/// - Description
///
/// Ref: _doc_design/key-event/design_keyProcess.md
class SingleShortcutMapper {

    static let shared = SingleShortcutMapper()

    private init() {}

    // MARK: - Core Retrieval

    /// Get the full KeyDefinition by Key Name (e.g., "keypad_comma", "{f1}")
    /// Handles partial inputs (braced or unbraced).
    func getDefinition(for keyName: String) -> SharedKeyMap.KeyDefinition? {
        let normalized = unwrap(keyName)
        return SharedKeyMap.definitions.first { $0.name == normalized }
    }

    /// Get the full KeyDefinition by Key Code
    func getDefinition(for keyCode: UInt16) -> SharedKeyMap.KeyDefinition? {
        // Handle overlapping codes (e.g., NumLock vs Clear both 71) by precedence in array
        return SharedKeyMap.definitions.first { $0.code == keyCode }
    }

    // MARK: - Attribute Accessors (Helpers)

    /// Get display symbol (e.g., "f1" -> "F1", "{keypad_comma}" -> "🔢,")
    func getSymbol(for keyName: String) -> String? {
        return getDefinition(for: keyName)?.symbol
    }

    /// Get visual count (e.g., "keypad_1" -> 1, "f1" -> 0)
    func getVisualCount(for keyName: String) -> Int {
        logD("⇄ getVisualCount(for: \(keyName))")
        return getDefinition(for: keyName)?.visualCount ?? 0
    }

    /// Get key code (e.g., "f1" -> 122)
    func getKeyCode(for keyName: String) -> UInt16? {
        return getDefinition(for: keyName)?.code
    }

    /// Get human readable description
    func getDescription(for keyName: String) -> String? {
        return getDefinition(for: keyName)?.description
    }

    // MARK: - Utility

    /// Remove curly braces if present (e.g., "{f1}" -> "f1")
    /// Centralized unwrap logic.
    func unwrap(_ keyName: String) -> String {
        if keyName.hasPrefix("{") && keyName.hasSuffix("}") && keyName.count > 2 {
            return String(keyName.dropFirst().dropLast())
        }
        return keyName
    }

    /// Check if a keyName corresponds to a valid Single Shortcut
    func isValidSingleShortcut(_ keyName: String) -> Bool {
        return getDefinition(for: keyName) != nil
    }

    // MARK: - Component Priority (Issue 562)

    enum ComponentPriority: Int, Comparable {
        case single = 1  // Highest (e.g. {keypad_comma})
        case function = 2  // Medium (e.g. {f1})
        case string = 3  // Lowest (e.g. "aa")

        static func < (lhs: ComponentPriority, rhs: ComponentPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    /// Determine the component type priority for a given key name
    func getComponentPriority(for keyName: String) -> ComponentPriority {
        // 1. Single Shortcut Check
        if let def = getDefinition(for: keyName) {
            // Function Keys are usually defined as Single Shortcuts too,
            // but we might want to distinguish them if needed.
            // For now, let's treat all defined Single Shortcuts as 'single' or 'function'.

            if def.name.hasPrefix("f") && Int(def.name.dropFirst()) != nil {
                return .function
            }
            return .single
        }

        // 2. Fallback to String
        return .string
    }

    // MARK: - Key Label Resolution (SSOT)

    /// Get unified key name for a key code (e.g. 0 -> "A", 95 -> "keypad_comma")
    /// Uses SharedKeyMap.definitions first, then SharedKeyMap.standardKeyNames.
    func getKeyLabel(for keyCode: UInt16) -> String {
        // 1. Try Special Definition (SSOT Priority)
        // e.g. 95 -> "keypad_comma"
        if let def = getDefinition(for: keyCode) {
            return def.name
        }

        // 2. Try Standard Map (Fallback)
        // e.g. 0 -> "A"
        return SharedKeyMap.standardKeyNames[keyCode] ?? "?"
    }
}
