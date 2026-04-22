import Foundation
import os.log

/// 로그 레벨 정의 (호환성)
public enum LogLevel: Int, CaseIterable, CustomStringConvertible {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public var description: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    public var localizedDescription: String {
        switch self {
        case .verbose: return NSLocalizedString("log.level.verbose", comment: "Verbose")
        case .debug: return NSLocalizedString("log.level.debug", comment: "Debug")
        case .info: return NSLocalizedString("log.level.info", comment: "Info")
        case .warning: return NSLocalizedString("log.level.warning", comment: "Warning")
        case .error: return NSLocalizedString("log.level.error", comment: "Error")
        case .critical: return NSLocalizedString("log.level.critical", comment: "Critical")
        }
    }

    public var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// 간소화된 fSnippet 로거
class Logger {
    static let shared = Logger()
    private let osLog = OSLog(subsystem: "com.nowage.fSnippet", category: "main")

    // ✅ App Sandbox 호환: Documents/finfra/fSnippet/<bundleId>/logs 사용
    private var logDirectoryURL: URL = {
        let fileManager = FileManager.default
        let appRootPath = PreferencesManager.resolveAppRootPath()

        let logDir = URL(fileURLWithPath: appRootPath).appendingPathComponent("logs")

        // 디렉토리 생성
        try? fileManager.createDirectory(
            at: logDir, withIntermediateDirectories: true, attributes: nil)

        // [Issue225] 디버그 로그 활성화 전에는 빈 파일 생성 방지 (옵션)
        // 여기서는 디렉토리만 생성하고 파일은 createLogFileIfNeeded에서 처리

        #if DEBUG
            print("🔧 [DEBUG] 로그 디렉토리 설정: \(logDir.path)")
        #endif
        return logDir
    }()

    private lazy var logFileURL: URL = {
        return logDirectoryURL.appendingPathComponent("flog.log")
    }()

    private let queue = DispatchQueue(label: "com.nowage.fSnippet.logger", qos: .utility)

    /// 현재 로그 레벨 (호환성)
    var currentLogLevel: LogLevel = .debug  // AppInitializer에서 적절히 설정됨

    // [Issue225] 파일 로깅 활성화 여부 (Master Switch)
    var isFileLoggingEnabled: Bool = true

    // ✅ DateFormatter 싱글톤 (성능 향상)
    private lazy var timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private lazy var dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // ✅ 하이브리드 시퀀스 ID 시스템 (메모리 기반 + 파일 기반 동기화)
    private static var memoryEventSequence: Int64 = 0

    private init() {
        // 최우선 실행: 로그 파일 동기식 생성
        #if DEBUG
            print("🔧 [DEBUG] Logger.init() 시작")
        #endif

        // 로그 파일 즉시 초기화 (동기식)
        createLogFileIfNeeded()

        // 초기화 완료 메시지 출력
        #if DEBUG
            print("✅ Logger 초기화 완료 - 로그 파일: \(logFileURL.path)")
            print("🔧 [DEBUG] Logger.init() 완료")
        #endif
    }

    /// 로그 파일 생성 (동기식으로 변경) - Truncate on Start
    private func createLogFileIfNeeded() {
        #if DEBUG
            print("🔧 [DEBUG] createLogFileIfNeeded() 시작")
            print("🔧 [DEBUG] 로그 파일 경로: \(self.logFileURL.path)")
        #endif

        // Truncate 기능: 시작 시 항상 새로 생성/덮어쓰기 (Debug/Release 공통)
        let startupMessage =
            "\n=== fSnippet 로그 시작 [\(self.formatTimestamp(Date()))] ======================================================\n"
        do {
            // [수정] atomically: false로 설정하여 inode 유지 (tail -f 호환성)
            try startupMessage.write(to: self.logFileURL, atomically: false, encoding: .utf8)
            #if DEBUG
                print("✅ 로그 파일 초기화(Truncate) 완료: \(self.logFileURL.path)")
            #endif
        } catch {
            print("❌ 로그 파일 생성 실패: \(error)")
        }

        #if DEBUG
            print("🔧 [DEBUG] createLogFileIfNeeded() 완료")
        #endif
    }

    /// 파일에 로그 쓰기 (Double Logging)
    private func writeToLogFile(_ message: String, level: LogLevel? = nil) {
        // [Issue225] 파일 로깅 비활성화 시 즉시 리턴
        // [Issue 5] Fix: Critical/Error 로그는 설정과 무관하게 항상 기록
        let isForceLog = (level == .error || level == .critical)

        guard isFileLoggingEnabled || isForceLog else {
            #if DEBUG
                // print("🚫 [FileLog Skipped] \(message)") // Uncomment for verbose debug
            #endif
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            let timestampedMessage = "[\(self.formatTimestamp(Date()))] \(message)\n"
            guard let data = timestampedMessage.data(using: .utf8) else { return }

            // 1. 실시간 로그: flog.log (시작 시 Truncate, 실행 중 Append)
            self.appendToFile(url: self.logFileURL, data: data)

            // 2. 아카이브 로그: flog_{Date_Time}.log (항상 Append)
            // [수정] Issue: 날짜만 있으면 덮어씌워지거나 구분이 어려움 -> 시분초 추가
            // 매 로그마다 파일명이 바뀌면 안되므로, init 시점에 생성된 sessionDateString을 사용해야 함.
            // 하지만 현재 구조에서는 writeToLogFile 내에서 Date()를 다시 부르고 있었음.
            // 세션별로 파일을 나누려면 Logger init 시점에 타임스탬프를 고정해야 함.

            let archivedLogURL = self.logDirectoryURL.appendingPathComponent(
                "flog_\(self.sessionDateString).log")
            self.appendToFile(url: archivedLogURL, data: data)
        }
    }

    // [추가] 세션 시작 시점의 타임스탬프 (파일명용)
    private lazy var sessionDateString: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }()

    private func appendToFile(url: URL, data: Data) {
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }

    /// KeyLogger 실행 상태 (AppInitializer에서 설정)
    static var isKeyLoggerActive: Bool = false

    /// 메모리 기반 시퀀스 ID 초기화 (앱 시작 시)
    static func resetMemorySequence() {
        memoryEventSequence = 0
        logger.info("📇 🔄 메모리 시퀀스 ID를 0으로 초기화")
    }

    /// 일반 로그용 타임스탬프 포맷 (시퀀스 ID 없음)
    private func formatTimestamp(_ date: Date) -> String {
        // ✅ 일반 로그는 시퀀스 ID 없이 타임스탬프만 사용
        return timestampFormatter.string(from: date)
    }

    /// 키 이벤트 전용 타임스탬프 (KeyLogger와 완전 동기화)
    func formatKeyEventTimestamp(_ date: Date) -> String {
        let sequenceId = getSharedSequenceId()
        let timestamp = timestampFormatter.string(from: date)
        return "\(timestamp):\(sequenceId)"
    }

    /// KeyLogger 프로세스 실행 여부 확인
    private func isKeyLoggerRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "KeyLogger.swift"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// KeyLogger가 사용한 현재 시퀀스 ID 읽기 (동일한 키 이벤트에 대해 같은 ID 사용)
    private func getSharedSequenceId() -> Int64 {
        // Issue173: 샌드박스 안전한 경로 사용 (NSTemporaryDirectory)
        let tempDir = NSTemporaryDirectory()
        let currentSequenceFilePath = (tempDir as NSString).appendingPathComponent(
            "fSnippet_sequence.counter")

        do {
            // KeyLogger가 사용한 현재 시퀀스 ID 파일이 없으면 기본값 사용
            if !FileManager.default.fileExists(atPath: currentSequenceFilePath) {
                // KeyLogger가 아직 시작되지 않은 경우 메모리 기반 폴백
                return OSAtomicIncrement64(&Self.memoryEventSequence)
            }

            // KeyLogger가 사용한 현재 시퀀스 ID 읽기
            let currentIdString = try String(
                contentsOfFile: currentSequenceFilePath, encoding: .utf8)
            let currentId =
                Int64(currentIdString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            if currentId > 0 {
                // KeyLogger가 사용한 동일한 시퀀스 ID 반환
                return currentId
            } else {
                // 유효하지 않은 경우 메모리 기반 폴백
                return OSAtomicIncrement64(&Self.memoryEventSequence)
            }

        } catch {
            // 파일 기반 실패 시 메모리 기반으로 폴백
            return OSAtomicIncrement64(&Self.memoryEventSequence)
        }
    }

    /// 정보 로그 (레이지 평가)
    func info(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.info.rawValue else { return }
        let evaluatedMessage = message()
        let logMessage = "ℹ️ INFO: \(evaluatedMessage)"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .info, logMessage)
        #endif
        writeToLogFile(logMessage, level: .info)
    }

    /// 키 이벤트 전용 로그 (KeyLogger와 완전 동기화)
    func keyEventInfo(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.debug.rawValue else { return }
        let evaluatedMessage = message()

        // 키 이벤트용 특별 타임스탬프 사용
        let keyEventTimestamp = formatKeyEventTimestamp(Date())
        let logMessage = "[\(keyEventTimestamp)] 🔍 DEBUG: \(evaluatedMessage)"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .debug, logMessage)
        #endif

        // 키 이벤트 로그는 별도로 파일에 기록
        queue.async { [weak self] in
            guard let self = self else { return }

            // [Issue225] 파일 로깅 비활성화 시 파일 쓰기 스킵
            // (Note: 키 이벤트 로그는 중요하므로 LogLevel.debug가 켜져있으면 기록해야 하는지?
            //  Issue 명세에 "debug off 시 flog.log 파일 쓰기를 원천 차단"이라고 했으므로 차단함)
            guard self.isFileLoggingEnabled else { return }

            let finalMessage = "\(logMessage)\n"

            if let data = finalMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
        }
    }

    /// 에러 로그 (레이지 평가)
    func error(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.error.rawValue else { return }
        let evaluatedMessage = message()
        let logMessage = "❌ ERROR: \(evaluatedMessage)"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .error, logMessage)
        #endif
        writeToLogFile(logMessage, level: .error)
    }

    /// 디버그 로그 (레이지 평가, 개발용)
    func debug(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.debug.rawValue else { return }
        #if DEBUG
            let evaluatedMessage = message()
            let logMessage = "🐛 DEBUG: \(evaluatedMessage)"

            print(logMessage)
            writeToLogFile(logMessage, level: .debug)
        #endif
    }

    /// verbose 로그 (레이지 평가, 개발용)
    func verbose(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.verbose.rawValue else { return }
        #if DEBUG
            let evaluatedMessage = message()
            let logMessage = "💬 VERBOSE: \(evaluatedMessage)"

            print(logMessage)
            writeToLogFile(logMessage, level: .verbose)
        #endif
    }

    /// 경고 로그 (레이지 평가)
    func warning(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.warning.rawValue else { return }
        let evaluatedMessage = message()
        let logMessage = "⚠️ WARNING: \(evaluatedMessage)"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .default, logMessage)
        #endif
        writeToLogFile(logMessage, level: .warning)
    }

    /// 치명적 오류 로그 (레이지 평가)
    func critical(_ message: @autoclosure () -> String) {
        guard currentLogLevel.rawValue <= LogLevel.critical.rawValue else { return }
        let evaluatedMessage = message()
        let logMessage = "🚨 CRITICAL: \(evaluatedMessage)"

        #if DEBUG
            print(logMessage)
        #else
            os_log("%{public}@", log: osLog, type: .fault, logMessage)
        #endif
        writeToLogFile(logMessage, level: .critical)
    }

    /// 로그 레벨 설정
    func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
        let logMessage = "🔧 로그 레벨 변경: \(level.emoji) \(level.description)"
        #if DEBUG
            print(logMessage)
        #endif
        writeToLogFile(logMessage)

        // ✅ 로그 레벨 변경 알림 전송 (KeyLogger 자동 관리용)
        NotificationCenter.default.post(name: .logLevelDidChange, object: level)
    }

    /// 비동기 쓰기 큐가 완료될 때까지 블록 (앱 종료 직전 호출)
    func flush() {
        queue.sync {}
    }

    /// 로그 파일 경로 반환
    func getLogFilePath() -> String {
        return logFileURL.path
    }

    /// 로그 파일 크기 확인
    func getLogFileSize() -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
            let fileSize = attributes[FileAttributeKey.size] as? NSNumber
        else {
            return 0
        }
        return fileSize.int64Value
    }

    /// 로그 파일 삭제 (로그 클리어) - fkey.log와 동기화
    func clearLogFile() {
        #if DEBUG
            print("🔥 clearLogFile() 호출됨!")
        #endif
        queue.async { [weak self] in
            guard let self = self else { return }
            #if DEBUG
                print("🔥 clearLogFile() 큐 실행 시작")
            #endif

            do {
                // fSnippet.log 클리어
                try FileManager.default.removeItem(at: self.logFileURL)
                let clearMessage =
                    "\n=== fSnippet 로그 클리어 후 재시작 [\(self.formatTimestamp(Date()))] ======================================================\n"
                try clearMessage.write(to: self.logFileURL, atomically: true, encoding: .utf8)

                // fkey.log도 함께 클리어 (동기화)
                // Issue173: 샌드박스 안전한 경로 사용
                let tempDir = NSTemporaryDirectory()
                let fkeyLogPath = (tempDir as NSString).appendingPathComponent("fkey.log")
                if FileManager.default.fileExists(atPath: fkeyLogPath) {
                    try FileManager.default.removeItem(atPath: fkeyLogPath)

                    // fkey.log 재생성 (KeyLogger와 동일한 형식)
                    let clearTime = self.timestampFormatter.string(from: Date())
                    let fkeyMessage = """
                        # ========================================
                        # KeyLogger Log Cleared by fSnippet: \(clearTime)
                        # Only-Down Mode: Unknown
                        # Event Sequence Format: [timestamp:sequenceId]
                        # Sequence synchronized with fSnippet.log
                        # ========================================

                        """
                    try fkeyMessage.write(toFile: fkeyLogPath, atomically: true, encoding: .utf8)
                }

                DispatchQueue.main.async {
                    #if DEBUG
                        print("🗑️ 로그 파일들이 동기화되어 클리어되었습니다:")
                        print("   - fSnippet.log: \(self.logFileURL.path)")
                        print("   - fkey.log: \(fkeyLogPath)")
                    #endif
                }
                #if DEBUG
                    print("🔥 clearLogFile() 큐 실행 완료")
                #endif
            } catch {
                DispatchQueue.main.async {
                    #if DEBUG
                        print("❌ 로그 파일 클리어 실패: \(error)")
                    #endif
                }
            }
        }
    }

}

// MARK: - 특수 로거

/// 성능 모니터링 로거
class PerformanceLogger {
    static let shared = PerformanceLogger()

    // 로그 파일 경로: appRootPath/logs/performance.log (flog.log와 동일한 기준 경로)
    private let logFileURL: URL = {
        let fileManager = FileManager.default
        let appRootPath = PreferencesManager.resolveAppRootPath()

        let logDir = URL(fileURLWithPath: appRootPath).appendingPathComponent("logs")
        try? fileManager.createDirectory(
            at: logDir, withIntermediateDirectories: true, attributes: nil)

        let logPath = logDir.appendingPathComponent("performance.log")
        #if DEBUG
            print("⚡ [PERF] 성능 로그 파일: \(logPath.path)")
        #endif
        return logPath
    }()

    private let queue = DispatchQueue(
        label: "com.nowage.fSnippet.logger.performance", qos: .utility)

    private lazy var timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    // 성능 모니터링 활성화 상태 (PreferencesManager 초기화 + 외부 주입)
    private var isEnabled: Bool = PreferencesManager.shared.bool(forKey: "performance_monitoring")

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func log(_ message: String, duration: TimeInterval) {
        // 내부 상태 확인 (No dependency on SettingsObservableObject)
        guard isEnabled else { return }

        let durationMs = String(format: "%.2fms", duration * 1000)
        let timestamp = timestampFormatter.string(from: Date())

        queue.async { [weak self] in
            guard let self = self else { return }

            let logMessage = "[\(timestamp)] [duration: \(durationMs)] \(message)\n"

            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
        }
    }
}

// 디버그 추적 로깅 전역 함수 (메인 로거의 debug 레벨로 통합, Issue241)
func logTrace(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.verbose(message())
    }
}

// 전역 로거 인스턴스
let logger = Logger.shared

// 호환성을 위한 전역 함수들 (레이지 평가 지원)
public func logV(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.verbose(message())
    }
}

public func logD(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.debug(message())
    }
}

public func logI(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.info(message())
    }
}

public func logW(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.warning(message())
    }
}

public func logE(_ message: @autoclosure () -> String, file: String = #file) {
    // 에러 로그는 중요하지만 명시적으로 거부된 경우 필터를 존중해야 할까?
    // 보통 Config 'deny'는 "이 파일의 로그를 보고 싶지 않음"을 의미함.
    // 하지만 에러는 중요할 수 있음.
    // 설계 결정: "로그 필터"에 따라 모든 레벨에 필터 적용.
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.error(message())
    }
}

public func logC(_ message: @autoclosure () -> String, file: String = #file) {
    // 치명적 로그도 필터링? 네.
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.critical(message())
    }
}

public func logKeyEvent(_ message: @autoclosure () -> String, file: String = #file) {
    if AppSettingManager.shared.shouldLog(file: file) {
        logger.keyEventInfo(message())
    }
}
public func setLogLevel(_ level: LogLevel) { logger.setLogLevel(level) }
public func clearLogFile() { logger.clearLogFile() }
public func logPerf(_ message: String, duration: TimeInterval) {
    PerformanceLogger.shared.log(message, duration: duration)
}
