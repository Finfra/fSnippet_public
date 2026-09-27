import Foundation

// MARK: - Version 커맨드

struct VersionCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let result = client.get(path: "/api/v2/cli/version")

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
            formatter.printKeyValue(rows(from: data, officialBanner: OfficialBuild.current))
        } else {
            // 서비스 미실행 시 로컬 정보만 출력
            print("fSnippetCli (서비스 미연결)")
        }

        return 0
    }

    /// Key-value rows of `--version`. The "Distribution" row appears only for Official Builds
    /// (Issue238) — source builds make no distribution claim.
    static func rows(from data: [String: Any], officialBanner: String?) -> [(String, String)] {
        var rows: [(String, String)] = [
            ("App", data["app"] as? String ?? "fSnippetCli"),
            ("Version", data["version"] as? String ?? "unknown"),
            ("Build", data["build"] as? String ?? "unknown"),
            ("Swift", data["swift_version"] as? String ?? "unknown"),
            ("macOS Target", data["macos_target"] as? String ?? "unknown")
        ]
        if let banner = officialBanner {
            rows.append(("Distribution", banner))
        }
        return rows
    }
}
