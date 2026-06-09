import Foundation

// PaidAppRemoteLogger — Receives log entries from paidApp via POST /api/v2/log/paidapp
// and writes them to the shared log directory alongside cliApp logs.
//
// Shared path: ~/Documents/finfra/fSnippetData/logs/
//   flog_paidApp.log                     — current session (appended)
//   flog_paidApp_{sessionId}.log         — archive per paidApp session (appended)
public enum PaidAppRemoteLogger {

    private static let serialQueue = DispatchQueue(
        label: "kr.finfra.fSnippetCli.PaidAppRemoteLogger.serial",
        qos: .utility
    )

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Public API

    /// Write a log entry received from paidApp to the shared log path.
    public static func write(level: String, message: String, sessionId: String?, timestamp: String?) {
        serialQueue.async {
            guard let logsURL = resolveLogsDirectory() else { return }

            let line = formatLine(level: level, message: message, timestamp: timestamp)

            // 1. Current log: flog_paidApp.log
            append(line: line, to: logsURL.appendingPathComponent("flog_paidApp.log"))

            // 2. Archive log: flog_paidApp_{sessionId}.log
            if let sid = sessionId, !sid.isEmpty {
                append(line: line, to: logsURL.appendingPathComponent("flog_paidApp_\(sid).log"))
            }
        }
    }

    // MARK: - Private Helpers

    private static func resolveLogsDirectory() -> URL? {
        let base = PreferencesManager.resolveAppRootPath()
        let logsURL = URL(fileURLWithPath: base).appendingPathComponent("logs")
        do {
            try FileManager.default.createDirectory(
                at: logsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return logsURL
        } catch {
            return nil
        }
    }

    private static func formatLine(level: String, message: String, timestamp: String?) -> String {
        let ts = timestamp ?? isoFormatter.string(from: Date())
        return "[\(ts)] [\(level.uppercased())] \(message)\n"
    }

    private static func append(line: String, to url: URL) {
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
