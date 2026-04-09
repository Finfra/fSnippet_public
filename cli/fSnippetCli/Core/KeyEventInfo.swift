import ApplicationServices
import Cocoa
import Foundation

// MARK: - 키 이벤트 정보 구조체

/// 키 이벤트 정보를 담는 구조체
struct KeyEventInfo {
    enum KeyType {
        case regular  // 일반 문자
        case command  // 커맨드키 조합
        case control  // 컨트롤키 조합
        case option  // 옵션키 조합
        case navigation  // 화살표, 홈/엔드 등
        case function  // F1-F12
        case modifier  // 수정자 키만 눌림 (Shift, Cmd 등)
        case special  // 특수 문자 (공백, 엔터 등) - Added for compatibility
        case backspace  // 백스페이스 - Added for compatibility
    }

    let originalEvent: CGEvent?  // Optional, as some events might be synthetic
    let characters: String?
    let charactersIgnoringModifiers: String?
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let type: KeyType

    // 편의 속성
    var character: String? {
        // 엔터키 처리
        if keyCode == 36 || keyCode == 76 { return "\n" }
        return characters
    }

    // 디버깅용 설명
    var description: String {
        return "Key(code: \(keyCode), char: \(character ?? "nil"), mods: \(modifiers))"
    }

    // MARK: - Initializers

    // Standard Initializer
    init(
        originalEvent: CGEvent? = nil, characters: String? = nil,
        charactersIgnoringModifiers: String? = nil, keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags, type: KeyType
    ) {
        self.originalEvent = originalEvent
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.type = type
    }

    // CGEventFlags compatibility initializer (needed for KeyEventProcessor)
    init(type: KeyType, character: String?, keyCode: UInt16, modifiers: CGEventFlags) {
        self.type = type
        self.characters = character  // Map to characters (stored property)
        self.charactersIgnoringModifiers = character
        self.keyCode = keyCode
        self.originalEvent = nil

        // Convert CGEventFlags to NSEvent.ModifierFlags
        var nsFlags: NSEvent.ModifierFlags = []
        if modifiers.contains(.maskCommand) { nsFlags.insert(.command) }
        if modifiers.contains(.maskControl) { nsFlags.insert(.control) }
        if modifiers.contains(.maskAlternate) { nsFlags.insert(.option) }
        if modifiers.contains(.maskShift) { nsFlags.insert(.shift) }
        if modifiers.contains(.maskAlphaShift) { nsFlags.insert(.capsLock) }
        if modifiers.contains(.maskHelp) { nsFlags.insert(.help) }
        if modifiers.contains(.maskSecondaryFn) { nsFlags.insert(.function) }
        // Numeric pad?
        if modifiers.contains(.maskNumericPad) { nsFlags.insert(.numericPad) }

        self.modifiers = nsFlags
    }
}

extension KeyEventInfo {
    /// Normalizes the key event into a string representation (e.g., "^C", "right_command")
    /// Logic moved from KeyEventMonitor.normalizeKeySpec
    func normalizedKeySpec() -> String {
        // Issue 298: 오른쪽 수정자에 대한 상세 로직 (CGEventFlags 기반)
        let raw = self.modifiers.rawValue
        //logD("🗝️ normalizedKeySpec")
        // 마스크: RightCmd(0x10), RightShift(0x04), RightOpt(0x40), RightCtrl(0x2000)
        let hasRight =
            (raw & 0x10 != 0) || (raw & 0x04 != 0) || (raw & 0x40 != 0) || (raw & 0x2000 != 0)

        var spec = ""

        if hasRight {
            // 상세 구성: "right_command+left_shift+..."
            var parts: [String] = []

            // Command
            if self.modifiers.contains(.command) {
                parts.append((raw & 0x10) != 0 ? "right_command" : "left_command")
            }

            // Shift
            if self.modifiers.contains(.shift) {
                parts.append((raw & 0x04) != 0 ? "right_shift" : "left_shift")
            }

            // Option
            if self.modifiers.contains(.option) {
                parts.append((raw & 0x40) != 0 ? "right_option" : "left_option")
            }

            // Control
            if self.modifiers.contains(.control) {
                parts.append((raw & 0x2000) != 0 ? "right_control" : "left_control")
            }

            // Caps Lock
            if self.modifiers.contains(.capsLock) {
                parts.append("caps_lock")
            }

            spec = parts.joined(separator: "+")
            if !spec.isEmpty { spec += "+" }

        } else {
            // 표준 심볼 구성
            // 순서 설정: ^ ⌥ ⌘ ⇧

            // ✅ Issue 561: Option 키 단독 조합(또는 Option+Shift)의 경우,
            // SharedKeyMap에서 유효한 문자가 반환되면 Option modifier 심볼(⌥)을 생략하고 해당 문자를 반환해야 함.
            // 문자가 없는 경우에만 ⌥ 심볼을 추가.

            // Option check moved to inline check below
            let isOptionKeyStart = self.modifiers.contains(.option)
            let optionChar = isOptionKeyStart ? SharedKeyMap.getOptionKeyCharacter(
                                keyCode: self.keyCode, modifiers: self.modifiers) : nil

            if optionChar != nil {
                // Option 키 문자가 유효하면 ⌥ 심볼 생략 (Modifier 제거됨)
                // 다른 Modifier(Control, Command)가 있다면 여전히 추가해야 함.
                if self.modifiers.contains(.control) { spec += "^" }
                if self.modifiers.contains(.command) { spec += "⌘" }
                // Shift는 Option 키 문자 변환에 이미 사용되었으므로 생략 가능?
                // getOptionKeyCharacter는 modifiers를 받아 shift 여부를 처리함.
                // 따라서 여기서 shift 심볼도 생략해야 함.
            } else {
                // 일반적인 경우
                if self.modifiers.contains(.control) { spec += "^" }
                if self.modifiers.contains(.option) { spec += "⌥" }
                if self.modifiers.contains(.command) { spec += "⌘" }
                if self.modifiers.contains(.shift) { spec += "⇧" }
            }

            // 표준 심볼에 대한 CapsLock? 보통 ⇪
            if self.modifiers.contains(.capsLock) { spec += "⇪" }

            // ✅ Option Char가 있으면 여기서 바로 반환 가능 (Modifiers 처리 완료됨)
            if let validOptionChar = optionChar {
                return spec + validOptionChar
            }
        }

        // 2. 문자 해결 (Character Resolution)
        // Issue 277: Modifiers가 있을 경우, Shift된 문자가 아닌 Base Key Character를 찾아야 함
        var resolvedChar: String? = nil

        let hasModifiers = !self.modifiers.intersection([.control, .option, .command, .shift])
            .isEmpty

        // Issue 311: 수정자 없이도 Numpad 키(NumKey 접두사)를 결정적으로 지원하기 위해 항상 역방향 맵 확인
        // (예: 단일 키패드 마침표)
        let matchedKeys = TriggerKeyManager.reverseKeyMap.filter { $0.value.contains(self.keyCode) }
            .map { $0.key }

        // ✅ Issue 430_3: 일관성을 위해 "Num"보다 "keypad_" 우선순위 지정 (예: keypad_comma 대 NumKey,)
        if let keypadMatch = matchedKeys.first(where: { $0.hasPrefix("keypad_") }) {
            // Issue 474: 올바른 내부 토큰 형식을 보장하기 위해 키패드 키를 중괄호로 감쌈 (예: {keypad_comma})
            resolvedChar = "{\(keypadMatch)}"
        } else if let numKeyMatch = matchedKeys.first(where: { $0.hasPrefix("Num") }) {
            // Issue 311 Fix: Prefer "NumLock" over "NumClear" for UI consistency
            if matchedKeys.contains("NumLock") {
                resolvedChar = "NumLock"
            } else {
                resolvedChar = numKeyMatch
            }
        } else if hasModifiers {
            // 수정자가 있는 경우에만 일반 역방향 조회 사용 (기본 문자 가져오기)
            resolvedChar = matchedKeys.first
        }

        if let char = resolvedChar {
            spec += char
        } else if let char = self.character {
            switch char {
            case " ": spec += "Space"
            case "\n": spec += "Enter"
            case "\r": spec += "Return"
            case "\t": spec += "Tab"
            default: spec += char.uppercased()
            }
        }

        // Issue 311: If spec ends with '+', it means no character was added (Modifier-Only Key).
        // Remove the trailing '+' to match EnhancedTriggerKey format (e.g. "right_command").
        if spec.hasSuffix("+") {
            spec.removeLast()
        }

        return spec
    }
}
