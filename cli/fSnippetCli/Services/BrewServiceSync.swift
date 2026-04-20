import Foundation

/// Issue51 (pairApp Issue39 Full Mirror): `brew services` (launchd) ↔ 메뉴바 앱 상태를
/// 4-quadrant 매트릭스로 동기화.
///
/// 집행 지점:
/// * `onAppStart()` — 앱 시작 시 호출. brew 가 `stopped` 상태면 `brew services start` 로 승격.
///                    이미 `started` 면 skip. (매트릭스: app start 행)
/// * `onAppStop(timeout:)` — 앱 종료 시 동기 호출. brew 가 `started` 상태면 `brew services stop`
///                           으로 강등. 이미 `stopped` 면 skip. 호출부가 이어서
///                           `NSApplication.terminate` 수행. (매트릭스: app stop 행)
///
/// brew 측 트리거(brew start/stop × 앱 실행 중) 에 대한 중복 방지는
/// `SingleInstanceGuard` + Formula `keep_alive: successful_exit: false` 가 담당.
enum BrewServiceSync {

    static let serviceLabel = "homebrew.mxcl.fsnippet-cli"
    static let formulaName = "fsnippet-cli"
    /// 명시적 `false` 일 때만 Phase 3 를 skip. 미설정·`true` 는 활성.
    static let optOutKey = "fsc.autoStartBrewService"

    static let brewCandidates = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    // MARK: - App Start → brew=started (매트릭스: app start 행)

    /// 앱 기동 직후 호출. brew 가 `stopped` 이면 `brew services start` 로 동기화.
    ///
    /// skip 조건:
    /// 1. `UserDefaults` optOutKey == false
    /// 2. launchd 가 이 프로세스를 기동 (`XPC_SERVICE_NAME` 매칭) — 무한 루프 방지
    /// 3. **Issue53**: open 심링크 경로(LaunchServices wrap, `XPC_SERVICE_NAME=application.*`) — 연쇄 종료 방지
    /// 4. `launchctl list` 에 이미 로드됨 — brew state 이미 `started`
    /// 5. brew 바이너리 미존재
    static func onAppStart() {
        if let optOut = UserDefaults.standard.object(forKey: optOutKey) as? Bool, optOut == false {
            logI("[brew-sync] onAppStart skip — \(optOutKey)=false")
            return
        }

        if isLaunchedByLaunchd() {
            logD("[brew-sync] onAppStart skip — launchd 기동 프로세스 (XPC_SERVICE_NAME=\(xpcServiceName() ?? "nil"))")
            return
        }

        // Issue53: open 심링크(/Applications/_nowage_app/fSnippetCli.app) 경로에서는 brew start 호출 금지.
        // LaunchServices 가 XPC_SERVICE_NAME=application.* 로 wrap 하여 기동 → 이 상태에서
        // brew services start 호출 시 launchd 가 별도 프로세스 spawn → SingleInstanceGuard 가
        // 자기(open 기동)를 terminate 하는 연쇄 반응 발생 (결국 앱·brew 모두 stopped).
        // 사용자가 brew 서비스도 함께 원하면 명시적 `brew services start` 사용.
        if isLaunchedViaLaunchServices() {
            logI("[brew-sync] onAppStart skip — open/LaunchServices 경로 (XPC_SERVICE_NAME=\(xpcServiceName() ?? "nil")). brew 시작은 수동.")
            return
        }

        if isServiceLoaded() {
            logD("[brew-sync] onAppStart skip — brew state 이미 started (\(serviceLabel) 로드됨)")
            return
        }

        guard let brewPath = findBrewPath() else {
            logI("[brew-sync] onAppStart skip — brew 미설치")
            return
        }

        // brew state: stopped → started. 백그라운드 비동기.
        DispatchQueue.global(qos: .utility).async {
            runBrewServicesStart(brewPath: brewPath)
        }
    }

    private static func runBrewServicesStart(brewPath: String) {
        logI("[brew-sync] brew services start \(formulaName) — app start × brew=stopped")
        let (rc, output) = runCommandWithStatus(brewPath, args: ["services", "start", formulaName])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if rc == 0 {
            logI("[brew-sync] ✅ brew services start 성공 → brew=started: \(trimmed)")
        } else {
            logW("[brew-sync] ⚠️ brew services start 실패 (rc=\(rc)): \(trimmed)")
        }
    }

    // MARK: - App Stop → brew=stopped (매트릭스: app stop 행)

    /// 메뉴바 "종료" 진입점에서 동기 호출. brew 가 `started` 이면 `brew services stop` 으로 동기화.
    ///
    /// 반환 후 호출부가 `NSApplication.terminate` 를 수행함.
    /// 타임아웃 초과 시 종료 흐름 지연 방지 위해 포기하고 반환.
    static func onAppStop(timeout: TimeInterval = 2.0) {
        guard let brewPath = findBrewPath() else {
            logI("[brew-sync] onAppStop skip — brew 미설치")
            return
        }

        if !isServiceLoaded() {
            logD("[brew-sync] onAppStop skip — brew state 이미 stopped")
            return
        }

        logI("[brew-sync] brew services stop \(formulaName) — app stop × brew=started")

        let semaphore = DispatchSemaphore(value: 0)
        var result: (Int32, String) = (-999, "")
        DispatchQueue.global(qos: .userInitiated).async {
            result = runCommandWithStatus(brewPath, args: ["services", "stop", formulaName])
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            logW("[brew-sync] ⚠️ brew services stop 타임아웃 (\(timeout)s) — fallback terminate 진행")
            return
        }
        let trimmed = result.1.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.0 == 0 {
            logI("[brew-sync] ✅ brew services stop 성공 → brew=stopped: \(trimmed)")
        } else {
            logW("[brew-sync] ⚠️ brew services stop 실패 (rc=\(result.0)): \(trimmed)")
        }
    }

    // MARK: - 상태 판정

    /// brew services(launchctl bootstrap) 로 기동됐는지 판정.
    /// macOS GUI 앱은 `open`/Finder 기동이더라도 부모 PID 가 1(launchd) 이므로
    /// PPID 기반 판정은 상시 true 가 되어 무한 루프 방지 조건으로만 사용 불가.
    /// `XPC_SERVICE_NAME` 이 서비스 label 과 일치하는 경우만 launchd 기동으로 간주.
    static func isLaunchedByLaunchd() -> Bool {
        return xpcServiceName() == serviceLabel
    }

    /// Issue53: open / Finder / LaunchServices 경로로 기동됐는지 판정.
    /// 이 경로는 `XPC_SERVICE_NAME` 이 `application.<BundleID>.<session>.<pid>` 포맷으로 주입됨.
    /// (ex: `application.kr.finfra.fSnippetCli.212453215.212453236`)
    /// launchd-bootstrap 경로(`homebrew.mxcl.*`) 와 명확히 구분됨.
    static func isLaunchedViaLaunchServices() -> Bool {
        guard let xpc = xpcServiceName() else { return false }
        return xpc.hasPrefix("application.")
    }

    /// 진단용: 현재 프로세스의 XPC_SERVICE_NAME 원본 값 반환. 없으면 nil.
    static func xpcServiceName() -> String? {
        return ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"]
    }

    /// brew state == `started` 와 등가. `launchctl list` 출력에 label 이 포함됐는지.
    static func isServiceLoaded() -> Bool {
        let output = runCommand("/bin/launchctl", args: ["list"]) ?? ""
        return output.contains(serviceLabel)
    }

    static func findBrewPath() -> String? {
        for path in brewCandidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    // MARK: - 실행 헬퍼

    static func runCommand(_ executable: String, args: [String]) -> String? {
        let (rc, output) = runCommandWithStatus(executable, args: args)
        return rc == 0 ? output : nil
    }

    static func runCommandWithStatus(_ executable: String, args: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, "\(error)")
        }
    }
}
