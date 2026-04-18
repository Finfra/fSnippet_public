import Foundation

// MARK: - 진입점 분기
// CLI 인자가 있으면 CLI 모드, 없으면 기존 GUI(MenuBarExtra) 모드

let rawArgs = Array(CommandLine.arguments.dropFirst())

// Xcode/시스템이 전달하는 launch argument 필터링 (-NS*, -Apple* 등)
// 이 인자들은 CLI 커맨드가 아니므로 제외
let args = rawArgs.filter { arg in
    !arg.hasPrefix("-NS") &&
    !arg.hasPrefix("-Apple") &&
    !arg.hasPrefix("-com.apple") &&
    // -NS/-Apple 옵션의 값(YES/NO 등)도 필터링
    !(rawArgs.firstIndex(of: arg).map { idx in
        idx > 0 && (rawArgs[idx - 1].hasPrefix("-NS") ||
                     rawArgs[idx - 1].hasPrefix("-Apple") ||
                     rawArgs[idx - 1].hasPrefix("-com.apple"))
    } ?? false)
}

if args.isEmpty {
    // GUI 모드: 기존 MenuBarExtra 앱 실행
    fSnippetCliApp.main()
} else {
    // CLI 모드: GUI 초기화 없이 커맨드 실행 후 종료
    let exitCode = CLIRouter.run(args)
    exit(exitCode)
}
