import Foundation

/// Phase 0-3: 상태 전환 로깅 모듈 (ISO8601 타임스탬프, 스레드 안전)
///
/// cliApp의 PaidAppMonitor가 상태 전환 시 호출할 로깅 인터페이스.
/// 로그 파일: `~/Documents/finfra/fSnippetData/logs/paidapp_state_transitions.log`
/// 카운터 파일: `~/Documents/finfra/fSnippetData/logs/paidapp_state_transitions.counter`
public enum PaidAppStateLogger {

    // MARK: - Test Override (테스트용)
    internal static var testableDefaultsOverride: UserDefaults?

    // MARK: - Private State
    private static let serialQueue = DispatchQueue(label: "com.finfra.fSnippetCli.PaidAppStateLogger.serial")

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Public API

    /// 상태 전환 기록
    /// - Parameters:
    ///   - previous: 직전 상태 (e.g. "cli-only", "paidApp-active", "connecting")
    ///   - next: 직후 상태
    ///   - eventType: 이벤트 타입 (e.g. "transition", "legacy_enabled", "register", "unregister", "didTerminate", "hijack_suspected")
    ///   - extra: 키-값 보조 정보 (옵션)
    /// - Throws: 파일시스템 오류 시
    public static func record(
        previous: String,
        next: String,
        eventType: String,
        extra: [String: String]? = nil
    ) throws {
        try serialQueue.sync {
            let logFileURL = Self.logFileURL

            // 디렉토리 생성
            try ensureLogsDirectory()

            // 로그 라인 생성
            let logLine = Self.formatLogLine(
                previous: previous,
                next: next,
                eventType: eventType,
                extra: extra
            )

            // 파일에 추가 (append)
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // 기존 파일에 append
                if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
                    fileHandle.seekToEndOfFile()
                    if let data = (logLine + "\n").data(using: .utf8) {
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    throw NSError(domain: "PaidAppStateLogger", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "파일 열기 실패: \(logFileURL.path)"])
                }
            } else {
                // 새 파일 생성
                try (logLine + "\n").write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    /// legacyMenuBarEnabled=true 카운터 증가
    /// - Returns: 증가 후 카운트
    /// - Throws: 파일시스템 오류 시
    @discardableResult
    public static func incrementLegacyEnabledCount() throws -> Int {
        return try serialQueue.sync {
            let counterFileURL = Self.counterFileURL

            // 디렉토리 생성
            try ensureLogsDirectory()

            // 현재 카운트 읽기
            var count = 0
            if FileManager.default.fileExists(atPath: counterFileURL.path) {
                if let content = try? String(contentsOf: counterFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                    if let currentCount = Int(content) {
                        count = currentCount
                    }
                }
            }

            // 증가
            count += 1

            // Atomic write: temp file + rename
            let tempFile = counterFileURL.appendingPathExtension("tmp")
            try String(count).write(to: tempFile, atomically: true, encoding: .utf8)

            do {
                try FileManager.default.removeItem(at: counterFileURL)
            } catch {
                // counter 파일이 없을 수 있음 (첫 쓰기)
            }

            try FileManager.default.moveItem(at: tempFile, to: counterFileURL)

            return count
        }
    }

    /// 현재 누적 카운터 (없으면 0)
    public static var legacyEnabledCount: Int {
        let counterFileURL = Self.counterFileURL

        guard FileManager.default.fileExists(atPath: counterFileURL.path) else {
            return 0
        }

        guard let content = try? String(contentsOf: counterFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return 0
        }

        return Int(content) ?? 0
    }

    // MARK: - Private Helpers

    /// 로그 파일 경로
    public static var logFileURL: URL {
        let baseURL = Self.resolveAppRootPath()
        let logsDir = URL(fileURLWithPath: baseURL).appendingPathComponent("logs")
        return logsDir.appendingPathComponent("paidapp_state_transitions.log")
    }

    /// 카운터 파일 경로
    private static var counterFileURL: URL {
        let baseURL = Self.resolveAppRootPath()
        let logsDir = URL(fileURLWithPath: baseURL).appendingPathComponent("logs")
        return logsDir.appendingPathComponent("paidapp_state_transitions.counter")
    }

    /// appRootPath 해결 (UserDefaults 또는 기본값)
    private static func resolveAppRootPath() -> String {
        // Test override 확인
        if let testDefaults = testableDefaultsOverride,
           let testPath = testDefaults.string(forKey: "appRootPath"), !testPath.isEmpty {
            return testPath
        }

        // 실제 UserDefaults 확인
        if let appRootPath = UserDefaults.standard.string(forKey: "appRootPath"), !appRootPath.isEmpty {
            return appRootPath
        }

        // 기본값
        return "/Users/\(NSUserName())/Documents/finfra/fSnippetData"
    }

    /// 로그 디렉토리 생성 (없으면)
    private static func ensureLogsDirectory() throws {
        let logFileURL = Self.logFileURL
        let logsDir = logFileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: logsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// 로그 라인 포맷
    /// 형식: {ISO8601_ms} [{eventType}] {previous} -> {next}{extraSuffix}
    private static func formatLogLine(
        previous: String,
        next: String,
        eventType: String,
        extra: [String: String]?
    ) -> String {
        // ISO8601 타임스탬프 (UTC, 밀리초 정밀도)
        let isoTimestamp = dateFormatter.string(from: Date())

        // extra suffix 생성
        var extraSuffix = ""
        if let extra = extra, !extra.isEmpty {
            let sortedKeys = extra.keys.sorted()
            let pairs = sortedKeys.map { key in "\(key)=\(extra[key] ?? "")" }
            extraSuffix = " extra={\(pairs.joined(separator: ","))}"
        }

        return "\(isoTimestamp) [\(eventType)] \(previous) -> \(next)\(extraSuffix)"
    }
}

// MARK: - @TestablePublic Attribute
/// Swift Testing에서 @testable import 없이도 접근 가능하도록 하는 매크로 흉내
/// (실제로는 접근 제어 코드에서 처리, 여기서는 주석)
