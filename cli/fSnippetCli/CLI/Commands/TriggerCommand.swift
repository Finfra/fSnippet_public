import Foundation

// MARK: - Trigger 커맨드

struct TriggerCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        let result = client.get(path: "/api/v1/triggers")
        guard result.isSuccess else {
            OutputFormatter.printError("트리거 정보 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            if let defaultTrigger = data["default_trigger"] as? [String: Any] {
                print("기본 트리거:")
                formatter.printKeyValue([
                    ("Symbol", defaultTrigger["symbol"] as? String ?? ""),
                    ("KeyCode", "\(defaultTrigger["key_code"] as? Int ?? 0)"),
                    ("Description", defaultTrigger["description"] as? String ?? "")
                ])
            }

            if let active = data["active"] as? [[String: Any]], !active.isEmpty {
                print("\n활성 트리거 키:")
                var rows: [[String]] = []
                for item in active {
                    let symbol = item["symbol"] as? String ?? ""
                    let keyCode = "\(item["key_code"] as? Int ?? 0)"
                    let desc = item["description"] as? String ?? ""
                    rows.append([symbol, keyCode, desc])
                }
                formatter.printTable(headers: ["Symbol", "KeyCode", "Description"], rows: rows)
            }
        }

        return 0
    }
}
