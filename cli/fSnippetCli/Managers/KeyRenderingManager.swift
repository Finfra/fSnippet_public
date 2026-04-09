import Cocoa

/// 키 표시 로직을 처리하는 중앙 관리자.
/// Option 키 기반 단축키를 결과 특수 문자(예: Option+P -> π)로 렌더링하도록 설계되었으며,
/// 다른 키에 대해서는 표준 수식어 표시 방식을 유지합니다.
/// 이제 시각적 너비 계산 및 입력 위생 처리의 중심이 됩니다.
class KeyRenderingManager {
    static let shared = KeyRenderingManager()

    private init() {
        logV("🎨 [KeyRenderingManager] Initialized")
        loadVisualWidthDefinitions()
    }

    // MARK: - Properties

    // visual_key_definitions.json에서 로드됨
    private var visualWidthDefinitions: [String: Int] = [:]

    // MARK: - Constants & Mappings

    // MARK: - Constants & Mappings

    private let numpadMapping: [UInt16: String] = SharedKeyMap.numpadMapping

    /// 키패드 및 오른쪽 수식어 기호 매핑 (표시 전용)
    private let symbolMapping: [String: String] = SharedKeyMap.symbolMapping

    // MARK: - 기호 매핑 접근

    /// 기호 매핑이 없으면 원래 문자열을 반환합니다.
    func getSymbol(for keyName: String) -> String {
        // 매퍼 사용
        if let symbol = SingleShortcutMapper.shared.getSymbol(for: keyName) {
            return symbol
        }

        let cleanKey = SingleShortcutMapper.shared.unwrap(keyName)
        return cleanKey
    }

    /// 텍스트 내의 모든 알려진 키 이름(예: "keypad_1")을 기호(예: "1️⃣")로 대체합니다.
    func replaceKeyNamesWithSymbols(in text: String) -> String {
        var result = text
        // symbolMapping을 순회합니다.
        // 참고: 키가 다른 키의 부분 문자열일 경우 부분 대체를 방지하기 위해 키 길이의 내림차순으로 순회합니다.
        // 현재 키들은 충분히 구별되지만("keypad_1", "right_command"), 좋은 관행입니다.
        let sortedKeys = symbolMapping.keys.sorted { $0.count > $1.count }

        for key in sortedKeys {
            // ✅ Issue 430: 중괄호로 감싸진 키 처리 ({keypad_comma} -> 🔢, {🔢,} 대신)
            let enclosedKey = "{\(key)}"
            if result.contains(enclosedKey) {
                if let symbol = symbolMapping[key] {
                    result = result.replacingOccurrences(of: enclosedKey, with: symbol)
                }
            }

            if result.contains(key) {
                if let symbol = symbolMapping[key] {
                    result = result.replacingOccurrences(of: key, with: symbol)
                }
            }
        }
        return result
    }

    /// 키가 강조(굵게 + 보조 색상)되어 표시되어야 하는지 확인합니다.
    /// 키패드 키와 오른쪽 수식어에 대해 true를 반환합니다.
    func isSpecialKey(_ keyName: String) -> Bool {
        return keyName.hasPrefix("keypad_") || keyName.hasPrefix("right_")
            || keyName.hasPrefix("🔢")  // keypad 심볼로 변환된 경우 (예: "🔢﹐")
    }

    // 오른쪽 수식어에 대한 가상 키 코드 (필요한 경우 원시 플래그 확인에 사용되지만, 여기서는 플래그를 확인합니다)
    // 장치별 수식어 플래그 상수 (macOS Carbon/IOKit)
    // NX_DEVICERCMDKEYMASK   = 0x00000010
    // NX_DEVICERSHIFTKEYMASK = 0x00000004
    // NX_DEVICERALTKEYMASK   = 0x00000040

    private let RightCommandMask: UInt = 0x0000_0010
    private let RightControlMask: UInt = 0x0000_2000
    // Option은 Alt입니다. Left=0x20, Right=0x40.
    private let RightOptionMask: UInt = 0x0000_0040
    private let RightShiftMask: UInt = 0x0000_0004

    // MARK: - Public Methods

    /// 키 이벤트가 수식어 문자열 대신 단일 문자로 렌더링되어야 하는지 확인합니다.
    /// - Parameter modifiers: 수식어 플래그.
    /// - Parameter keyString: 키의 문자열 표현 (있는 경우).
    /// - Parameter keyCode: 가상 키 코드.
    /// - Returns: 단일 문자로 렌더링해야 하면 true를 반환합니다.
    func shouldRenderAsCharacter(
        modifiers: NSEvent.ModifierFlags, keyString: String?, keyCode: UInt16
    ) -> Bool {
        // Numpad 키는 특수 처리가 필요하므로 "단일 문자" 렌더링 로직(특수문자 변환)에서는 제외하고
        // getDisplayString에서 직접 처리하도록 함 (또는 여기서 true를 반환하고 getDisplayString에서 처리)
        // 여기서는 "Option+Char -> SpecialChar" 로직을 위한 것이므로 Numpad는 false가 적절함.
        if isNumpadKey(keyCode: keyCode) { return false }

        // 1. 출력 가능한 문자가 있어야 함
        guard let chars = keyString, !chars.isEmpty else { return false }

        // 2. 텍스트 표현이 있더라도 출력 불가능한 키(Enter, Tab, F-키 등)는 제외
        if isNonPrintableKey(keyCode: keyCode) { return false }

        let significantModifiers = modifiers.intersection([.command, .control, .option, .shift])

        // 3. Option 키 로직 (핵심 요구사항)
        // Option이 포함되어 있고, Command와 Control은 포함되지 않은 경우 문자로 렌더링.
        // Shift는 허용됨 (예: Shift+Option+K -> )
        return significantModifiers.contains(.option) && !significantModifiers.contains(.command)
            && !significantModifiers.contains(.control)
    }

    /// KeyEventInfo를 사용하는 편의 메서드
    func shouldRenderAsCharacter(_ keyInfo: KeyEventInfo) -> Bool {
        // CGEventFlags -> NSEvent.ModifierFlags 변환 필요
        // 하지만 여기서는 NSEvent.ModifierFlags를 직접 구성하기보다
        // 내부 로직을 CGEventFlags 호환으로 만들거나 변환해야 함.
        // 간단히 NSEvent.ModifierFlags(rawValue: UInt(keyInfo.modifiers.rawValue)) 사용
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(keyInfo.modifiers.rawValue))
        return shouldRenderAsCharacter(
            modifiers: modifiers, keyString: keyInfo.character, keyCode: keyInfo.keyCode)
    }

    /// 주어진 키 조합에 대한 표시 문자열을 반환합니다.
    /// - Parameters:
    ///   - modifiers: 수식어 플래그
    ///   - keyString: 이벤트에 의해 생성된 문자 (예: "π")
    ///   - keyCode: 원시 키 코드
    ///   - standardDisplayString: 표준 "⌥P" 스타일 문자열 (대체값)
    /// - Returns: UI에 표시할 문자열
    func getDisplayString(
        modifiers: NSEvent.ModifierFlags, keyString: String?, keyCode: UInt16,
        standardDisplayString: String
    ) -> String {
        // 1. Numpad Check
        if let numpadString = numpadMapping[keyCode] {
            // Numpad는 Modifier와 결합될 수 있음 (예: Cmd + Num0)
            let modifierString = getModifierString(modifiers: modifiers)

            // Issue 420: Symbol Mapping
            let symbol = symbolMapping[numpadString] ?? numpadString
            return modifierString + symbol
        }

        // 2. Option+Key Special Character Rendering
        if shouldRenderAsCharacter(modifiers: modifiers, keyString: keyString, keyCode: keyCode) {
            return keyString ?? standardDisplayString
        }

        // 3. Right Modifier Check & Standard Fallback
        // 표준 문자열(standardDisplayString)은 이미 "⌥⌘P" 형태일 것임.
        // 우리는 "Right Command" 등을 구별하고 싶으므로, modifiers를 다시 파싱해서 재조립해야 할 수도 있음.
        // 하지만 standardDisplayString이 간단하다면(modifier symbols), 우리가 직접 조립하는 게 안전함.

        // 3. Right Modifier & Caps Lock Check
        // 표준 문자열(standardDisplayString)은 이미 "⌥⌘P" 형태일 것임.
        // 우리는 "Right Command" 등을 구별하고 싶으므로, modifiers를 다시 파싱해서 재조립해야 할 수도 있음.
        // 하지만 standardDisplayString이 간단하다면(modifier symbols), 우리가 직접 조립하는 게 안전함.

        // 만약 Right Modifier나 Caps Lock이 감지되면 직접 조립
        if hasRightModifiers(modifiers: modifiers) || modifiers.contains(.capsLock) {
            // Issue 308: For modifier keys (e.g. Right Command pressed), charPart should be empty
            let charPart =
                isModifierKeyCode(keyCode)
                ? "" : (keyString?.uppercased() ?? getKeyName(keyCode: keyCode))

            // Issue 308: If charPart is empty (Modifier-only trigger), remove trailing '+'
            var modStr = getModifierString(modifiers: modifiers)
            if charPart.isEmpty {
                if modStr.hasSuffix("+") {
                    modStr.removeLast()
                }
                return modStr
            }
            return modStr + charPart
        }

        return standardDisplayString
    }

    /// KeyEventInfo를 사용하는 편의 메서드
    func getDisplayString(_ keyInfo: KeyEventInfo, standardDisplayString: String) -> String {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(keyInfo.modifiers.rawValue))
        return getDisplayString(
            modifiers: modifiers, keyString: keyInfo.character, keyCode: keyInfo.keyCode,
            standardDisplayString: standardDisplayString)
    }

    // MARK: - Private Helpers

    private func isNumpadKey(keyCode: UInt16) -> Bool {
        return numpadMapping.keys.contains(keyCode)
    }

    private func hasRightModifiers(modifiers: NSEvent.ModifierFlags) -> Bool {
        let raw = modifiers.rawValue
        return (raw & RightCommandMask != 0) || (raw & RightControlMask != 0)
            || (raw & RightOptionMask != 0)
        // (raw & RightShiftMask != 0) // Issue 558: Shift는 Left/Right 구분 없이 처리
    }

    private func getModifierString(modifiers: NSEvent.ModifierFlags) -> String {
        var str = ""
        let raw = modifiers.rawValue

        // Control
        if modifiers.contains(.control) {
            if (raw & RightControlMask) != 0 { str += "➡️⌃" } else { str += "⌃" }
        }

        // Option
        if modifiers.contains(.option) {
            // Option은 보통 그냥 ⌥를 쓰지만, Right 구별 요청이 있다면:
            if (raw & RightOptionMask) != 0 { str += "➡️⌥" } else { str += "⌥" }
        }

        // Command
        if modifiers.contains(.command) {
            if (raw & RightCommandMask) != 0 { str += "➡️⌘" } else { str += "⌘" }
        }

        // Shift
        if modifiers.contains(.shift) {
            if (raw & RightShiftMask) != 0 { str += "➡️⇧" } else { str += "⇧" }
        }

        // CapsLock
        if modifiers.contains(.capsLock) {
            str += "Caps+"
        }

        return str
    }

    private func getKeyName(keyCode: UInt16) -> String {
        // 기본 키 이름 반환 (매핑되지 않은 특수키용, 실제론 standardDisplayString이 더 정확할 수 있음)
        // 여기서는 간단한 폴백만 제공
        return ""
    }

    /// 이 컨텍스트에서 기능적으로 출력 불가능한 키를 식별하는 헬퍼
    /// (알파벳 대체에 초점)
    private func isNonPrintableKey(keyCode: UInt16) -> Bool {
        // 일반적인 출력 불가능 코드 (표준 레이아웃 기준 대략적 확인)
        // 36: Return, 48: Tab, 51: Delete, 53: Esc, 123-126: 화살표, F-키 등
        let nonPrintables: Set<UInt16> = [
            36, 48, 49, 51, 53, 71, 76,  // 일반 제어키 (Space(49)는 출력 가능하지만 보통 "Space" 라벨을 원함)
            123, 124, 125, 126,  // 화살표
            96, 97, 98, 99, 100, 101, 109, 103, 111, 105, 107, 113, 106, 63, 118, 96, 97, 98, 99,
            100, 114,  // F-키 등
        ]

        // 특수 케이스: Space (49)
        // 사용자가 " " (공백 문자)를 보길 원하면 false를 반환해야 함.
        // 하지만 단축키에서는 보통 "Space" 텍스트나 심볼을 원하며, 빈 공백을 원하지 않음.
        // Option+Space -> Non-breaking space의 경우 보이지 않으므로, "시각적 문자" 목적에서는 출력 불가능으로 처리하는 것이 적절함.

        return nonPrintables.contains(keyCode) || (keyCode >= 96 && keyCode <= 111)  // 대략적인 F1-F12 범위
    }

    private func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
        // 54-62 range: Right/Left Cmd, Shift, Caps, Opt, Ctrl
        return keyCode >= 54 && keyCode <= 62
    }

    // MARK: - 시각적 너비 및 위생 처리 로직 (KeyEventMonitor에서 이동됨)

    // visual_key_definitions.json 로드
    private func loadVisualWidthDefinitions() {
        guard
            let url = Bundle.main.url(forResource: "visual_key_definitions", withExtension: "json")
        else {
            logW("🎨 [KeyRenderingManager] visual_key_definitions.json not found in Bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.visualWidthDefinitions = try decoder.decode([String: Int].self, from: data)
            logV(
                "🎨 [KeyRenderingManager] Loaded \(self.visualWidthDefinitions.count) visual width definitions."
            )
        } catch {
            logE("🎨 [KeyRenderingManager] Failed to load visual width definitions: \(error)")
        }
    }

    /// 특정 문자의 시각적 표시 너비 반환 (개선된 동적 방식)
    func getVisualWidth(from triggerKey: EnhancedTriggerKey) -> Int {
        let char = triggerKey.displayCharacter

        // 1. 로드된 정의 확인 (테이블) - 사용자 설정
        if let definedWidth = visualWidthDefinitions[char] {
            return definedWidth
        }

        // 1-1. 매퍼 확인 (SSOT)
        let normalized = SingleShortcutMapper.shared.unwrap(char)
        if SingleShortcutMapper.shared.isValidSingleShortcut(normalized) {
            return SingleShortcutMapper.shared.getVisualCount(for: normalized)
        }

        // 2. 일반 문자열 (길이 1)
        if char.count == 1 {
            return 1
        }

        // 3. Alt 키 계열 (Option modifier)
        // User rule: "표에 정의 되지 않은 shortcut은 alt키 계열이 아닌 이상 VisualCnt가 0임"
        if triggerKey.modifiers.contains("option") {
            return 1  // Alt는 보통 1글자를 출력한다고 가정
        }

        // 4. 정의되지 않은 단축키 (예: F5, 또는 알 수 없는 특수 키) -> 0
        return 0
    }

    /// 문자열의 시각적 길이를 계산하며, 내부 비시각적 토큰은 무시합니다.
    func calculateVisualStringLength(_ str: String) -> Int {
        var length = 0
        for char in str {
            if char == "🔢" { continue }  // 비시각적 키 (NumLock/Clear)
            length += 1
        }
        return length
    }

    /// Issue469_7: 위생 처리 헬퍼
    func sanitizeInputCharacter(_ char: String) -> String {
        // 1. 내부 토큰 확인 (중괄호)
        if char.hasPrefix("{") && char.hasSuffix("}") && char.count > 2 {
            // 일반 토큰을 시각적으로 매핑
            let content = char.dropFirst().dropLast()  // {} 제거

            // Refactor (Issue 513_2): Use SingleShortcutMapper for validation
            if SingleShortcutMapper.shared.isValidSingleShortcut(String(content)) {
                return "{\(content)}"
            } else {
                return ""  // 알 수 없는 내부 토큰 삭제
            }
        }

        // 2. 레거시 "NumKey" 확인
        if char.hasPrefix("NumKey") {
            if char == "NumKey," { return "," }
            // Extract last char if useful?
            // e.g. NumKey0 -> 0
            if let last = char.last { return String(last) }
            return ""
        }

        // 3. Issue 474: 중괄호 없는 keypad_ 키 처리 (버퍼 보호)
        // 시스템이 "keypad_comma" 문자열을 반환하면, 위의 토큰 로직에 걸리도록 감쌉니다.
        if char.hasPrefix("keypad_") {
            return sanitizeInputCharacter("{\(char)}")
        }

        return char
    }

    /// Issue38 해결: 트리거 바이어스를 적용한 백스페이스 계산
    /// ✅ Issue 278: 비시각적 트리거에 대한 EnhancedTriggerKey 지원
    /// ✅ Refactor: 복잡한 뺄셈 로직을 피하기 위해 기본 길이(baseLength)를 직접 받음
    func calculateVisualAdjustment(
        baseLength: Int, triggerKey: EnhancedTriggerKey, triggerBias: Int, auxBias: Int
    ) -> Int {
        if triggerKey.isNonVisualTrigger && triggerKey.modifiers.isEmpty == false {
            // 비시각적 트리거 (예: ^;)는 외부에서 버퍼에서 제거됨.
            return max(0, baseLength + triggerBias + auxBias)
        } else {
            // 시각적 트리거 (또는 수식어는 없지만 특수한 이름을 가진 키패드 키)

            // 트리거키의 시각적 넓이 계산 (업데이트됨: triggerKey 객체 전달)
            let triggerVisualWidth = getVisualWidth(from: triggerKey)

            // 총 백스페이스 = 기본 텍스트 길이 + 트리거키 시각적 넓이 + 바이어스 + 보조 바이어스
            let totalBackspaceCount = baseLength + triggerVisualWidth + triggerBias + auxBias

            logD(
                "🎨 [KeyRenderingManager] Deletion: Base(\(baseLength)) + Visual(\(triggerVisualWidth)) [\(triggerKey.displayCharacter)] + UserBias(\(triggerBias)) + AuxBias(\(auxBias)) = Total(\(totalBackspaceCount))"
            )

            return max(0, totalBackspaceCount)
        }
    }
}
