import Foundation
import Cocoa
import ApplicationServices

/// KeyLogger 데이터 추출을 위한 유틸리티 클래스
struct KeyEventDataExtractor {
    
    /// CGEvent에서 키 이벤트 데이터 추출
    static func extractKeyData(from event: CGEvent) -> KeyEventData {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = event.flags
        
        // 문자 추출 (NSEvent 생성 필요)
        let nsEvent = NSEvent(cgEvent: event)
        let character = nsEvent?.charactersIgnoringModifiers ?? ""
        let characterWithModifiers = nsEvent?.characters ?? ""
        
        // Usage 및 UsagePage는 CGEvent에서 직접 추출할 수 없으므로 keyCode 기반으로 매핑
        let (usage, usagePage) = mapKeyCodeToUsage(keyCode)
        
        // Modifiers를 문자열로 변환
        let modifiersString = modifiersToString(modifiers)
        
        return KeyEventData(
            keyCode: keyCode,
            keyCodeString: keyCodeToString(keyCode),
            usage: usage,
            usagePage: usagePage,
            modifiers: modifiers,
            modifiersString: modifiersString,
            character: characterWithModifiers,
            characterIgnoringModifiers: character
        )
    }
    
    /// 직접 매개변수로 키 이벤트 데이터 생성 (Issue39: 향상된 시스템용)
    static func createKeyEventData(keyCode: UInt16, modifiers: CGEventFlags, character: String) -> KeyEventData {
        // keyCode를 usage, usagePage로 매핑 (HID 표준 기반)
        let (usage, usagePage) = mapKeyCodeToUsage(keyCode)
        
        // keyCode를 문자열로 변환
        let keyCodeString = keyCodeToString(keyCode)
        
        // Modifiers를 문자열로 변환
        let modifiersString = modifiersToString(modifiers)
        
        return KeyEventData(
            keyCode: keyCode,
            keyCodeString: keyCodeString,
            usage: usage,
            usagePage: usagePage,
            modifiers: modifiers,
            modifiersString: modifiersString,
            character: character,
            characterIgnoringModifiers: character
        )
    }
    
    /// keyCode를 usage, usagePage로 매핑 (HID 표준 기반)
    private static func mapKeyCodeToUsage(_ keyCode: UInt16) -> (usage: String, usagePage: String) {
        let usagePage = "7 (0x0007)"  // Generic Desktop Page (키보드)
        
        switch keyCode {
        case 0: return ("4 (0x0004)", usagePage)     // A
        case 1: return ("22 (0x0016)", usagePage)    // S
        case 2: return ("7 (0x0007)", usagePage)     // D
        case 3: return ("9 (0x0009)", usagePage)     // F
        case 4: return ("11 (0x000b)", usagePage)    // H
        case 5: return ("10 (0x000a)", usagePage)    // G
        case 6: return ("29 (0x001d)", usagePage)    // Z
        case 7: return ("27 (0x001b)", usagePage)    // X
        case 8: return ("6 (0x0006)", usagePage)     // C
        case 9: return ("25 (0x0019)", usagePage)    // V
        case 11: return ("5 (0x0005)", usagePage)    // B
        case 12: return ("20 (0x0014)", usagePage)   // Q
        case 13: return ("26 (0x001a)", usagePage)   // W -> J (Option+J = ∆)
        case 14: return ("8 (0x0008)", usagePage)    // E
        case 15: return ("21 (0x0015)", usagePage)   // R
        case 16: return ("28 (0x001c)", usagePage)   // Y
        case 17: return ("23 (0x0017)", usagePage)   // T
        case 18: return ("30 (0x001e)", usagePage)   // 1
        case 19: return ("31 (0x001f)", usagePage)   // 2
        case 20: return ("32 (0x0020)", usagePage)   // 3
        case 21: return ("33 (0x0021)", usagePage)   // 4
        case 22: return ("35 (0x0023)", usagePage)   // 6
        case 23: return ("34 (0x0022)", usagePage)   // 5
        case 24: return ("46 (0x002e)", usagePage)   // =
        case 25: return ("38 (0x0026)", usagePage)   // 9
        case 26: return ("36 (0x0024)", usagePage)   // 7
        case 27: return ("45 (0x002d)", usagePage)   // -
        case 28: return ("37 (0x0025)", usagePage)   // 8
        case 29: return ("39 (0x0027)", usagePage)   // 0
        case 30: return ("48 (0x0030)", usagePage)   // ]
        case 31: return ("18 (0x0012)", usagePage)   // O
        case 32: return ("24 (0x0018)", usagePage)   // U
        case 33: return ("47 (0x002f)", usagePage)   // [
        case 34: return ("12 (0x000c)", usagePage)   // I
        case 35: return ("19 (0x0013)", usagePage)   // P
        case 36: return ("40 (0x0028)", usagePage)   // Return
        case 37: return ("15 (0x000f)", usagePage)   // L -> Option+L = ¬
        case 38: return ("13 (0x000d)", usagePage)   // J -> Option+J = ∆
        case 39: return ("52 (0x0034)", usagePage)   // '
        case 40: return ("14 (0x000e)", usagePage)   // K -> Option+K = ˚
        case 41: return ("51 (0x0033)", usagePage)   // ;
        case 42: return ("49 (0x0031)", usagePage)   // \
        case 43: return ("54 (0x0036)", usagePage)   // , (Comma)
        case 44: return ("56 (0x0038)", usagePage)   // /
        case 45: return ("17 (0x0011)", usagePage)   // N
        case 46: return ("16 (0x0010)", usagePage)   // M
        case 47: return ("55 (0x0037)", usagePage)   // .
        case 48: return ("43 (0x002b)", usagePage)   // Tab
        case 49: return ("44 (0x002c)", usagePage)   // Space
        case 50: return ("53 (0x0035)", usagePage)   // ` (Backtick)
        case 64: return ("95 (0x005f)", usagePage)   // JIS Keypad Comma (◊)
        case 65: return ("99 (0x0063)", "8 (0x0008)") // Keypad . (Period) -> LED/Keypad Page? usagePage is 7. Let's stick to standard 7 for consistency or map correctly if different. Usage for Keypad . is 99 (0x63).
        case 67: return ("85 (0x0055)", usagePage)   // Keypad *
        case 69: return ("87 (0x0057)", usagePage)   // Keypad +
        case 71: return ("83 (0x0053)", usagePage)   // Keypad Clear / NumLock
        case 75: return ("84 (0x0054)", usagePage)   // Keypad /
        case 76: return ("88 (0x0058)", usagePage)   // Keypad Enter
        case 78: return ("86 (0x0056)", usagePage)   // Keypad -
        case 81: return ("103 (0x0067)", usagePage)  // Keypad =
        case 82: return ("98 (0x0062)", usagePage)   // Keypad 0
        case 83: return ("89 (0x0059)", usagePage)   // Keypad 1
        case 84: return ("90 (0x005a)", usagePage)   // Keypad 2
        case 85: return ("91 (0x005b)", usagePage)   // Keypad 3
        case 86: return ("92 (0x005c)", usagePage)   // Keypad 4
        case 87: return ("93 (0x005d)", usagePage)   // Keypad 5
        case 88: return ("94 (0x005e)", usagePage)   // Keypad 6
        case 89: return ("95 (0x005f)", usagePage)   // Keypad 7
        case 91: return ("96 (0x0060)", usagePage)   // Keypad 8
        case 92: return ("97 (0x0061)", usagePage)   // Keypad 9
        case 95: return ("95 (0x005f)", usagePage)   // unknown_95 (◊)
        default: return ("\(keyCode) (0x\(String(keyCode, radix: 16, uppercase: true).padded(toLength: 4)))", usagePage)
        }
    }
    
    /// keyCode를 문자열로 변환
    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        // 1. Check SharedKeyMap first (SSOT for Keypad)
        if let sharedName = SharedKeyMap.numpadMapping[keyCode] {
            return sharedName.count > 1 ? "{\(sharedName)}" : sharedName
        }

        let keyName: String
        switch keyCode {
        case 0: keyName = "a"
        case 1: keyName = "s"
        case 2: keyName = "d"
        case 3: keyName = "f"
        case 4: keyName = "h"
        case 5: keyName = "g"
        case 6: keyName = "z"
        case 7: keyName = "x"
        case 8: keyName = "c"
        case 9: keyName = "v"
        case 11: keyName = "b"
        case 12: keyName = "q"
        case 13: keyName = "j"  // Option+J = ∆
        case 14: keyName = "e"
        case 15: keyName = "r"
        case 16: keyName = "y"
        case 17: keyName = "t"
        case 37: keyName = "l"  // Option+L = ¬
        case 38: keyName = "j"  // J key
        case 40: keyName = "k"  // Option+K = ˚
        case 43: keyName = ","  // Comma
        case 50: keyName = "`"  // Backtick
        case 95: keyName = "unknown_95"    // Special key 95 (If not in SharedKeyMap)
        default: keyName = "unknown_\(keyCode)"
        }
        
        return keyName.count > 1 ? "{\(keyName)}" : keyName
    }
    
    /// CGEventFlags를 문자열로 변환
    static func modifiersToString(_ modifiers: CGEventFlags) -> String {
        var components: [String] = []
        
        if modifiers.contains(.maskShift) {
            if modifiers.contains(.maskSecondaryFn) { // Right shift
                components.append("flags right_shift")
            } else {
                components.append("flags left_shift")
            }
        }
        
        if modifiers.contains(.maskControl) {
            components.append("flags left_control")
        }
        
        if modifiers.contains(.maskAlternate) {
            components.append("flags left_option")
        }
        
        if modifiers.contains(.maskCommand) {
            components.append("flags left_command")
        }
        
        if modifiers.contains(.maskSecondaryFn) && !modifiers.contains(.maskShift) {
            components.append("flags fn")
        }
        
        return components.joined(separator: " ")
    }
}

/// 키 이벤트 데이터 구조체
struct KeyEventData {
    let keyCode: UInt16
    let keyCodeString: String           // "j", "unknown_95" 등
    let usage: String                   // "13 (0x000d)" 등
    let usagePage: String               // "7 (0x0007)"
    let modifiers: CGEventFlags
    let modifiersString: String         // "flags left_option" 등
    let character: String               // 실제 입력된 문자 (modifiers 적용)
    let characterIgnoringModifiers: String  // modifiers 무시한 기본 문자
    
    /// KeyLogger 출력 형식으로 변환 (keyDown 이벤트 반영)
    var keyLoggerFormat: String {
        return """
        {"type":"down","name":{"key_code":"\(keyCodeString.padded(toLength: 20))"},"usagePage":"\(usagePage)","usage":"\(usage.padded(toLength: 12))","misc":"\(modifiersString.padded(toLength: 25))"}
        """
    }
    
    /// 디버그용 간단 형식
    var debugFormat: String {
        return "keyCode: \(keyCode), chars: '\(character)', charsIgnoring: '\(characterIgnoringModifiers)', modifiers: \(modifiers.rawValue)"
    }
}

// MARK: - String Extension

extension String {
    /// 지정된 길이로 패딩 (KeyLogger 형식 맞추기용)
    func padded(toLength length: Int, with character: Character = " ") -> String {
        let padding = max(0, length - self.count)
        return self + String(repeating: character, count: padding)
    }
}

// Issue392: Context Awareness Utility (Merged to avoid pbxproj/file addition issues)
class ContextUtils {
    static let shared = ContextUtils()
    
    // [Issue Debug] Prevent log spam for apps not supporting AXWindowNumber
    private var failedPIDs: Set<pid_t> = []
    private let lock = NSLock()
    
    private init() {}
    
    /// 현재 활성 앱의 포커스된 윈도우 ID를 반환
    /// - Returns: (PID, WindowID) 튜플. 실패 시 nil.
    func getCurrentFocusedWindowID() -> (pid_t, CGWindowID)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        
        // Check if we already failed for this PID to avoid log spam
        // Note: Not locking for read to keep it fast, worst case we log twice.
        // But for write/update we should be careful if accessed from multiple threads.
        // AppActivationMonitor is main thread usually, but let's be safe.
        
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: AnyObject?
        
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let windowElement = focusedWindow as! AXUIElement? {
            var windowIdRef: AnyObject?
            // "AXWindowNumber" is unlikely to fail if the app is accessible, but let's log if it does.
            // Some apps (Electron based) might not expose it easily.
            let idResult = AXUIElementCopyAttributeValue(windowElement, "AXWindowNumber" as CFString, &windowIdRef)
            
            if idResult == .success, let idNum = windowIdRef as? NSNumber {
                return (pid, CGWindowID(idNum.uint32Value))
            } else {
                // [Debug] Log failure only ONCE per PID
                lock.lock()
                if !failedPIDs.contains(pid) {
                    // Use global logger if available (logW is not visible here easily without import, assume print is fine or use logW if file is in same module)
                    // Since this file is in Utils, and Logger is in Data, we might need import or just use print with prefix.
                    // The user code showed `logW` is global func. Let's try to use it if Utils imports Data or similar.
                    // But to be safe and match previous style:
                    // logW("🧪 ⚠️ [ContextUtils] Failed to get AXWindowNumber for PID \(pid). Result: \(idResult.rawValue) (Suppressing further logs for this PID)")
                    failedPIDs.insert(pid)
                }
                lock.unlock()
            }
        } else {
             // [Debug]
             // print("⚠️ [ContextUtils] Failed to get kAXFocusedWindow for PID \(pid). Result: \(result.rawValue)")
        }
        
        // Fallback: CGWindowList (Robust method for non-AX apps)
        // If AX failed, try finding the top on-screen window for this PID.
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] {
            for entry in windowList {
                if let ownerPID = entry[kCGWindowOwnerPID as String] as? Int, ownerPID == Int(pid) {
                    // This is the top window of the active app
                    if let windowID = entry[kCGWindowNumber as String] as? Int {
                        // print("🔧 [ContextUtils] Fallback to CGWindowList: PID \(pid) -> WindowID \(windowID)")
                        return (pid, CGWindowID(windowID))
                    }
                }
            }
        }
        
        // Final Fallback: Return (pid, 0) if all else fails.
        return (pid, 0) 
    }
}