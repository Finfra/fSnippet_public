#!/usr/bin/env swift

import Foundation
import Carbon
import CoreGraphics

class KeyLogger {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let tempDir: String
    private let logDir: String // Added logDir
    private let logPath: String
    private let sequenceFilePath: String
    private let lockFilePath: String
    private let nextIdFilePath: String
    private let fSnippetLogPath: String
    
    private let onlyDown: Bool
    
    // ✅ Static shared path for signal handler
    static var sharedLogPath: String = "/tmp/fkey.log"
    
    // ✅ DateFormatter 싱글톤 (성능 향상) - Static for signal handler
    static let sharedTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    // Instance accessor for convenience
    private var timestampFormatter: DateFormatter {
        return KeyLogger.sharedTimestampFormatter
    }

    private let keyCodeToName: [CGKeyCode: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "equal", 25: "9", 26: "7", 27: "hyphen",
        28: "8", 29: "0", 30: "right_bracket", 31: "o", 32: "u", 33: "left_bracket",
        34: "i", 35: "p", 36: "return", 37: "l", 38: "j", 39: "quote", 40: "k",
        41: "semicolon", 42: "backslash", 43: "comma", 44: "slash", 45: "n", 46: "m",
        47: "period", 48: "tab", 49: "space", 50: "grave", 51: "delete", 53: "escape",
        54: "right_command", 55: "left_command", 56: "left_shift", 57: "caps_lock",
        58: "left_option", 59: "left_control", 60: "right_shift", 61: "right_option",
        62: "right_control", 63: "function", 64: "f17", 65: "keypad_decimal", 67: "keypad_multiply",
        69: "keypad_plus", 71: "keypad_clear", 72: "volume_up", 73: "volume_down",
        74: "mute", 75: "keypad_divide", 76: "keypad_enter", 78: "keypad_minus",
        79: "f18", 80: "f19", 81: "keypad_equals", 82: "keypad_0", 83: "keypad_1",
        84: "keypad_2", 85: "keypad_3", 86: "keypad_4", 87: "keypad_5", 88: "keypad_6",
        89: "keypad_7", 90: "f20", 91: "keypad_8", 92: "keypad_9", 96: "f5", 97: "f6",
        98: "f7", 99: "f3", 100: "f8", 101: "f9", 103: "f11", 105: "f13", 106: "f16",
        107: "f14", 109: "f10", 111: "f12", 113: "f15", 114: "help", 115: "home",
        116: "page_up", 117: "forward_delete", 118: "f4", 119: "end", 120: "f2",
        121: "page_down", 122: "f1", 123: "left_arrow", 124: "right_arrow", 125: "down_arrow",
        126: "up_arrow", 133: "keypad_comma"
    ]
    
    // Usage code mapping for common keys
    private func getUsageCode(for keyCode: CGKeyCode) -> UInt32 {
        switch keyCode {
        case 0: return 4    // a
        case 1: return 22   // s
        case 2: return 7    // d
        case 3: return 9    // f
        case 4: return 11   // h
        case 5: return 10   // g
        case 6: return 29   // z
        case 7: return 27   // x
        case 8: return 6    // c
        case 9: return 25   // v
        case 11: return 5   // b
        case 12: return 20  // q
        case 13: return 26  // w
        case 14: return 8   // e
        case 15: return 21  // r
        case 16: return 28  // y
        case 17: return 23  // t
        case 38: return 13  // j
        case 46: return 16  // m
        case 55: return 227 // left_command
        case 56: return 225 // left_shift
        case 58: return 226 // left_option
        case 59: return 224 // left_control
        case 133: return 133 // keypad_comma
        default: return UInt32(keyCode)
        }
    }
    
    init(onlyDown: Bool = false, tempDir: String = "/tmp", logDir: String? = nil) {
        self.onlyDown = onlyDown
        self.tempDir = tempDir
        self.logDir = logDir ?? tempDir // Default to tempDir if not provided
        
        self.logPath = "\(self.logDir)/fkey.log"
        self.fSnippetLogPath = "\(self.logDir)/fSnippet.log"
        
        // Sequence files remain in tempDir for safety/speed
        self.sequenceFilePath = "\(tempDir)/fSnippet_sequence.counter"
        self.lockFilePath = "\(tempDir)/fSnippet_sequence.lock"
        self.nextIdFilePath = "\(tempDir)/fSnippet_next_sequence.id"
        
        // Update static shared path for signal handler
        KeyLogger.sharedLogPath = self.logPath
        
        initializeSequenceFile()
        setupEventTap()
    }

    /// 시퀀스 파일 초기화
    private func initializeSequenceFile() {
        if !FileManager.default.fileExists(atPath: sequenceFilePath) {
            do {
                try "0".write(toFile: sequenceFilePath, atomically: true, encoding: .utf8)
                print("Sequence file initialized: \(sequenceFilePath)")
            } catch {
                print("Error initializing sequence file: \(error)")
            }
        }
    }

    /// KeyLogger 전용 시퀀스 ID 생성 및 다음 ID 공유
    private func getNextSequenceId() -> Int64 {
        // 경로 속성 사용 (lockFilePath, nextIdFilePath 등 이미 초기화됨)

        do {
            // 락 파일을 통한 동기화
            let lockFileURL = URL(fileURLWithPath: lockFilePath)

            // 파일이 없으면 0으로 초기화
            if !FileManager.default.fileExists(atPath: sequenceFilePath) {
                try "0".write(toFile: sequenceFilePath, atomically: true, encoding: .utf8)
            }

            // 락 파일 생성 및 배타적 접근
            var attempts = 0
            while attempts < 10 {
                if !FileManager.default.fileExists(atPath: lockFilePath) {
                    do {
                        // 락 파일 생성 시도
                        try "locked".write(to: lockFileURL, atomically: false, encoding: .utf8)
                        break
                    } catch {
                        // 락 파일 생성 실패 시 잠시 대기
                        usleep(1000) // 1ms 대기
                        attempts += 1
                        continue
                    }
                } else {
                    // 다른 프로세스가 락을 가지고 있음
                    usleep(1000) // 1ms 대기
                    attempts += 1
                }
            }

            defer {
                // 락 파일 제거
                try? FileManager.default.removeItem(at: lockFileURL)
            }

            // 현재 값 읽기
            let currentString = try String(contentsOfFile: sequenceFilePath, encoding: .utf8)
            let currentValue = Int64(currentString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            // KeyLogger가 사용할 현재 시퀀스 ID
            let currentSequenceId = currentValue + 1

            // fSnippet이 사용할 다음 시퀀스 ID를 미리 준비
            let nextSequenceId = currentSequenceId + 1

            // 카운터 파일 업데이트 (KeyLogger가 사용한 ID로)
            try "\(currentSequenceId)".write(toFile: sequenceFilePath, atomically: true, encoding: .utf8)

            // fSnippet이 사용할 다음 ID 파일 생성/업데이트
            try "\(nextSequenceId)".write(toFile: nextIdFilePath, atomically: true, encoding: .utf8)

            return currentSequenceId
        } catch {
            print("Error reading/writing sequence file: \(error)")
            return 0
        }
    }

    /// 시퀀스 카운터 리셋 (로그 세션 시작 시)
    private func resetSequenceCounter() {
        do {
            try "0".write(toFile: sequenceFilePath, atomically: true, encoding: .utf8)
            print("Sequence counter reset to 0")
        } catch {
            print("Error resetting sequence: \(error)")
        }
    }

    /// 로그 파일 클리어 (fSnippet.log와 동기화)
    func clearLogFile() {
        do {
            // fkey.log 클리어
            if FileManager.default.fileExists(atPath: logPath) {
                try FileManager.default.removeItem(atPath: logPath)
            }

            // fSnippet.log도 함께 클리어 (동기화)
            // let fSnippetLogPath = "/tmp/fSnippet.log" // Property used instead
            if FileManager.default.fileExists(atPath: fSnippetLogPath) {
                try FileManager.default.removeItem(atPath: fSnippetLogPath)

                // fSnippet.log 재생성
                let clearTime = timestampFormatter.string(from: Date())
                let fSnippetMessage = "\n=== fSnippet 로그 클리어 by KeyLogger [\(clearTime)] ===\n"
                try fSnippetMessage.write(toFile: fSnippetLogPath, atomically: true, encoding: .utf8)
            }

            // fkey.log 재생성
            let clearTime = timestampFormatter.string(from: Date())
            let clearMessage = """
# ========================================
# KeyLogger Log Cleared: \(clearTime)
# Only-Down Mode: \(onlyDown ? "ON" : "OFF")
# Event Sequence Format: [timestamp:sequenceId]
# Sequence synchronized with fSnippet.log
# ========================================

"""
            try clearMessage.write(toFile: logPath, atomically: true, encoding: .utf8)

            print("🗑️ 로그 파일들이 동기화되어 클리어되었습니다:")
            print("   - fkey.log: \(logPath)")
            print("   - fSnippet.log: \(fSnippetLogPath)")
        } catch {
            print("❌ 로그 클리어 실패: \(error)")
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        print("Creating event tap...")
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let keyLogger = Unmanaged<KeyLogger>.fromOpaque(refcon!).takeUnretainedValue()
                keyLogger.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap. Make sure the app has accessibility permissions.")
            print("Try: System Preferences → Security & Privacy → Privacy → Accessibility")
            print("Add Terminal or the application running this script.")
            exit(1)
        }
        
        print("Event tap created successfully")
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("Event tap enabled and added to run loop")
        
        // Add session header without clearing existing log file
        do {
            // ✅ 시퀀스 ID는 기존 값 유지 (리셋하지 않음)
            // resetSequenceCounter() // 제거됨 - 기존 시퀀스 유지

            // ✅ 싱글톤 formatter 사용
            let startTime = timestampFormatter.string(from: Date())

            let sessionHeader = """

            # ========================================
            # KeyLogger Session Resumed: \(startTime)
            # Only-Down Mode: \(onlyDown ? "ON" : "OFF")
            # Event Sequence Format: [timestamp:sequenceId]
            # Sequence synchronized with fSnippet.log
            # ========================================

            """

            // ✅ 기존 파일에 추가 (덮어쓰지 않음)
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(sessionHeader.data(using: .utf8)!)
                    fileHandle.closeFile()
                }
            } else {
                // 파일이 없으면 새로 생성
                try sessionHeader.write(toFile: logPath, atomically: true, encoding: .utf8)
            }

            print("Log file session header added: \(logPath)")
            print("Event sequence tracking enabled - format: [timestamp:sequenceId]")
            print("Sequence ID synchronized with fSnippet: \(sequenceFilePath)")
        } catch {
            print("Warning: Could not add session header: \(error)")
        }
    }
    
    private var isFirstEvent = true
    
    private func handleEvent(type: CGEventType, event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        var eventData: [String: Any] = [:]
        
        switch type {
        case .keyDown:
            eventData["type"] = "down"
        case .keyUp:
            if onlyDown { return }  // Skip up events if only-down mode
            eventData["type"] = "up"
        case .flagsChanged:
            // Handle modifier keys
            handleFlagsChanged(keyCode: keyCode, flags: flags)
            return
        default:
            return
        }
        
        let keyName = keyCodeToName[keyCode] ?? "unknown_\(keyCode)"
        let usageCode = getUsageCode(for: keyCode)
        
        eventData["name"] = ["key_code": keyName]
        eventData["usagePage"] = "7 (0x0007)"
        eventData["usage"] = "\(usageCode) (0x\(String(format: "%04x", usageCode)))"
        
        // Add flags if any modifier is pressed
        var miscFlags: [String] = []
        if flags.contains(.maskCommand) { miscFlags.append("left_command") }
        if flags.contains(.maskShift) { miscFlags.append("left_shift") }
        if flags.contains(.maskAlternate) { miscFlags.append("left_option") }
        if flags.contains(.maskControl) { miscFlags.append("left_control") }
        
        if !miscFlags.isEmpty {
            eventData["misc"] = "flags \(miscFlags.joined(separator: " "))"
        } else {
            eventData["misc"] = ""
        }
        
        logEvent(eventData)
    }
    
    private var previousFlags: CGEventFlags = []
    
    private func handleFlagsChanged(keyCode: CGKeyCode, flags: CGEventFlags) {
        // Detect which modifier key changed
        let changedFlags = CGEventFlags(rawValue: flags.rawValue ^ previousFlags.rawValue)
        
        var keyName = ""
        var usageCode: UInt32 = 0
        
        if changedFlags.contains(.maskCommand) {
            keyName = "left_command"
            usageCode = 227
        } else if changedFlags.contains(.maskShift) {
            keyName = "left_shift" 
            usageCode = 225
        } else if changedFlags.contains(.maskAlternate) {
            keyName = "left_option"
            usageCode = 226
        } else if changedFlags.contains(.maskControl) {
            keyName = "left_control"
            usageCode = 224
        } else {
            previousFlags = flags
            return
        }
        
        let isPressed = flags.rawValue > previousFlags.rawValue
        
        var eventData: [String: Any] = [:]
        eventData["type"] = isPressed ? "down" : "up"
        eventData["name"] = ["key_code": keyName]
        eventData["usagePage"] = "7 (0x0007)"
        eventData["usage"] = "\(usageCode) (0x\(String(format: "%04x", usageCode)))"
        
        if isPressed && !keyName.isEmpty {
            eventData["misc"] = "flags \(keyName)"
        } else {
            eventData["misc"] = ""
        }
        
        // Skip up events for modifier keys if only-down mode
        if onlyDown && !isPressed {
            return
        }
        
        logEvent(eventData)
        previousFlags = flags
    }
    
    private func logEvent(_ eventData: [String: Any]) {
        do {
            // ✅ 파일 기반 시퀀스 ID 생성 (fSnippet과 동기화)
            let sequenceId = getNextSequenceId()

            // ✅ 싱글톤 DateFormatter 사용 (성능 향상)
            let timestamp = timestampFormatter.string(from: Date())

            // Create aligned JSON string with proper spacing outside quotes
            let type = eventData["type"] as! String
            let nameDict = eventData["name"] as! [String: String]
            let usagePage = eventData["usagePage"] as! String
            let usage = eventData["usage"] as! String
            let misc = eventData["misc"] as! String

            let keyCode = nameDict["key_code"]!

            // Calculate padding needed (outside of quotes)
            let keyCodePadding = String(repeating: " ", count: max(0, 20 - keyCode.count))
            let usagePadding = String(repeating: " ", count: max(0, 15 - usage.count))
            let miscPadding = String(repeating: " ", count: max(0, 25 - misc.count))

            // ✅ 타임스탬프:시퀀스ID 포함한 로그 포맷
            let jsonString = """
            [\(timestamp):\(sequenceId)] {"type":"\(type)","name":{"key_code":"\(keyCode)"\(keyCodePadding)},"usagePage":"\(usagePage)","usage":"\(usage)"\(usagePadding),"misc":"\(misc)"\(miscPadding)}
            """

            let logEntry = jsonString + "\n"

            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try logEntry.write(toFile: logPath, atomically: false, encoding: .utf8)
            }
        } catch {
            print("Error logging event: \(error)")
        }
    }
    
    func start() {
        print("Key logger started. Press Ctrl+C to stop.")
        print("Log file: \(logPath)")
        
        // Handle Ctrl+C gracefully
        signal(SIGINT) { _ in
            print("\nStopping key logger...")

            // ✅ 세션 종료 타임스탬프 기록 (Static formatter 사용)
            let endTime = KeyLogger.sharedTimestampFormatter.string(from: Date())

            let sessionFooter = """

            # ========================================
            # KeyLogger Session Ended: \(endTime)
            # ========================================
            """

            do {
                if let fileHandle = FileHandle(forWritingAtPath: KeyLogger.sharedLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(sessionFooter.data(using: .utf8)!)
                    fileHandle.closeFile()
                }
            } catch {
                print("Warning: Could not write session footer")
            }

            exit(0)
        }
        
        print("Starting run loop...")
        CFRunLoopRun()
        print("Run loop ended (this shouldn't happen)")
    }
    
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        // Clean up resources
    }
}

// Main execution
let arguments = CommandLine.arguments
let onlyDown = arguments.contains("--only-down")

// Parse --temp-dir argument
var tempDir = "/tmp" // Default fallback
if let index = arguments.firstIndex(of: "--temp-dir"), index + 1 < arguments.count {
    tempDir = arguments[index + 1]
    // Remove trailing slash if present
    if tempDir.hasSuffix("/") {
        tempDir = String(tempDir.dropLast())
    }
}

// Parse --log-dir argument
var logDir: String? = nil
if let index = arguments.firstIndex(of: "--log-dir"), index + 1 < arguments.count {
    var rawLogDir = arguments[index + 1]
    // Remove trailing slash if present
    if rawLogDir.hasSuffix("/") {
        rawLogDir = String(rawLogDir.dropLast())
    }
    logDir = rawLogDir
}

if onlyDown {
    print("Running in --only-down mode (only keyDown events)")
}
print("Using temp directory: \(tempDir)")
if let logDir = logDir {
    print("Using log directory: \(logDir)")
}

let keyLogger = KeyLogger(onlyDown: onlyDown, tempDir: tempDir, logDir: logDir)
keyLogger.start()