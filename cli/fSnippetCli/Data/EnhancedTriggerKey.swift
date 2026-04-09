import Cocoa  // NSEvent.ModifierFlags 사용을 위해 추가

/// 향상된 트리거키 정보 (KeyLogger 결과 기반)
struct EnhancedTriggerKey: Codable, Equatable, Identifiable {
    let id: String  // 식별자 (예: "diamond_key")
    let displayCharacter: String  // 화면 표시 문자 (예: "◊")
    let keyCode: String  // KeyLogger keyCode (예: "unknown_95")
    let usage: String  // KeyLogger usage (예: "95 (0x005f)")
    let usagePage: String  // KeyLogger usagePage (예: "7 (0x0007)")
    let modifiers: String  // KeyLogger misc (예: "flags left_option")

    // UI 표시용
    let displayName: String  // "다이아몬드 (◊)"
    let keySequence: String  // "Option+J" 또는 "Special Key 95"

    // 매칭 전략
    enum MatchingStrategy: String, Codable {
        case character  // 문자 기반 매칭 (기존 방식)
        case keyCodeAndModifiers  // keyCode + modifiers 매칭 (새로운 방식)
        case hybrid  // 두 방식 모두 지원
    }
    let matchingStrategy: MatchingStrategy

    // 성능 최적화를 위한 저장 속성 (Issue 583_10)
    // 매번 문자열을 파싱하는 대신, 초기화 시점에 정수형으로 미리 계산하여 저장함.
    let storedKeyCode: UInt16?
    let storedModifierFlags: UInt

    // 생성자
    init(
        id: String, displayCharacter: String, keyCode: String, usage: String,
        usagePage: String, modifiers: String, displayName: String,
        keySequence: String, matchingStrategy: MatchingStrategy = .hybrid
    ) {
        self.id = id
        self.displayCharacter = displayCharacter
        self.keyCode = keyCode
        self.usage = usage
        self.usagePage = usagePage
        self.modifiers = modifiers
        self.displayName = displayName
        self.keySequence = keySequence
        self.matchingStrategy = matchingStrategy

        // 초기화 시점에 미리 계산 (Optimization)
        // self가 완전히 초기화되기 전에 메서드 호출 불가하므로, 정적 메서드나 클로저 활용
        // 여기서는 임시 변수로 계산 후 할당

        // 1. keyCode 계산
        var calculatedKeyCode: UInt16? = nil
        let components = keyCode.split(separator: "_")
        let keyCodeString = components.last ?? Substring(keyCode)
        if let val = UInt16(keyCodeString) {
            calculatedKeyCode = val
        } else {
            // 특별한 경우들 처리 (Option 조합 트리거용)
            switch keyCode {
            case "j": calculatedKeyCode = 38  // Option+J (∆)
            case "k": calculatedKeyCode = 40  // Option+K (˚)
            case "l": calculatedKeyCode = 37  // Option+L (¬)
            case "p": calculatedKeyCode = 35  // Option+P (π)
            default: calculatedKeyCode = nil
            }
        }
        self.storedKeyCode = calculatedKeyCode

        // 2. modifiers 계산 (기존 modifierFlagsUInt 로직 복제/이동)
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains("left_command") || modifiers.contains("right_command") {
            flags.insert(.command)
        }
        if modifiers.contains("left_option") || modifiers.contains("right_option") {
            flags.insert(.option)
        }
        if modifiers.contains("left_control") || modifiers.contains("right_control") {
            flags.insert(.control)
        }
        if modifiers.contains("left_shift") || modifiers.contains("right_shift") {
            flags.insert(.shift)
        }
        if modifiers.contains("right_command") { flags.insert(.deviceRightCommand) }
        if modifiers.contains("right_shift") { flags.insert(.deviceRightShift) }
        if modifiers.contains("right_option") { flags.insert(.deviceRightOption) }
        if modifiers.contains("right_control") { flags.insert(.deviceRightControl) }
        if modifiers.contains("caps_lock") { flags.insert(.capsLock) }

        self.storedModifierFlags = flags.rawValue
    }

    // ✅ Issue 277/278 헬퍼: 트리거가 버퍼를 소비할 가능성이 있거나 명령인지 확인
    var isNonVisualTrigger: Bool {
        return modifiers.contains("control") || modifiers.contains("command")
    }

    /// Issue 550: 트리거 키의 시각적 길이 반환 (SingleShortcutMapper 위임)
    var visualLength: Int {
        // 1. 우선 명시된 정의(KeyDefinition) 확인 (예: F1 -> 0, keypad_0 -> 1)
        if let def = SingleShortcutMapper.shared.getDefinition(for: self.id) {
            return def.visualCount
        }

        // 1-1. ID로 찾지 못한 경우 keySequence로 재시도 (Issue 550 Fix)
        // (예: id="trigger.keyspec_...", keySequence="{keypad_comma}")
        if let def = SingleShortcutMapper.shared.getDefinition(for: self.keySequence) {
            return def.visualCount
        }

        // 2. 정의가 없는 경우 (표준 키: A, 1, =, ` 등)
        // isCharacterGenerating 속성을 기반으로 판단 (문자를 생성하면 길이 1)
        return isCharacterGenerating ? 1 : 0
    }

    // ✅ Issue 459 & 603: 키가 가시적인 문자를 생성하는지 확인
    // 명시적으로 트리거로 등록해야 하는 키(예: NumLock/Clear/Modifiers)를 식별하는 데 사용됨
    var isCharacterGenerating: Bool {
        // 1. 수정자(Cmd/Ctrl/Opt)는 텍스트를 생성하지 않음
        if isNonVisualTrigger { return false }

        // 1.1. displayCharacter가 비어있으면 텍스트를 생성하지 않는 것으로 간주 (수정자 전용 키 등)
        if displayCharacter.isEmpty { return false }

        // 2. 키 코드 확인
        guard let code = hardwareKeyCode else { return true }  // 알 수 없는 경우 기본값 true

        // 문자를 생성하지 않는 코드:
        // 54-63: Modifier keys (RCmd, LCmd, LShift, Caps, LOpt, LCtrl, RShift, ROpt, RCtrl, Fn)
        // 71: Clear/NumLock
        // 36: Return, 76: Enter
        // 48: Tab
        // 51: Backspace, 117: Delete
        // 53: Escape
        // 96-122: F-Keys (대략적)
        let nonCharCodes: Set<UInt16> = [
            54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
            71, 36, 76, 48, 51, 117, 53,
        ]

        // F-키 범위 확인 (F1: 122... 등, 표준 F-키는 흩어져 있음)
        // 일반적인 비문자 키에 대한 간소화된 확인
        if nonCharCodes.contains(code) { return false }

        // F-키 (표준 Mac: 96, 97, 98, 99, 100, 101, 103, 109, 111, 105, 107, 113, 122, 120, 118, 96...)
        // displayCharacter가 F1-F12처럼 보이는지 확인?
        if displayCharacter.hasPrefix("F") && Int(displayCharacter.dropFirst()) != nil {
            return false
        }

        return true
    }

    // MARK: - Matching Methods

    /// 키 이벤트가 이 트리거키와 매칭되는지 확인 (Legacy String-based)
    func matches(
        keyCode: String, usage: String, usagePage: String, modifiers: String, character: String
    ) -> Bool {
        let charMatch = matchByCharacter(character)
        let dataMatch = matchByKeyData(
            keyCode: keyCode, usage: usage, usagePage: usagePage, modifiers: modifiers)

        // 🔍 디버깅: 매칭 과정 상세 로깅 (Verbose only)
        // logV("⚡ \(displayName) 매칭 검사:")

        switch matchingStrategy {
        case .character:
            return charMatch
        case .keyCodeAndModifiers:
            return dataMatch
        case .hybrid:
            return charMatch || dataMatch
        }
    }

    /// 키 이벤트가 이 트리거키와 매칭되는지 확인 (Optimized Integer-based)
    /// Issue 583_10: 정수형 비교로 성능 최적화
    func matches(keyCode: UInt16, modifiers: UInt, character: String?) -> Bool {
        // 1. Character Matching Strategy
        if matchingStrategy == .character || matchingStrategy == .hybrid {
            if let char = character, !char.isEmpty {
                if displayCharacter == char { return true }
            }
        }

        // 2. KeyCode & Modifiers Matching Strategy
        if matchingStrategy == .keyCodeAndModifiers || matchingStrategy == .hybrid {
            // KeyCode 비교
            guard let myCode = storedKeyCode else { return false }
            if myCode != keyCode { return false }

            // Modifiers 비교 (Strict)
            // storedModifierFlags는 init에서 계산됨
            // 입력된 modifiers와 저장된 modifiers가 정확히 일치해야 함

            // 주의: NSEvent.ModifierFlags는 device-dependent flag를 포함할 수 있으므로
            // 핵심 flag만 비교하는 것이 안전할 수 있음. 하지만 EnhancedTriggerKey의 로직은
            // 현재 Strict Matching을 수행함.

            // Issue: 입력된 modifiers에 불필요한 플래그(예: numericPad, function)가 있을 수 있음.
            // 트리거 키 정의에 사용된 플래그만 마스킹해서 비교?
            // 아니면, EnhancedTriggerKey.modifiersToReadable 처럼 핵심 플래그만 남기고 비교?

            // 기존 로직(matchByKeyData)은 문자열 비교를 수행함.
            // "flags left_option" vs "flags left_option"

            // storedModifierFlags는 init에서 "left_command", "right_command" 등을 파싱하여 플래그로 변환함.
            // 입력된 modifiers도 NSEvent.modifierFlags.rawValue임.

            // 캡스락 무시? (기존 로직은 modifiers 문자열에 caps_lock이 없으면 불일치로 간주)
            // 기존 로직: "트리거키가 모디파이어를 요구하지 않는데 입력에 모디파이어가 있으면 매칭 실패"

            // 마스크 정의
            let mask: UInt =
                NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
                | NSEvent.ModifierFlags.deviceLeftCommand.rawValue
                | NSEvent.ModifierFlags.deviceLeftOption.rawValue
                | NSEvent.ModifierFlags.deviceLeftControl.rawValue
                | NSEvent.ModifierFlags.deviceLeftShift.rawValue
                | NSEvent.ModifierFlags.deviceRightCommand.rawValue
                | NSEvent.ModifierFlags.deviceRightOption.rawValue
                | NSEvent.ModifierFlags.deviceRightControl.rawValue
                | NSEvent.ModifierFlags.deviceRightShift.rawValue

            // 비교
            // 단순 비교 시도
            // 기존 storedModifierFlags는 init에서 구성됨.
            // 입력 modifiers에서 numericPad, help, function 등을 제외해야 할 수도 있음.

            // 0x10(RightCmd), 0x2000(RightCtrl) 등 device specific flag가 넘어옴.
            // storedModifierFlags도 이를 포함하도록 init에서 수정했음.

            // 단순히 rawValue 비교가 가장 빠름.
            // 단, numericPad 같은 플래그가 간섭할 수 있음.
            let significantModifiers = modifiers & mask
            // storedModifierFlags도 mask로 걸러야 하나?
            // init에서 직접 insert했으므로 이미 clean함.

            if storedModifierFlags == significantModifiers {
                return true
            }

            // Backwards Compatibility / Relaxed Check
            // 만약 storedModifierFlags가 generic flag(command)만 가지고 있는데,
            // 입력은 leftCommand를 가지고 있다면?
            // NSEvent.ModifierFlags.command는 .deviceLeftCommand | .deviceRightCommand 였던가?
            // 아니면 별도? AppKit 문서상 .command = 0x100000.
            // .deviceLeftCommand = ?

            // Check:
            // storedModifierFlags가 0 (modifier 없음)이고 input이 0이면 Match.

            return false
        }

        return false
    }

    /// 문자 기반 매칭
    private func matchByCharacter(_ character: String) -> Bool {
        return displayCharacter == character
    }

    /// KeyLogger 메타데이터 기반 매칭
    private func matchByKeyData(
        keyCode: String, usage: String, usagePage: String, modifiers: String
    ) -> Bool {
        // ✅ Issue40 해결: 모디파이어 기반 트리거키의 엄격한 매칭
        // 트리거키가 모디파이어를 요구하는 경우, 입력에도 정확한 모디파이어가 있어야 함
        if !self.modifiers.isEmpty {
            // 트리거키가 모디파이어를 요구하는데 입력에 모디파이어가 없으면 매칭 실패
            if modifiers.isEmpty {
                logV("⚡ 모디파이어 불일치: 트리거키는 '\(self.modifiers)'를 요구하지만 입력은 비어있음")
                return false
            }

            // 정확한 모디파이어 매칭 확인
            let modifiersMatch = self.modifiers == modifiers
            if !modifiersMatch {
                logV("⚡ 모디파이어 불일치: 트리거키='\(self.modifiers)', 입력='\(modifiers)'")
                return false
            }
        } else {
            // 트리거키가 모디파이어를 요구하지 않는데 입력에 모디파이어가 있으면 매칭 실패
            if !modifiers.isEmpty {
                logV("⚡ 모디파이어 불일치: 트리거키는 모디파이어 없음을 요구하지만 입력에 '\(modifiers)' 있음")
                return false
            }
        }

        // 정확한 매칭을 위해 모든 메타데이터 비교
        let keyCodeMatch = self.keyCode == keyCode

        // Issue 297 해결: 생성된 키에 대한 퍼지 매칭 허용 (SSOT 마이그레이션)
        // 생성된 키는 "28 (generated)"와 같은 가짜 usage 문자열을 가지므로 실제 하드웨어 usage "28 (0x001c)"와 일치하지 않음
        let isGenerated = self.usage.contains("(generated)")
        let usageMatch = isGenerated ? true : (self.usage == usage)
        let usagePageMatch = isGenerated ? true : (self.usagePage == usagePage)

        logV(
            "⚡ 메타데이터 매칭: keyCode=\(keyCodeMatch), usage=\(usageMatch)(gen:\(isGenerated)), usagePage=\(usagePageMatch)"
        )

        // 모든 조건이 일치해야 매칭으로 인정
        return keyCodeMatch && usageMatch && usagePageMatch
    }

    // MARK: - Predefined Trigger Keys

    /// 사전 정의된 트리거키들
    static let presets: [EnhancedTriggerKey] = [
        delta, ring, `not`, equals, backtick, `comma`,
    ]

    /// ∆ (델타) - KeyLogger: j + left_option
    static let delta = EnhancedTriggerKey(
        id: "delta_key",
        displayCharacter: "∆",
        keyCode: "j",
        usage: "13 (0x000d)",
        usagePage: "7 (0x0007)",
        modifiers: "flags left_option",
        displayName: "델타 (∆)",
        keySequence: "Option+J",
        matchingStrategy: .keyCodeAndModifiers
    )

    /// ˚ (링) - KeyLogger: k + left_option
    static let ring = EnhancedTriggerKey(
        id: "ring_key",
        displayCharacter: "˚",
        keyCode: "k",
        usage: "40 (0x0028)",
        usagePage: "7 (0x0007)",
        modifiers: "flags left_option",
        displayName: "링 (˚)",
        keySequence: "Option+K",
        matchingStrategy: .keyCodeAndModifiers
    )

    /// ¬ (논리부정) - KeyLogger: l + left_option
    static let `not` = EnhancedTriggerKey(
        id: "not_key",
        displayCharacter: "¬",
        keyCode: "l",
        usage: "37 (0x0025)",
        usagePage: "7 (0x0007)",
        modifiers: "flags left_option",
        displayName: "논리부정 (¬)",
        keySequence: "Option+L",
        matchingStrategy: .keyCodeAndModifiers
    )

    /// = (등호) - 기본 트리거키
    static let equals = EnhancedTriggerKey(
        id: "equals_key",
        displayCharacter: "=",
        keyCode: "24",
        usage: "24 (0x0018)",
        usagePage: "7 (0x0007)",
        modifiers: "",
        displayName: "등호 (=)",
        keySequence: "Equals",
        matchingStrategy: .character  // 기존 방식 유지
    )

    /// ` (백틱) - 기본 스니펫 팝업키
    static let backtick = EnhancedTriggerKey(
        id: "backtick_key",
        displayCharacter: "`",
        keyCode: "50",
        usage: "50 (0x0032)",
        usagePage: "7 (0x0007)",
        modifiers: "",
        displayName: "백틱 (`)",
        keySequence: "Backtick",
        matchingStrategy: .character  // 기존 방식 유지
    )

    /// , (쉼표) - 콤마 트리거키
    static let `comma` = EnhancedTriggerKey(
        id: "comma_key",
        displayCharacter: ",",
        keyCode: "43",
        usage: "43 (0x002b)",
        usagePage: "7 (0x0007)",
        modifiers: "",
        displayName: "쉼표 (,)",
        keySequence: "Comma",
        matchingStrategy: .character  // 기존 방식 유지
    )

    // MARK: - Utility Methods

    /// KeyLogger 결과로부터 EnhancedTriggerKey 생성
    static func fromKeyLogger(
        character: String, keyCode: String, usage: String,
        usagePage: String, modifiers: String
    ) -> EnhancedTriggerKey {
        let id = "custom_\(keyCode)_\(character.unicodeScalars.first?.value ?? 0)"
        let displayName = "\(character) (사용자 정의)"
        let keySequence =
            modifiers.isEmpty ? "Key \(keyCode)" : "\(modifiersToReadable(modifiers))+\(keyCode)"

        return EnhancedTriggerKey(
            id: id,
            displayCharacter: character,
            keyCode: keyCode,
            usage: usage,
            usagePage: usagePage,
            modifiers: modifiers,
            displayName: displayName,
            keySequence: keySequence,
            matchingStrategy: .hybrid
        )
    }

    /// modifiers 문자열을 읽기 쉬운 형태로 변환
    private static func modifiersToReadable(_ modifiers: String) -> String {
        var readable = modifiers
        readable = readable.replacingOccurrences(of: "flags ", with: "")
        readable = readable.replacingOccurrences(of: "left_option", with: "Option")
        readable = readable.replacingOccurrences(of: "left_command", with: "Cmd")
        readable = readable.replacingOccurrences(of: "left_control", with: "Ctrl")
        readable = readable.replacingOccurrences(of: "left_shift", with: "Shift")

        // Issue 308: 오른쪽 수정자 및 CapsLock 지원
        readable = readable.replacingOccurrences(of: "right_command", with: "➡️Cmd")
        readable = readable.replacingOccurrences(of: "right_option", with: "➡️Opt")
        readable = readable.replacingOccurrences(of: "right_control", with: "➡️Ctrl")
        readable = readable.replacingOccurrences(of: "right_shift", with: "➡️Shift")
        readable = readable.replacingOccurrences(of: "caps_lock", with: "Caps")

        return readable
    }

    // MARK: - Debug Information

    /// 디버깅용 상세 정보
    var debugInfo: String {
        return """
            EnhancedTriggerKey Debug Info:
            - ID: \(id)
            - Character: '\(displayCharacter)'
            - KeyCode: \(keyCode)
            - Usage: \(usage)
            - UsagePage: \(usagePage)
            - Modifiers: \(modifiers)
            - Strategy: \(matchingStrategy)
            - Display: \(displayName)
            - Sequence: \(keySequence)
            """
    }
}

// MARK: - Extensions

extension EnhancedTriggerKey {
    /// 기존 시스템 호환을 위한 간단한 문자 반환
    var legacyCharacter: String {
        return displayCharacter
    }

    /// 트리거키의 우선순위 (낮을수록 높은 우선순위)
    var priority: Int {
        switch id {
        case "delta_key": return 2  // ∆
        case "ring_key": return 3  // ˚
        case "not_key": return 4  // ¬
        case "equals_key": return 5  // =
        case "backtick_key": return 6  // `
        case "comma_key": return 7  // ,
        default: return 100  // 사용자 정의
        }
    }

    /// keyCode 문자열에서 하드웨어 키코드 추출 (CGEventTap 호환)
    var hardwareKeyCode: UInt16? {
        // keyCode 형식 예: "unknown_95", "equal_sign_27", "24"
        let components = keyCode.split(separator: "_")
        let keyCodeString = components.last ?? Substring(keyCode)

        // 순수 숫자인 경우 (예: "24")
        if let keyCodeValue = UInt16(keyCodeString) {
            return keyCodeValue
        }

        // 특별한 경우들 처리 (Option 조합 트리거용)
        switch keyCode {
        case "j": return 38  // Option+J (∆)
        case "k": return 40  // Option+K (˚)
        case "l": return 37  // Option+L (¬)
        case "p": return 35  // Option+P (π) - Added for consistency
        default: return nil
        }
    }

    /// modifiers 문자열을 NSEvent.ModifierFlags.rawValue (UInt)로 변환
    var modifierFlagsUInt: UInt {
        var flags: NSEvent.ModifierFlags = []

        // Generic Flags
        if modifiers.contains("left_command") || modifiers.contains("right_command") {
            flags.insert(.command)
        }
        if modifiers.contains("left_option") || modifiers.contains("right_option") {
            flags.insert(.option)
        }
        if modifiers.contains("left_control") || modifiers.contains("right_control") {
            flags.insert(.control)
        }
        if modifiers.contains("left_shift") || modifiers.contains("right_shift") {
            flags.insert(.shift)
        }

        // Device-Specific Flags (Issue 298)
        if modifiers.contains("right_command") { flags.insert(.deviceRightCommand) }
        if modifiers.contains("right_shift") { flags.insert(.deviceRightShift) }
        if modifiers.contains("right_option") { flags.insert(.deviceRightOption) }
        if modifiers.contains("right_control") { flags.insert(.deviceRightControl) }

        // Caps Lock
        if modifiers.contains("caps_lock") { flags.insert(.capsLock) }

        // We assume left_* maps to generic + lack of Right flag, or we could add .deviceLeft*.
        // But usually checking .command && !.deviceRightCommand implies Left.

        return flags.rawValue
    }
}

// MARK: - KeySpec Support (Issue 277)
extension EnhancedTriggerKey {
    /// keySpec 문자열 반환 (예: "^⌥⌘P" 또는 "right_command+P")
    var toKeySpec: String {
        var spec = ""

        // Issue 298: 오른쪽 수정자 확인
        let hasRightModifiers = modifiers.contains("right_")

        if hasRightModifiers {
            // Use Verbose Format (e.g. "right_command+left_shift+P")
            var parts: [String] = []

            // Extract modifiers from space-separated string "flags left_command right_shift"
            let mods = modifiers.replacingOccurrences(of: "flags ", with: "").components(
                separatedBy: " ")

            // Order: Command -> Shift -> Option -> Control (to match common conventions, though logic handles any)
            if mods.contains("left_command") { parts.append("left_command") }
            if mods.contains("right_command") { parts.append("right_command") }

            if mods.contains("left_shift") { parts.append("left_shift") }
            if mods.contains("right_shift") { parts.append("right_shift") }

            if mods.contains("left_option") { parts.append("left_option") }
            if mods.contains("right_option") { parts.append("right_option") }

            if mods.contains("left_control") { parts.append("left_control") }
            if mods.contains("right_control") { parts.append("right_control") }

            if mods.contains("caps_lock") { parts.append("caps_lock") }

            spec = parts.joined(separator: "+")
            if !spec.isEmpty { spec += "+" }

        } else {
            // Standard Symbol Format
            // Order: Ctrl -> Opt -> Cmd -> Shift (Standard Cocoa order)
            if modifiers.contains("control") { spec += "^" }
            if modifiers.contains("option") { spec += "⌥" }
            if modifiers.contains("command") { spec += "⌘" }
            if modifiers.contains("shift") { spec += "⇧" }
            if modifiers.contains("caps_lock") { spec += "⇪" }
        }

        // Key Character 변환
        // 하드웨어 키코드가 있으면 역매핑 시도
        if let code = hardwareKeyCode {
            let label = EnhancedTriggerKey.keyCodeToString(code)
            spec += EnhancedTriggerKey.wrapInBraces(label)
        } else {
            // fallback: displayCharacter (알파벳인 경우)
            if displayCharacter.count == 1
                && displayCharacter.description.rangeOfCharacter(from: .letters) != nil
            {
                spec += displayCharacter.uppercased()
            } else {
                // 특수문자나 알 수 없는 경우... 일단 displayCharacter 사용
                spec += displayCharacter
            }
        }

        return spec
    }

    /// KeySpec으로부터 EnhancedTriggerKey 생성 Factory
    static func from(keySpec: String) -> EnhancedTriggerKey {
        // Issue 449: Strip curly braces if present (e.g. "{keypad_comma}" -> "keypad_comma")
        var remainingSpec = keySpec
        if remainingSpec.hasPrefix("{") && remainingSpec.hasSuffix("}") {
            remainingSpec = String(remainingSpec.dropFirst().dropLast())
        }

        var modifierParts: [String] = []

        // Issue 298: Verbose Format Parsing
        // Check for specific tokens and consume them
        // Tokens: right_command, right_shift, right_option, right_control
        // Also left_ counterparts if explicitly provided

        let verboseTokens = [
            "right_command", "left_command",
            "right_shift", "left_shift",
            "right_option", "left_option",
            "right_control", "left_control",
            "caps_lock",  // Added for Issue 308
        ]

        var foundVerbose = false
        for token in verboseTokens {
            if remainingSpec.contains(token) {
                modifierParts.append(token)
                remainingSpec = remainingSpec.replacingOccurrences(of: token, with: "")
                foundVerbose = true
            }
        }

        if foundVerbose {
            // Clean up separators (+)
            remainingSpec = remainingSpec.replacingOccurrences(of: "+", with: "")
        } else {
            // Standard Symbol Parsing (Backward Compatibility)
            if remainingSpec.contains("⌘") {
                modifierParts.append("left_command")
                remainingSpec = remainingSpec.replacingOccurrences(of: "⌘", with: "")
            }
            if remainingSpec.contains("⇧") {
                modifierParts.append("left_shift")
                remainingSpec = remainingSpec.replacingOccurrences(of: "⇧", with: "")
            }
            if remainingSpec.contains("⌥") {
                modifierParts.append("left_option")
                remainingSpec = remainingSpec.replacingOccurrences(of: "⌥", with: "")
            }
            if remainingSpec.contains("^") || remainingSpec.contains("⌃") {
                modifierParts.append("left_control")
                remainingSpec = remainingSpec.replacingOccurrences(of: "^", with: "")
                remainingSpec = remainingSpec.replacingOccurrences(of: "⌃", with: "")
            }
            if remainingSpec.contains("⇪") {
                modifierParts.append("caps_lock")
                remainingSpec = remainingSpec.replacingOccurrences(of: "⇪", with: "")
            }
        }

        let modifiersStr =
            modifierParts.isEmpty ? "" : "flags " + modifierParts.joined(separator: " ")

        var char = remainingSpec  // 남은 부분이 문자

        // keyCode 역추적 (문자 -> 코드)
        var code = "0"
        var candidateCodes = TriggerKeyManager.reverseKeyMap[char]
        var isLegacy = false

        if candidateCodes == nil {
            candidateCodes = TriggerKeyManager.legacyKeyMap[char]
            if candidateCodes != nil { isLegacy = true }
        }

        if let codes = candidateCodes, let first = codes.first {
            code = String(first)

            // Issue 439: Canonicalize Legacy Names (e.g. NumKey, -> keypad_comma)
            // Even if input was "NumKey,", we switch to "keypad_comma" for display/ID
            if isLegacy, let codeVal = UInt16(code) {
                let canonicalName = keyCodeToString(codeVal)
                if canonicalName != "?" {
                    char = canonicalName
                }
            }

            // ✅ Issue 459: Canonicalize NumLock/Clear to '🔢' for internal buffer consistency
            if char == "keypad_num_lock" || char == "keypad_clear" || char == "NumLock" {
                char = "🔢"
            }
        }

        // Issue 308: 수정자 전용 트리거에 대한 키 코드 추론
        // char가 비어 있고 단일 수정자 부분만 있는 경우 해당 수정자의 키 코드를 기본 코드로 사용
        // 이를 통해 UI 컴포넌트(ShortcutInputView)가 올바르게 표시할 수 있음 (예: "A" 대신 "RCmd").
        if code == "0" && char.isEmpty && modifierParts.count == 1 {
            let mod = modifierParts[0]
            switch mod {
            case "right_command": code = "54"
            case "left_command": code = "55"
            case "left_shift": code = "56"
            case "caps_lock": code = "57"
            case "left_option": code = "58"
            case "left_control": code = "59"
            case "right_shift": code = "60"
            case "right_option": code = "61"
            case "right_control": code = "62"
            default: break
            }
        }

        // Issue 308: 적절한 DisplayName 생성
        var cleanDisplayName = ""
        if !modifiersStr.isEmpty {
            cleanDisplayName += EnhancedTriggerKey.modifiersToReadable(modifiersStr)
            // 뒤따르는 문자가 있으면 구분 기호 추가
            if !char.isEmpty {
                cleanDisplayName += "+"
            }
        }
        cleanDisplayName += char.uppercased()

        // Issue 277: ID must allow reconstruction of modifiers.
        let specData = keySpec.data(using: .utf8)
        let base64Spec = specData?.base64EncodedString() ?? ""
        let id = "keyspec_\(base64Spec)"

        return EnhancedTriggerKey(
            id: id,
            displayCharacter: char,
            keyCode: code,
            usage: "\(code) (generated)",
            usagePage: "7 (0x0007)",
            modifiers: modifiersStr,
            displayName: cleanDisplayName,  // Issue 308: 깔끔한 이름 사용
            keySequence: keySpec,
            matchingStrategy: .keyCodeAndModifiers
        )
    }

    // Helper: KeyCode to String (SnippetWatcherScaffold/ShortcutInputView와 유사)
    fileprivate static func keyCodeToString(_ keyCode: UInt16) -> String {
        return SingleShortcutMapper.shared.getKeyLabel(for: keyCode)
    }

    // MARK: - Brace Handling Helpers (Issue 449)

    /// 키 사양 문자열을 중괄호로 감싸야 하는지 확인 (예: "keypad_comma" -> true, "=" -> false)
    /// 키 스펙 문자열이 중괄호로 감싸져야 하는지 확인합니다. (예: "keypad_comma" -> true, "=" -> false)
    static func shouldWrapInBraces(_ spec: String) -> Bool {
        // Issue 524: Single Shortcut(기술적 키 이름)만 중괄호로 감싸고, 일반 문자는 제외합니다.

        // 1. 이미 감싸져 있다면 유지 (true 반환)
        if spec.hasPrefix("{") && spec.hasSuffix("}") { return true }

        // 2. 일반 문자 또는 Modifier 조합은 감싸지 않음
        // (단일 문자이거나, +, ^, ⌥, ⌘, ⇧ 등을 포함하는 경우)
        // 주의: "keypad_plus" 같은 경우 "+"를 포함하지 않도록 이름이 되어있음.
        // 하지만 "Cmd+S" 같은 Modifier 조합 식별 필요.

        let modifierSymbols = CharacterSet(charactersIn: "^⌥⌘⇧⇪+")
        if spec.rangeOfCharacter(from: modifierSymbols) != nil {
            return false
        }

        // 3. Single Shortcut 패턴 확인 (기술적 키 이름)
        // SharedKeyMap.reverseMapping.keys를 참조하는 것이 가장 정확하지만,
        // 여기서는 패턴 매칭으로 처리하여 종속성을 줄입니다.

        let technicalPrefixes = [
            "keypad_", "right_", "left_",
            "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
            "home", "end", "page_", "help", "delete", "forward_delete",
            "tab", "return", "enter", "space", "escape", "caps_lock",
        ]

        // 소문자로 변환하여 확인
        let lowerSpec = spec.lowercased()

        for prefix in technicalPrefixes {
            if lowerSpec.hasPrefix(prefix) {
                return true
            }
        }

        // 그 외 (일반 단어, 문자 등) -> 감싸지 않음
        return false
    }

    /// 필요한 경우 키 사양을 중괄호로 감쌈
    static func wrapInBraces(_ spec: String) -> String {
        if shouldWrapInBraces(spec) && !spec.hasPrefix("{") {
            return "{\(spec)}"
        }
        return spec
    }

    /// 중괄호에서 키 사양 추출
    static func unwrapBraces(_ spec: String) -> String {
        return SingleShortcutMapper.shared.unwrap(spec)
    }
}

// MARK: - Collection Extensions

extension Array where Element == EnhancedTriggerKey {
    /// 우선순위 순으로 정렬
    func sortedByPriority() -> [EnhancedTriggerKey] {
        return sorted { $0.priority < $1.priority }
    }

    /// 특정 문자로 필터링
    func matching(character: String) -> [EnhancedTriggerKey] {
        return filter { $0.displayCharacter == character }
    }

    /// KeyLogger 데이터로 필터링
    func matching(
        keyCode: String, usage: String, usagePage: String, modifiers: String, character: String
    ) -> [EnhancedTriggerKey] {
        return filter {
            $0.matches(
                keyCode: keyCode, usage: usage, usagePage: usagePage, modifiers: modifiers,
                character: character)
        }
    }
}
