import Foundation

// MARK: - 커맨드 파서

/// CLI 인자를 파싱하여 구조화된 커맨드로 변환
struct CommandParser {

    /// 파싱된 커맨드 결과
    struct ParsedCommand {
        let command: String          // 메인 커맨드 (ex: "snippet", "status")
        let subcommand: String?      // 서브 커맨드 (ex: "list", "search")
        let positionalArgs: [String] // 위치 인자 (ex: 검색 쿼리)
        let options: [String: String] // 옵션 (ex: --limit → "20")
        let flags: Set<String>       // 플래그 (ex: --json, --help)
    }

    /// 인자 배열을 파싱
    static func parse(_ args: [String]) -> ParsedCommand {
        var command = ""
        var subcommand: String?
        var positionalArgs: [String] = []
        var options: [String: String] = [:]
        var flags: Set<String> = []

        var i = 0
        // 글로벌 플래그/옵션 먼저 수집
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--") || arg.hasPrefix("-") {
                let (opt, val, consumed) = parseOption(args: args, index: i)
                if let val = val {
                    options[opt] = val
                } else {
                    flags.insert(opt)
                }
                i += consumed
            } else {
                break
            }
        }

        // 메인 커맨드
        if i < args.count {
            command = args[i]
            i += 1
        }

        // 서브 커맨드 또는 위치 인자
        if i < args.count && !args[i].hasPrefix("-") {
            // snippet list, snippet search, settings get/set/reset/snapshot 등
            let next = args[i]
            if ["list", "search", "get", "expand", "top", "history", "alfred", "set", "reset", "snapshot"].contains(next) {
                subcommand = next
                i += 1
            }
        }

        // 나머지 인자
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--") || arg.hasPrefix("-") {
                let (opt, val, consumed) = parseOption(args: args, index: i)
                if let val = val {
                    options[opt] = val
                } else {
                    flags.insert(opt)
                }
                i += consumed
            } else {
                positionalArgs.append(arg)
                i += 1
            }
        }

        return ParsedCommand(
            command: command,
            subcommand: subcommand,
            positionalArgs: positionalArgs,
            options: options,
            flags: flags
        )
    }

    /// 옵션 파싱: --key value 또는 --flag 형태 처리
    /// 반환: (옵션명, 값(nil이면 플래그), 소비한 인자 수)
    private static func parseOption(args: [String], index: Int) -> (String, String?, Int) {
        let arg = args[index]
        let key: String

        if arg.hasPrefix("--") {
            key = String(arg.dropFirst(2))
        } else {
            // 단축 옵션: -h, -v, -p
            key = expandShortOption(String(arg.dropFirst()))
        }

        // 값을 받는 옵션 목록
        let valueOptions: Set<String> = ["port", "limit", "offset"]
        if valueOptions.contains(key) && index + 1 < args.count {
            return (key, args[index + 1], 2)
        }

        return (key, nil, 1)
    }

    /// 단축 옵션을 풀네임으로 확장
    private static func expandShortOption(_ short: String) -> String {
        switch short {
        case "h": return "help"
        case "v": return "version"
        case "p": return "port"
        default: return short
        }
    }
}
