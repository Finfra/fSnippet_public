import AppKit
import Foundation

/// Centralized source of truth for Key Mapping definitions.
/// Used by ShortcutMgr, KeyRenderingManager, TriggerKeyManager, etc.
/// Based on `design_keyProcess.md`
/// Used by `SingleShortcutMapper`
struct SharedKeyMap {

    struct KeyDefinition {
        let name: String
        let code: UInt16
        let symbol: String
        let visualCount: Int
        let description: String
    }

    static let definitions: [KeyDefinition] = [
        // Right Modifiers
        KeyDefinition(
            name: "right_command", code: 54, symbol: "➡️⌘", visualCount: 0,
            description: "오른쪽 Command 키"),
        KeyDefinition(
            name: "right_option", code: 61, symbol: "➡️⌥", visualCount: 0,
            description: "오른쪽 Option 키"),
        KeyDefinition(
            name: "right_shift", code: 60, symbol: "➡️⇧", visualCount: 0, description: "오른쪽 Shift 키"),
        KeyDefinition(
            name: "right_control", code: 62, symbol: "➡️⌃", visualCount: 0,
            description: "오른쪽 Control 키"),
        KeyDefinition(name: "fn", code: 63, symbol: "Fn", visualCount: 0, description: "Fn키"),

        // Keypad Keys
        KeyDefinition(
            name: "keypad_num_lock", code: 71, symbol: "🔢", visualCount: 0,
            description: "Num Lock 키"),
        KeyDefinition(
            name: "keypad_equals", code: 81, symbol: "🔢=", visualCount: 1, description: "키패드 등호 (=)"
        ),
        KeyDefinition(
            name: "keypad_comma", code: 95, symbol: "🔢﹐", visualCount: 0, description: "키패드 쉼표 (,)"),
        KeyDefinition(
            name: "keypad_0", code: 82, symbol: "0️⃣", visualCount: 1, description: "키패드 0"),
        KeyDefinition(
            name: "keypad_1", code: 83, symbol: "1️⃣", visualCount: 1, description: "키패드 1"),
        KeyDefinition(
            name: "keypad_2", code: 84, symbol: "2️⃣", visualCount: 1, description: "키패드 2"),
        KeyDefinition(
            name: "keypad_3", code: 85, symbol: "3️⃣", visualCount: 1, description: "키패드 3"),
        KeyDefinition(
            name: "keypad_4", code: 86, symbol: "4️⃣", visualCount: 1, description: "키패드 4"),
        KeyDefinition(
            name: "keypad_5", code: 87, symbol: "5️⃣", visualCount: 1, description: "키패드 5"),
        KeyDefinition(
            name: "keypad_6", code: 88, symbol: "6️⃣", visualCount: 1, description: "키패드 6"),
        KeyDefinition(
            name: "keypad_7", code: 89, symbol: "7️⃣", visualCount: 1, description: "키패드 7"),
        KeyDefinition(
            name: "keypad_8", code: 91, symbol: "8️⃣", visualCount: 1, description: "키패드 8"),
        KeyDefinition(
            name: "keypad_9", code: 92, symbol: "9️⃣", visualCount: 1, description: "키패드 9"),

        KeyDefinition(
            name: "keypad_period", code: 65, symbol: "🔢·", visualCount: 1, description: "키패드 점 (.)"),
        KeyDefinition(
            name: "keypad_plus", code: 69, symbol: "🔢+", visualCount: 1, description: "키패드 더하기 (+)"),
        KeyDefinition(
            name: "keypad_minus", code: 78, symbol: "🔢-", visualCount: 1, description: "키패드 빼기 (-)"),
        KeyDefinition(
            name: "keypad_multiply", code: 67, symbol: "🔢*", visualCount: 1,
            description: "키패드 곱하기 (*)"),
        KeyDefinition(
            name: "keypad_divide", code: 75, symbol: "🔢/", visualCount: 1,
            description: "키패드 나누기 (/)"),
        KeyDefinition(
            name: "keypad_enter", code: 76, symbol: "🔢⏎", visualCount: 1,
            description: "키패드 엔터 (Enter)"),
        KeyDefinition(
            name: "semicolon", code: 41, symbol: ";", visualCount: 1, description: "Semicolon (;)"),  // Issue 513_2

        // Function Keys
        KeyDefinition(name: "f1", code: 122, symbol: "F1", visualCount: 0, description: "F1"),
        KeyDefinition(name: "f2", code: 120, symbol: "F2", visualCount: 0, description: "F2"),
        KeyDefinition(name: "f3", code: 99, symbol: "F3", visualCount: 0, description: "F3"),
        KeyDefinition(name: "f4", code: 118, symbol: "F4", visualCount: 0, description: "F4"),
        KeyDefinition(name: "f5", code: 96, symbol: "F5", visualCount: 0, description: "F5"),
        KeyDefinition(name: "f6", code: 97, symbol: "F6", visualCount: 0, description: "F6"),
        KeyDefinition(name: "f7", code: 98, symbol: "F7", visualCount: 0, description: "F7"),
        KeyDefinition(name: "f8", code: 100, symbol: "F8", visualCount: 0, description: "F8"),
        KeyDefinition(name: "f9", code: 101, symbol: "F9", visualCount: 0, description: "F9"),
        KeyDefinition(name: "f10", code: 109, symbol: "F10", visualCount: 0, description: "F10"),
        KeyDefinition(name: "f11", code: 103, symbol: "F11", visualCount: 0, description: "F11"),
        KeyDefinition(name: "f12", code: 111, symbol: "F12", visualCount: 0, description: "F12"),
        KeyDefinition(name: "f13", code: 105, symbol: "F13", visualCount: 0, description: "F13"),
        KeyDefinition(name: "f14", code: 107, symbol: "F14", visualCount: 0, description: "F14"),
        KeyDefinition(name: "f15", code: 113, symbol: "F15", visualCount: 0, description: "F15"),
        KeyDefinition(name: "f16", code: 106, symbol: "F16", visualCount: 0, description: "F16"),
        KeyDefinition(name: "f17", code: 64, symbol: "F17", visualCount: 0, description: "F17"),
        KeyDefinition(name: "f18", code: 79, symbol: "F18", visualCount: 0, description: "F18"),
        KeyDefinition(name: "f19", code: 80, symbol: "F19", visualCount: 0, description: "F19"),

        // Navigation & Editing Keys
        KeyDefinition(
            name: "insert", code: 114, symbol: "Ins", visualCount: 0, description: "Insert (Help)"),
        KeyDefinition(
            name: "delete_forward", code: 117, symbol: "⌦", visualCount: 0,
            description: "Forward Delete"),
        KeyDefinition(name: "home", code: 115, symbol: "↖", visualCount: 0, description: "Home"),
        KeyDefinition(name: "end", code: 119, symbol: "↘", visualCount: 0, description: "End"),
        KeyDefinition(
            name: "pageup", code: 116, symbol: "⇞", visualCount: 0, description: "Page Up"),
        KeyDefinition(
            name: "pagedown", code: 121, symbol: "⇟", visualCount: 0, description: "Page Down"),
    ]

    // MARK: - Computed Mappings

    /// KeyCode -> Unified Name (e.g. 82 -> "keypad_0")
    /// Issue651: static var → static let 으로 변경 (앱 기동 시 1회만 초기화, 매 접근마다 재계산 방지)
    static let numpadMapping: [UInt16: String] = {
        var map: [UInt16: String] = [:]
        for def in definitions {
            map[def.code] = def.name
        }
        return map
    }()

    /// Unified Name -> Symbol (e.g. "keypad_0" -> "0️⃣")
    /// Issue651: static let으로 변경 (1회 초기화)
    static let symbolMapping: [String: String] = {
        var map: [String: String] = [:]
        for def in definitions {
            map[def.name] = def.symbol
        }
        return map
    }()

    /// Unified Name -> [KeyCode] (e.g. "keypad_0" -> [82])
    /// Used for reverse lookups in ShortcutMgr/TriggerKeyManager
    /// Issue651: static let으로 변경 (1회 초기화)
    static let reverseMapping: [String: [UInt16]] = {
        var map: [String: [UInt16]] = [:]
        for def in definitions {
            if map[def.name] != nil {
                map[def.name]?.append(def.code)
            } else {
                map[def.name] = [def.code]
            }
        }
        return map
    }()

    /// Unified Name -> Visual Count (e.g. "keypad_0" -> 1, "keypad_equals" -> 0)
    /// Issue651: static let으로 변경 (1회 초기화)
    static let visualWidths: [String: Int] = {
        var map: [String: Int] = [:]
        for def in definitions {
            map[def.name] = def.visualCount
        }
        return map
    }()

    // Legacy support for older SharedKeyMap.numpadKeyCodes access pattern, mapped to new system
    // Issue651: numpadMapping/reverseMapping이 static let이므로 이중 계산 없음
    static var numpadKeyCodes: [UInt16: String] {
        return numpadMapping
    }

    static var reverseNumpadKeyCodes: [String: [UInt16]] {
        return reverseMapping
    }

    // MARK: - Standard Key Names (Fallback)
    // Moved from ShortcutInputView.swift to enforce SSOT
    static let standardKeyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "[Return]", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "[Tab]", 49: "Space", 50: "`", 51: "[Backspace]", 53: "[Escape]",
        54: "➡️⌘", 55: "⌘", 56: "⇧", 57: "⇪", 58: "⌥", 59: "⌃", 60: "⇧", 61: "➡️⌥", 62: "➡️⌃",
        63: "Fn",
    ]
    // MARK: - Option Key Mapping (Issue 524)

    /// Returns the character produced by Option + KeyCode combination
    /// Based on `design_keyProcess.md` standardization
    static func getOptionKeyCharacter(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String?
    {
        guard modifiers.contains(.option) else { return nil }
        let isShift = modifiers.contains(.shift)

        switch keyCode {
        // 숫자 키 및 기호
        case 18: return isShift ? "⁄" : "¡"  // 1
        case 19: return isShift ? "€" : "™"  // 2
        case 20: return isShift ? "‹" : "£"  // 3
        case 21: return isShift ? "›" : "¢"  // 4
        case 23: return isShift ? "ﬁ" : "∞"  // 5
        case 22: return isShift ? "ﬂ" : "§"  // 6
        case 26: return isShift ? "‡" : "¶"  // 7
        case 28: return isShift ? "°" : "•"  // 8
        case 25: return isShift ? "·" : "ª"  // 9
        case 29: return isShift ? "‚" : "º"  // 0
        case 27: return isShift ? "—" : "–"  // -
        case 24: return isShift ? "±" : "≠"  // =

        // QWERTY 상단
        case 12: return isShift ? "Œ" : "œ"  // Q
        case 13: return isShift ? "„" : "∑"  // W
        // case 14: return "?"                // E (Dead Key)
        case 15: return isShift ? "‰" : "®"  // R
        case 17: return isShift ? "ˇ" : "†"  // T
        case 16: return isShift ? "Á" : "¥"  // Y
        // case 32: return "?"                // U (Dead Key)
        // case 34: return "?"                // I (Dead Key)
        case 31: return isShift ? "Ø" : "ø"  // O
        case 35: return isShift ? "∏" : "π"  // P
        case 33: return isShift ? "”" : "“"  // [
        case 30: return isShift ? "’" : "”"  // ]
        case 42: return isShift ? "»" : "«"  // \

        // QWERTY 중간
        case 0: return isShift ? "Å" : "å"  // A
        case 1: return isShift ? "Í" : "ß"  // S
        case 2: return isShift ? "Î" : "∂"  // D
        case 3: return isShift ? "Ï" : "ƒ"  // F
        case 5: return isShift ? "˝" : "©"  // G
        case 4: return isShift ? "Ó" : "˙"  // H
        case 38: return isShift ? "Ô" : "∆"  // J
        case 40: return isShift ? "" : "˚"  // K
        case 37: return isShift ? "Ò" : "¬"  // L
        case 41: return isShift ? "Ú" : "…"  // ;
        case 39: return isShift ? "Æ" : "æ"  // '

        // QWERTY 하단
        case 6: return isShift ? "¸" : "Ω"  // Z
        case 7: return isShift ? "˛" : "≈"  // X
        case 8: return isShift ? "Ç" : "ç"  // C
        case 9: return isShift ? "◊" : "√"  // V
        case 11: return isShift ? "ı" : "∫"  // B
        // case 45: return "?"                // N (Dead Key)
        case 46: return isShift ? "Â" : "µ"  // M
        case 43: return isShift ? "¯" : "≤"  // ,
        case 47: return isShift ? "˘" : "≥"  // .
        case 44: return isShift ? "¿" : "÷"  // /

        // Dead Key Cases (주황색 키) - return nil to let system handle or bypass
        // case 50: // Grave (`)
        // case 14: // E
        // case 32: // U
        // case 34: // I
        // case 45: // N

        default:
            return nil
        }
    }
}
