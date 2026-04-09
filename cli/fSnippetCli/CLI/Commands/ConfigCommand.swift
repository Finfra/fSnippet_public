import Foundation

// MARK: - Config 커맨드

struct ConfigCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        let result = client.get(path: "/api/v1/settings")
        guard result.isSuccess else {
            OutputFormatter.printError("설정 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            let appRoot = data["app_root_path"] as? String ?? ""
            let configPath = data["config_path"] as? String ?? ""

            formatter.printKeyValue([
                ("App Root", appRoot),
                ("Config Path", configPath)
            ])

            if let config = data["config"] as? [String: Any], !config.isEmpty {
                print("\n설정 항목:")
                let sorted = config.keys.sorted()
                let pairs = sorted.map { key -> (String, String) in
                    let value = config[key]
                    let str: String
                    if let boolVal = value as? Bool { str = boolVal ? "true" : "false" }
                    else if let intVal = value as? Int { str = "\(intVal)" }
                    else { str = "\(value ?? "")" }
                    return ("  \(key)", str)
                }
                formatter.printKeyValue(pairs)
            }
        }

        return 0
    }
}
