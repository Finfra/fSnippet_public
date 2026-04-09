import Foundation

// MARK: - CLI 라우터

/// CLI 인자를 파싱하고 적절한 커맨드로 분기
struct CLIRouter {

    /// CLI 모드 실행
    /// - Parameter args: CommandLine.arguments에서 첫 번째(실행 파일 경로) 제거한 인자 배열
    /// - Returns: 종료 코드 (0: 성공, 1: 일반 오류, 2: 인자 오류, 3: 서비스 미실행, 4: API 통신 오류)
    static func run(_ args: [String]) -> Int32 {
        let parsed = CommandParser.parse(args)

        // 글로벌 옵션 처리
        let port = UInt16(parsed.options["port"] ?? "") ?? 3015
        let jsonMode = parsed.flags.contains("json")
        let formatter = OutputFormatter(jsonMode: jsonMode)
        let client = CLIAPIClient(port: port)

        // --help 플래그
        if parsed.flags.contains("help") && parsed.command.isEmpty {
            HelpCommand.run()
            return 0
        }

        // --version 플래그
        if parsed.flags.contains("version") && parsed.command.isEmpty {
            return VersionCommand.run(client: client, formatter: formatter)
        }

        // 커맨드 분기
        switch parsed.command {
        case "help":
            HelpCommand.run()
            return 0

        case "version":
            return VersionCommand.run(client: client, formatter: formatter)

        case "status":
            return StatusCommand.run(client: client, formatter: formatter)

        case "snippet":
            return SnippetCommand.run(parsed: parsed, client: client, formatter: formatter)

        case "clipboard":
            return ClipboardCommand.run(parsed: parsed, client: client, formatter: formatter)

        case "folder":
            return FolderCommand.run(parsed: parsed, client: client, formatter: formatter)

        case "stats":
            return StatsCommand.run(parsed: parsed, client: client, formatter: formatter)

        case "trigger":
            return TriggerCommand.run(client: client, formatter: formatter)

        case "config":
            return ConfigCommand.run(client: client, formatter: formatter)

        case "import":
            return ImportCommand.run(parsed: parsed, client: client, formatter: formatter)

        default:
            OutputFormatter.printError("알 수 없는 커맨드: '\(parsed.command)'")
            print("  → fSnippetCli --help 로 사용법을 확인하세요")
            return 2
        }
    }
}
