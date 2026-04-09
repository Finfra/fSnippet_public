import Foundation

// MARK: - Status 커맨드

struct StatusCommand {
    static func run(client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        // 먼저 프로세스 존재 여부 확인 (REST 호출 전)
        let isRunning = isProcessRunning()

        if !isRunning {
            if formatter.jsonMode {
                let json = """
                {"success": true, "data": {"status": "stopped"}}
                """
                print(json)
            } else {
                print("fSnippetCli: 중지됨")
                print("  → brew services start fsnippetcli 로 시작해주세요")
            }
            return 0
        }

        // 서비스 실행 중 → API 호출로 상세 정보
        let result = client.get(path: "/api/v1/cli/status")

        guard result.isSuccess else {
            if formatter.jsonMode {
                let json = """
                {"success": true, "data": {"status": "running", "api": "unreachable"}}
                """
                print(json)
            } else {
                print("fSnippetCli: 실행 중 (API 연결 불가)")
            }
            return 0
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            let uptime = data["uptime_seconds"] as? Int ?? 0
            let snippetCount = data["snippet_count"] as? Int ?? 0
            let pid = data["pid"] as? Int ?? 0

            formatter.printKeyValue([
                ("Status", "실행 중"),
                ("PID", "\(pid)"),
                ("Port", "\(client.port)"),
                ("Uptime", formatUptime(uptime)),
                ("Snippets", "\(snippetCount)개")
            ])
        }

        return 0
    }

    // MARK: - 프로세스 확인

    /// pgrep으로 fSnippetCli 프로세스 존재 여부 확인
    private static func isProcessRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "fSnippetCli"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 가동 시간 포매팅
    private static func formatUptime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)초" }
        if seconds < 3600 { return "\(seconds / 60)분 \(seconds % 60)초" }
        let hours = seconds / 3600
        let mins = (seconds % 3600) / 60
        return "\(hours)시간 \(mins)분"
    }
}
