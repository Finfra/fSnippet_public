import Foundation

// MARK: - 진입점 분기
// CLI 인자가 있으면 CLI 모드, 없으면 기존 GUI(MenuBarExtra) 모드

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty {
    // GUI 모드: 기존 MenuBarExtra 앱 실행
    fSnippetCliApp.main()
} else {
    // CLI 모드: GUI 초기화 없이 커맨드 실행 후 종료
    let exitCode = CLIRouter.run(args)
    exit(exitCode)
}
