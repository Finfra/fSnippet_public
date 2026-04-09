import Foundation

// MARK: - Stats 커맨드

struct StatsCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let sub = parsed.subcommand else {
            OutputFormatter.printError("서브 커맨드가 필요합니다: top, history")
            return 2
        }

        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        switch sub {
        case "top":
            return runTop(parsed: parsed, client: client, formatter: formatter)
        case "history":
            return runHistory(parsed: parsed, client: client, formatter: formatter)
        default:
            OutputFormatter.printError("알 수 없는 서브 커맨드: '\(sub)'")
            return 2
        }
    }

    private static func runTop(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        var query: [String: String] = [:]
        query["limit"] = parsed.options["limit"] ?? "10"

        let result = client.get(path: "/api/v1/stats/top", query: query)
        guard result.isSuccess else {
            OutputFormatter.printError("통계 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [[String: Any]] {
            print("사용 빈도 Top \(data.count)\n")

            var rows: [[String]] = []
            for (i, item) in data.enumerated() {
                let rank = "\(i + 1)"
                let abbr = item["abbreviation"] as? String ?? ""
                let folder = item["folder"] as? String ?? ""
                let count = "\(item["usage_count"] as? Int ?? 0)"
                let lastUsed = item["last_used"] as? String ?? "-"
                rows.append([rank, abbr, folder, count, lastUsed])
            }
            formatter.printTable(headers: ["#", "Abbreviation", "Folder", "Count", "Last Used"], rows: rows)
        }

        return 0
    }

    private static func runHistory(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        var query: [String: String] = [:]
        query["limit"] = parsed.options["limit"] ?? "20"
        query["offset"] = parsed.options["offset"] ?? "0"

        let result = client.get(path: "/api/v1/stats/history", query: query)
        guard result.isSuccess else {
            OutputFormatter.printError("사용 이력 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [[String: Any]],
           let meta = dict["meta"] as? [String: Any] {
            let total = meta["total"] as? Int ?? 0
            print("사용 이력 (총 \(total)건)\n")

            var rows: [[String]] = []
            for item in data {
                let abbr = item["abbreviation"] as? String ?? ""
                let path = item["snippet_path"] as? String ?? ""
                let usedAt = item["used_at"] as? String ?? ""
                let trigger = item["trigger_by"] as? String ?? ""
                rows.append([abbr, path, usedAt, trigger])
            }
            formatter.printTable(headers: ["Abbreviation", "Path", "Used At", "Trigger"], rows: rows)
        }

        return 0
    }
}
