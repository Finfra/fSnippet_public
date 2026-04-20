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
    // Issue51 Phase4: 동일 Bundle ID 중복 인스턴스 차단.
    // LaunchServices 가 심링크/경로 차이로 별개 인스턴스를 허용하는 경우
    // (`open _nowage_app/...` + `brew services start` 조합) 를 런타임에서 방어.
    // launchd-bootstrap 프로세스가 우선권을 갖도록 기존 인스턴스를 terminate 함.
    if SingleInstanceGuard.shouldTerminateAsDuplicate() {
        exit(0)
    }
    fSnippetCliApp.main()
} else {
    // CLI 모드: GUI 초기화 없이 커맨드 실행 후 종료
    let exitCode = CLIRouter.run(args)
    exit(exitCode)
}
