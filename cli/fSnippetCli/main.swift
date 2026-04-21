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
    // Issue51 Phase4: 중복 인스턴스 방어는 AppDelegate.applicationDidFinishLaunching 에서 수행.
    // 이전에는 여기서 exit(0)를 호출했으나, AppKit 초기화 전 exit(0)는 LaunchServices 가
    // 비정상 종료로 인식하여 "not open anymore" 오류 다이얼로그를 표시하는 부작용이 있었음.
    // applicationDidFinishLaunching 으로 이동하면 AppKit 초기화 후 terminate(nil) 호출 가능 → 정상 종료.
    fSnippetCliApp.main()
} else {
    // CLI 모드: GUI 초기화 없이 커맨드 실행 후 종료
    let exitCode = CLIRouter.run(args)
    exit(exitCode)
}
