import Foundation

// MARK: - Version 커맨드

struct VersionCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let result = client.get(path: "/api/v1/cli/version")

        guard result.error == nil else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            let version = data["version"] as? String ?? "unknown"
            let build = data["build"] as? String ?? "unknown"
            let swift = data["swift_version"] as? String ?? "unknown"
            let target = data["macos_target"] as? String ?? "unknown"

            formatter.printKeyValue([
                ("App", data["app"] as? String ?? "fSnippetCli"),
                ("Version", version),
                ("Build", build),
                ("Swift", swift),
                ("macOS Target", target)
            ])
        } else {
            // 서비스 미실행 시 로컬 정보만 출력
            print("fSnippetCli (서비스 미연결)")
        }

        return 0
    }
}
