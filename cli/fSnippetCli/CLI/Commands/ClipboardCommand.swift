import Foundation

// MARK: - Clipboard 커맨드

struct ClipboardCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let sub = parsed.subcommand else {
            OutputFormatter.printError("서브 커맨드가 필요합니다: list, get, search")
            return 2
        }

        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        switch sub {
        case "list":
            return runList(parsed: parsed, client: client, formatter: formatter)
        case "get":
            return runGet(parsed: parsed, client: client, formatter: formatter)
        case "search":
            return runSearch(parsed: parsed, client: client, formatter: formatter)
        default:
            OutputFormatter.printError("알 수 없는 서브 커맨드: '\(sub)'")
            return 2
        }
    }

    private static func runList(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        var query: [String: String] = [:]
        query["limit"] = parsed.options["limit"] ?? "20"
        query["offset"] = parsed.options["offset"] ?? "0"

        let result = client.get(path: "/api/v1/clipboard/history", query: query)
        guard result.isSuccess else {
            OutputFormatter.printError("클립보드 히스토리 조회 실패")
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
            print("클립보드 히스토리 (총 \(total)개)\n")

            var rows: [[String]] = []
            for item in data {
                let id = "\(item["id"] as? Int ?? 0)"
                let kind = item["kind"] as? String ?? ""
                let preview = (item["text_preview"] as? String ?? "").replacingOccurrences(of: "\n", with: "↵").prefix(50)
                let app = item["app_bundle"] as? String ?? ""
                rows.append([id, kind, String(preview), app])
            }
            formatter.printTable(headers: ["ID", "Kind", "Preview", "App"], rows: rows)
        }

        return 0
    }

    private static func runGet(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let id = parsed.positionalArgs.first else {
            OutputFormatter.printError("클립보드 항목 ID가 필요합니다: clipboard get <id>")
            return 2
        }

        let result = client.get(path: "/api/v1/clipboard/history/\(id)")
        guard result.isSuccess else {
            OutputFormatter.printError("클립보드 항목을 찾을 수 없습니다: \(id)")
            return 1
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            formatter.printKeyValue([
                ("ID", "\(data["id"] as? Int ?? 0)"),
                ("Kind", data["kind"] as? String ?? ""),
                ("App", data["app_bundle"] as? String ?? ""),
                ("Size", "\(data["size_bytes"] as? Int ?? 0) bytes"),
                ("Pinned", (data["pinned"] as? Bool == true) ? "예" : "아니오"),
                ("Created", data["created_at"] as? String ?? "")
            ])
            print("\n--- Text ---")
            print(data["text"] as? String ?? "")
        }

        return 0
    }

    private static func runSearch(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let query = parsed.positionalArgs.first else {
            OutputFormatter.printError("검색어가 필요합니다: clipboard search <query>")
            return 2
        }

        var params: [String: String] = ["q": query]
        params["limit"] = parsed.options["limit"] ?? "20"
        params["offset"] = parsed.options["offset"] ?? "0"

        let result = client.get(path: "/api/v1/clipboard/search", query: params)
        guard result.isSuccess else {
            OutputFormatter.printError("클립보드 검색 실패")
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
            print("검색 결과: '\(query)' (\(total)건)\n")

            var rows: [[String]] = []
            for item in data {
                let id = "\(item["id"] as? Int ?? 0)"
                let kind = item["kind"] as? String ?? ""
                let preview = (item["text_preview"] as? String ?? "").replacingOccurrences(of: "\n", with: "↵").prefix(50)
                rows.append([id, kind, String(preview)])
            }
            formatter.printTable(headers: ["ID", "Kind", "Preview"], rows: rows)
        }

        return 0
    }
}
