import Foundation

// MARK: - Snippet 커맨드

struct SnippetCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let sub = parsed.subcommand else {
            if parsed.flags.contains("help") {
                printHelp()
                return 0
            }
            OutputFormatter.printError("서브 커맨드가 필요합니다: list, search, get, expand")
            return 2
        }

        // 서비스 실행 확인
        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        switch sub {
        case "list":
            return runList(parsed: parsed, client: client, formatter: formatter)
        case "search":
            return runSearch(parsed: parsed, client: client, formatter: formatter)
        case "get":
            return runGet(parsed: parsed, client: client, formatter: formatter)
        case "expand":
            return runExpand(parsed: parsed, client: client, formatter: formatter)
        default:
            OutputFormatter.printError("알 수 없는 서브 커맨드: '\(sub)'")
            return 2
        }
    }

    // MARK: - snippet list

    private static func runList(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        var query: [String: String] = [:]
        query["limit"] = parsed.options["limit"] ?? "20"
        query["offset"] = parsed.options["offset"] ?? "0"
        if let folder = parsed.options["folder"] {
            query["folder"] = folder
        }

        let result = client.get(path: "/api/v1/snippets", query: query)
        guard result.isSuccess else {
            OutputFormatter.printError("스니펫 목록 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        // 텍스트 테이블 출력
        if let dict = result.jsonDict(),
           let data = dict["data"] as? [[String: Any]],
           let meta = dict["meta"] as? [String: Any] {
            let total = meta["total"] as? Int ?? 0
            print("스니펫 목록 (총 \(total)개)\n")

            var rows: [[String]] = []
            for item in data {
                let abbr = item["abbreviation"] as? String ?? ""
                let folder = item["folder"] as? String ?? ""
                let preview = (item["content_preview"] as? String ?? "").replacingOccurrences(of: "\n", with: "↵").prefix(50)
                rows.append([abbr, folder, String(preview)])
            }
            formatter.printTable(headers: ["Abbreviation", "Folder", "Content"], rows: rows)
        }

        return 0
    }

    // MARK: - snippet search

    private static func runSearch(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let query = parsed.positionalArgs.first else {
            OutputFormatter.printError("검색어가 필요합니다: snippet search <query>")
            return 2
        }

        var params: [String: String] = ["q": query]
        params["limit"] = parsed.options["limit"] ?? "20"
        params["offset"] = parsed.options["offset"] ?? "0"

        let result = client.get(path: "/api/v1/snippets/search", query: params)
        guard result.isSuccess else {
            OutputFormatter.printError("스니펫 검색 실패")
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
                let abbr = item["abbreviation"] as? String ?? ""
                let folder = item["folder"] as? String ?? ""
                let preview = (item["content_preview"] as? String ?? "").replacingOccurrences(of: "\n", with: "↵").prefix(50)
                rows.append([abbr, folder, String(preview)])
            }
            formatter.printTable(headers: ["Abbreviation", "Folder", "Content"], rows: rows)
        }

        return 0
    }

    // MARK: - snippet get

    private static func runGet(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let id = parsed.positionalArgs.first else {
            OutputFormatter.printError("스니펫 ID가 필요합니다: snippet get <id>")
            return 2
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let result = client.get(path: "/api/v1/snippets/\(encodedId)")
        guard result.isSuccess else {
            OutputFormatter.printError("스니펫을 찾을 수 없습니다: \(id)")
            return 1
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            formatter.printKeyValue([
                ("ID", data["id"] as? String ?? ""),
                ("Abbreviation", data["abbreviation"] as? String ?? ""),
                ("Folder", data["folder"] as? String ?? ""),
                ("Keyword", data["keyword"] as? String ?? ""),
                ("Description", data["description"] as? String ?? ""),
                ("Modified", data["modified_at"] as? String ?? ""),
                ("Placeholders", (data["has_placeholders"] as? Bool == true) ? "있음" : "없음")
            ])
            print("\n--- Content ---")
            print(data["content"] as? String ?? "")
        }

        return 0
    }

    // MARK: - snippet expand

    private static func runExpand(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let abbrev = parsed.positionalArgs.first else {
            OutputFormatter.printError("abbreviation이 필요합니다: snippet expand <abbrev>")
            return 2
        }

        let body: [String: Any] = ["abbreviation": abbrev]
        let result = client.post(path: "/api/v1/snippets/expand", body: body)
        guard result.isSuccess else {
            OutputFormatter.printError("스니펫 확장 실패: \(abbrev)")
            return 1
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            // expand는 확장된 텍스트만 stdout으로 출력 (파이프 활용 가능)
            print(data["expanded_text"] as? String ?? "")
        }

        return 0
    }

    // MARK: - 도움말

    private static func printHelp() {
        let help = """
        사용법: fSnippetCli snippet <subcommand> [options]

        서브 커맨드:
          list                스니펫 목록
          search <query>      스니펫 검색
          get <id>            스니펫 상세 조회
          expand <abbrev>     abbreviation → 텍스트 확장

        옵션:
          --limit <n>         결과 개수 제한 (기본 20)
          --offset <n>        결과 시작 위치 (기본 0)
          --folder <name>     폴더 필터 (list, search)
          --json              JSON 형식 출력
        """
        print(help)
    }
}
