import Foundation

// MARK: - Folder 커맨드

struct FolderCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let sub = parsed.subcommand else {
            OutputFormatter.printError("서브 커맨드가 필요합니다: list, get")
            return 2
        }

        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        switch sub {
        case "list":
            return runList(client: client, formatter: formatter)
        case "get":
            return runGet(parsed: parsed, client: client, formatter: formatter)
        default:
            OutputFormatter.printError("알 수 없는 서브 커맨드: '\(sub)'")
            return 2
        }
    }

    private static func runList(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let result = client.get(path: "/api/v1/folders")
        guard result.isSuccess else {
            OutputFormatter.printError("폴더 목록 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [[String: Any]] {
            print("폴더 목록 (\(data.count)개)\n")

            var rows: [[String]] = []
            for item in data {
                let name = item["name"] as? String ?? ""
                let prefix = item["prefix"] as? String ?? ""
                let suffix = item["suffix"] as? String ?? ""
                let count = "\(item["snippet_count"] as? Int ?? 0)"
                let special = (item["is_special"] as? Bool == true) ? "●" : ""
                rows.append([name, prefix, suffix, count, special])
            }
            formatter.printTable(headers: ["Name", "Prefix", "Suffix", "Count", "Special"], rows: rows)
        }

        return 0
    }

    private static func runGet(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let name = parsed.positionalArgs.first else {
            OutputFormatter.printError("폴더명이 필요합니다: folder get <name>")
            return 2
        }

        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        var query: [String: String] = [:]
        query["limit"] = parsed.options["limit"] ?? "50"
        query["offset"] = parsed.options["offset"] ?? "0"

        let result = client.get(path: "/api/v1/folders/\(encodedName)", query: query)
        guard result.isSuccess else {
            OutputFormatter.printError("폴더를 찾을 수 없습니다: \(name)")
            return 1
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any],
           let folder = data["folder"] as? [String: Any],
           let snippets = data["snippets"] as? [[String: Any]] {
            formatter.printKeyValue([
                ("Folder", folder["name"] as? String ?? ""),
                ("Prefix", folder["prefix"] as? String ?? ""),
                ("Suffix", folder["suffix"] as? String ?? ""),
                ("Snippets", "\(folder["snippet_count"] as? Int ?? 0)개")
            ])
            print("")

            var rows: [[String]] = []
            for item in snippets {
                let abbr = item["abbreviation"] as? String ?? ""
                let keyword = item["keyword"] as? String ?? ""
                let preview = (item["content_preview"] as? String ?? "").replacingOccurrences(of: "\n", with: "↵").prefix(40)
                rows.append([abbr, keyword, String(preview)])
            }
            formatter.printTable(headers: ["Abbreviation", "Keyword", "Content"], rows: rows)
        }

        return 0
    }
}
