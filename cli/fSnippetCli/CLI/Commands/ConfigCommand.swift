import Foundation

// MARK: - Config 커맨드

struct ConfigCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        let result = client.get(path: "/api/v2/settings/general")
        guard result.isSuccess else {
            OutputFormatter.printError("설정 조회 실패")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict() {
            let settingsFolder = dict["settingsFolder"] as? String ?? ""
            let snippetFolder = dict["snippetFolder"] as? String ?? ""
            let language = dict["language"] as? String ?? ""
            let appearance = dict["appearance"] as? String ?? ""

            formatter.printKeyValue([
                ("Settings Folder", settingsFolder),
                ("Snippet Folder", snippetFolder),
                ("Language", language),
                ("Appearance", appearance)
            ])

            if let triggerKey = dict["triggerKey"] as? [String: Any],
               let token = triggerKey["token"] as? String {
                formatter.printKeyValue([("Trigger Key", token)])
            }
        }

        return 0
    }
}
