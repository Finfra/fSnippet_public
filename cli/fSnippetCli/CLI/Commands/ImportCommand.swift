import Foundation

// MARK: - Import 커맨드

struct ImportCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard parsed.subcommand == "alfred" else {
            OutputFormatter.printError("지원되는 임포트: import alfred <path>")
            return 2
        }

        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        // path가 없으면 파일 선택 다이얼로그 (NSOpenPanel)
        var body: [String: Any]? = nil
        if let path = parsed.positionalArgs.first {
            body = ["db_path": path]
        }

        let result = client.post(path: "/api/v1/import/alfred", body: body)

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return result.isSuccess ? 0 : 1
        }

        guard result.isSuccess else {
            if let dict = result.jsonDict(),
               let error = dict["error"] as? [String: Any] {
                OutputFormatter.printError(error["message"] as? String ?? "임포트 실패")
            } else {
                OutputFormatter.printError("Alfred 임포트 실패")
            }
            return 1
        }

        if let dict = result.jsonDict(),
           let data = dict["data"] as? [String: Any] {
            let total = data["total"] as? Int ?? 0
            let collections = data["collections"] as? Int ?? 0
            let dest = data["destination"] as? String ?? ""

            print("Alfred 임포트 완료!")
            formatter.printKeyValue([
                ("총 스니펫", "\(total)개"),
                ("컬렉션", "\(collections)개"),
                ("저장 위치", dest)
            ])
        }

        return 0
    }
}
