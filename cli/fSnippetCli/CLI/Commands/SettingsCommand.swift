import Foundation

// MARK: - Settings 커맨드

struct SettingsCommand {
    static func run(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard client.isServiceRunning() else {
            OutputFormatter.printError(CLIError.serviceNotRunning.description)
            return CLIError.serviceNotRunning.exitCode
        }

        let subcommand = parsed.subcommand ?? "get"

        switch subcommand {
        case "get":
            return handleGet(parsed: parsed, client: client, formatter: formatter)

        case "set":
            return handleSet(parsed: parsed, client: client, formatter: formatter)

        case "reset":
            return handleReset(parsed: parsed, client: client, formatter: formatter)

        case "snapshot":
            return handleSnapshot(parsed: parsed, client: client, formatter: formatter)

        default:
            OutputFormatter.printError("알 수 없는 settings 서브커맨드: '\(subcommand)'")
            return 2
        }
    }

    // MARK: - settings get [key]

    private static func handleGet(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let key = parsed.positionalArgs.first ?? "general"

        let path: String
        switch key {
        case "general":
            path = "/api/v2/settings/general"
        case "popup":
            path = "/api/v2/settings/popup"
        case "behavior":
            path = "/api/v2/settings/behavior"
        case "history":
            path = "/api/v2/settings/history"
        case "advanced":
            path = "/api/v2/settings/advanced/info"
        case "snapshot":
            path = "/api/v2/settings/snapshot"
        case "shortcuts":
            path = "/api/v2/settings/shortcuts"
        default:
            OutputFormatter.printError("알 수 없는 settings 키: '\(key)'")
            OutputFormatter.printError("사용 가능한 키: general, popup, behavior, history, advanced, snapshot, shortcuts")
            return 2
        }

        let result = client.get(path: path)
        guard result.isSuccess else {
            OutputFormatter.printError("설정 조회 실패 (\(result.statusCode))")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
            return 0
        }

        // 텍스트 출력: 키-값 형태로 표시
        if let dict = result.jsonDict() {
            prettyPrintSettings(dict, formatter: formatter)
            return 0
        }

        formatter.printJSON(result.data)
        return 0
    }

    // MARK: - settings set <key> <value>

    private static func handleSet(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard parsed.positionalArgs.count >= 2 else {
            OutputFormatter.printError("사용법: settings set <section.field> <value>")
            OutputFormatter.printError("예: settings set popup.popupRows 10")
            OutputFormatter.printError("예: settings set behavior.expandOnTrigger true")
            return 2
        }

        let keyPath = parsed.positionalArgs[0]
        let valueStr = parsed.positionalArgs[1]

        // section.field 파싱
        let parts = keyPath.split(separator: ".", maxSplits: 1).map { String($0) }
        guard parts.count == 2 else {
            OutputFormatter.printError("키 형식이 잘못되었습니다: '\(keyPath)'")
            OutputFormatter.printError("올바른 형식: <section>.<field> (예: popup.popupRows)")
            return 2
        }

        let section = parts[0]
        let field = parts[1]

        // API 경로 결정
        let apiPath: String
        switch section {
        case "general":
            apiPath = "/api/v2/settings/general"
        case "popup":
            apiPath = "/api/v2/settings/popup"
        case "behavior":
            apiPath = "/api/v2/settings/behavior"
        case "history":
            apiPath = "/api/v2/settings/history"
        case "advanced":
            apiPath = "/api/v2/settings/advanced"
        default:
            OutputFormatter.printError("알 수 없는 섹션: '\(section)'")
            return 2
        }

        // 값 타입 자동 감지
        let value: Any
        switch valueStr.lowercased() {
        case "true":
            value = true
        case "false":
            value = false
        default:
            if let intVal = Int(valueStr) {
                value = intVal
            } else if let doubleVal = Double(valueStr) {
                value = doubleVal
            } else {
                value = valueStr
            }
        }

        let body = [field: value]
        let result = client.patch(path: apiPath, body: body)

        guard result.isSuccess else {
            OutputFormatter.printError("설정 변경 실패 (\(result.statusCode))")
            if let dict = result.jsonDict(), let error = dict["error"] as? [String: Any] {
                if let message = error["message"] as? String {
                    OutputFormatter.printError("상세: \(message)")
                }
            }
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
        } else {
            print("✓ 설정 변경 완료: \(section).\(field) = \(valueStr)")
        }

        return 0
    }

    // MARK: - settings reset [--confirm]

    private static func handleReset(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let hasConfirm = parsed.flags.contains("confirm")

        if !hasConfirm {
            print("⚠️  경고: 이 작업은 모든 설정을 기본값으로 초기화합니다.")
            print("계속하려면 --confirm 플래그를 사용하세요:")
            print("  fSnippetCli settings reset --confirm")
            return 0
        }

        // confirm 토큰과 함께 API 호출
        let body: [String: Any] = ["confirm": true]
        let result = client.post(path: "/api/v2/settings/actions/reset-settings", body: body)

        guard result.isSuccess else {
            OutputFormatter.printError("설정 초기화 실패 (\(result.statusCode))")
            return 4
        }

        if formatter.jsonMode {
            formatter.printJSON(result.data)
        } else {
            print("✓ 모든 설정이 기본값으로 초기화되었습니다.")
        }

        return 0
    }

    // MARK: - settings snapshot [export|import] [file]

    private static func handleSnapshot(parsed: CommandParser.ParsedCommand, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let action = parsed.positionalArgs.first else {
            OutputFormatter.printError("사용법: settings snapshot [export|import] [file]")
            OutputFormatter.printError("예: settings snapshot export backup.json")
            OutputFormatter.printError("예: settings snapshot import backup.json")
            return 2
        }

        let filePath = parsed.positionalArgs.count > 1 ? parsed.positionalArgs[1] : nil

        switch action {
        case "export":
            return handleSnapshotExport(filePath: filePath, client: client, formatter: formatter)

        case "import":
            return handleSnapshotImport(filePath: filePath, client: client, formatter: formatter)

        default:
            OutputFormatter.printError("알 수 없는 snapshot 동작: '\(action)'")
            OutputFormatter.printError("사용 가능한 동작: export, import")
            return 2
        }
    }

    private static func handleSnapshotExport(filePath: String?, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        let result = client.get(path: "/api/v2/settings/snapshot")
        guard result.isSuccess else {
            OutputFormatter.printError("스냅샷 조회 실패 (\(result.statusCode))")
            return 4
        }

        guard let data = result.data else {
            OutputFormatter.printError("응답 데이터가 없습니다")
            return 4
        }

        if let filePath = filePath {
            // 파일로 저장
            do {
                try data.write(to: URL(fileURLWithPath: filePath))
                print("✓ 스냅샷이 '\(filePath)'에 저장되었습니다")
                return 0
            } catch {
                OutputFormatter.printError("파일 저장 실패: \(error)")
                return 4
            }
        } else {
            // stdout으로 출력
            formatter.printJSON(data)
            return 0
        }
    }

    private static func handleSnapshotImport(filePath: String?, client: CLIAPIClient, formatter: OutputFormatter) -> Int32 {
        guard let filePath = filePath else {
            OutputFormatter.printError("사용법: settings snapshot import <file>")
            return 2
        }

        // 파일에서 읽기
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                OutputFormatter.printError("유효한 JSON이 아닙니다")
                return 2
            }

            let result = client.put(path: "/api/v2/settings/snapshot", body: json)
            guard result.isSuccess else {
                OutputFormatter.printError("스냅샷 복원 실패 (\(result.statusCode))")
                return 4
            }

            if formatter.jsonMode {
                formatter.printJSON(result.data)
            } else {
                print("✓ 스냅샷이 '\(filePath)'에서 복원되었습니다")
            }

            return 0
        } catch {
            OutputFormatter.printError("파일 읽기 실패: \(error)")
            return 4
        }
    }

    // MARK: - 헬퍼

    private static func prettyPrintSettings(_ dict: [String: Any], formatter: OutputFormatter) {
        if let data = dict["data"] as? [String: Any] {
            let sortedKeys = data.keys.sorted()
            var pairs: [(String, String)] = []

            for key in sortedKeys {
                let value = data[key]
                let valueStr: String

                if let boolVal = value as? Bool {
                    valueStr = boolVal ? "true" : "false"
                } else if let intVal = value as? Int {
                    valueStr = "\(intVal)"
                } else if let doubleVal = value as? Double {
                    valueStr = "\(doubleVal)"
                } else if let arrayVal = value as? [Any] {
                    if arrayVal.isEmpty {
                        valueStr = "[]"
                    } else {
                        // 배열은 간단히 표시
                        valueStr = "[\(arrayVal.count) items]"
                    }
                } else if let dictVal = value as? [String: Any] {
                    valueStr = "{\(dictVal.count) keys}"
                } else {
                    valueStr = "\(value ?? "nil")"
                }

                pairs.append(("  \(key)", valueStr))
            }

            formatter.printKeyValue(pairs)
        } else {
            // data 필드가 없으면 직접 출력
            formatter.printJSON(try? JSONSerialization.data(withJSONObject: dict))
        }
    }
}
