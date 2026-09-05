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

    /// Issue206: 라벨 SSOT 는 `BrewServiceLabel`. 여기서는 신 라벨을 대표값으로 노출만 한다.
    /// **판정에 직접 쓰지 말 것** — 설치된 Homebrew 버전에 따라 구 라벨이 올 수 있으므로
    /// 비교는 반드시 `BrewServiceLabel.matches(_:)` / `BrewServiceLabel.all` 을 경유한다.
    static let serviceLabel = BrewServiceLabel.current
    static let formulaName = BrewServiceLabel.formula
    /// 명시적 `false` 일 때만 Phase 3 를 skip. 미설정·`true` 는 활성.
    static let optOutKey = "fsc.autoStartBrewService"

    /// Issue53 v2: handoff 진행 중 flag. SingleInstanceGuard 에 의한 terminate 시
    /// applicationWillTerminate → onAppStop → brew stop 이 방금 start 한 서비스를
    /// 다시 stop 시키는 race 를 차단.
    private static var handoffInProgress = false

    /// Issue206: handoff start 실패 여부. `true` 면 이 프로세스는 launchd 가 관리하지 않는
    /// 상태로 잔존한 것이며, 메뉴바가 경고를 표시한다.
    private(set) static var handoffFailed = false

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

        if isServiceLoaded() {
            logD("[brew-sync] onAppStart skip — brew state 이미 started (\(serviceLabel) 로드됨)")
            return
        }

        guard let brewPath = findBrewPath() else {
            logI("[brew-sync] onAppStart skip — brew 미설치")
            return
        }

        // Issue53 v2: open/LaunchServices 경로(XPC=application.*)에서는 `brew services start` 후
        // 즉시 self-exit(0) 하여 launchd-bootstrap 프로세스에게 승계.
        // 이유: 이 경로에서 일반 비동기 start 를 수행하면 SingleInstanceGuard 가 open 기동
        // 프로세스를 terminate → applicationWillTerminate Phase0 가 방금 start 한 서비스를 stop
        // → 연쇄적으로 모두 stopped 로 귀결됨.
        // exit(0) 는 applicationWillTerminate 를 우회하므로 Phase0 brew stop 도 실행되지 않음.
        if isLaunchedViaLaunchServices() {
            logI("[brew-sync] onAppStart — open 경로 감지 (XPC=\(xpcServiceName() ?? "nil")). brew start + self-exit handoff.")
            DispatchQueue.global(qos: .utility).async {
                performHandoffStart(brewPath: brewPath)
            }
            return
        }

        // 일반 경로 (Xcode Debug, bundle 직접 실행 등): 기존 비동기 start.
        DispatchQueue.global(qos: .utility).async {
            runBrewServicesStart(brewPath: brewPath)
        }
    }

    /// Issue53 v2: open/LaunchServices 경로 전용 — brew start 동기 호출 후 exit(0).
    /// applicationWillTerminate 를 우회하여 Phase0 brew stop 이 실행되지 않도록 함.
    /// launchd-bootstrap 프로세스(XPC=`BrewServiceLabel.all` 중 하나) 가 survive 하여 메뉴바 아이콘 재등장.
    private static func performHandoffStart(brewPath: String) {
        // race 방어: brew start 호출 전에 flag set → onAppStop 이 trigger 되어도 brew stop 스킵
        handoffInProgress = true
        logI("[brew-sync] brew services start \(formulaName) — handoff (open → launchd-bootstrap)")
        let (rc, output) = runCommandWithStatus(brewPath, args: ["services", "start", formulaName])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if rc != 0 {
            // Issue206: 이 지점이 곧 "좀비 인스턴스" 다. launchd 미관리 상태로 살아남으므로
            // brew services 는 stopped 로 남고, 접근성 권한이 없으면 키 감지가 영구 불능이 된다.
            // 사용자가 인지할 수 있도록 logE 로 승격하고 메뉴바 경고 플래그를 세운다.
            logE("[brew-sync] ❌ handoff start 실패 (rc=\(rc)): \(trimmed) — self-exit 취소, 기존 앱 유지. "
                + "launchd 미관리 상태로 잔존하므로 brew services 는 stopped 로 남는다.")
            // 실패했으므로 handoff 억제 플래그를 되돌린다 — 그대로 두면 onAppStop 의
            // brew stop 이 앱 수명 내내 억제된 채로 남는다.
            handoffInProgress = false
            handoffFailed = true
            return
        }
        logI("[brew-sync] ✅ handoff start 성공: \(trimmed). self-exit(0) — launchd-bootstrap 승계")
        // applicationWillTerminate 우회: Foundation.exit 은 delegate 를 호출하지 않음.
        Foundation.exit(0)
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
        // Issue53 v2: handoff 중 SingleInstanceGuard terminate 경로 진입 시
        // 방금 start 한 brew service 를 다시 stop 시키는 race 차단.
        if handoffInProgress {
            logI("[brew-sync] onAppStop skip — handoff in progress (brew stop 억제)")
            return
        }

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
        // Issue206: 신(`sh.brew.*`)·구(`homebrew.mxcl.*`) 라벨 양쪽 허용.
        return BrewServiceLabel.matches(xpcServiceName())
    }

    /// Issue53: open / Finder / LaunchServices 경로로 기동됐는지 판정.
    /// 이 경로는 `XPC_SERVICE_NAME` 이 `application.<BundleID>.<session>.<pid>` 포맷으로 주입됨.
    /// (ex: `application.kr.finfra.fSnippetCli.212453215.212453236`)
    /// launchd-bootstrap 경로(`sh.brew.*` / 구 `homebrew.mxcl.*`) 와 명확히 구분됨.
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
        // Issue206: 어느 네임스페이스로 로드됐든 "started" 로 판정.
        return BrewServiceLabel.loadedLabel(in: output) != nil
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

// MARK: - Issue206: Homebrew 서비스 라벨 SSOT

/// Homebrew 가 서비스 라벨 네임스페이스를 `homebrew.mxcl.<formula>` 에서
/// `sh.brew.<formula>` 로 변경한 것에 대응하는 **단일 판정 지점**.
///
/// 그 전까지 라벨은 6개소에 하드코딩돼 있었고, Homebrew 가 실제 라벨만 바꾸자
/// `SingleInstanceGuard` 가 launchd 기동 프로세스를 non-launchd 로 오판해
/// 스스로 exit 하는 회귀가 발생했다(Issue206). 판정과 계약이 갈리지 않도록
/// 라벨에 관한 모든 질문은 이 타입으로 모은다.
///
/// 규칙:
/// * **판정은 항상 집합 매칭** — 설치된 Homebrew 버전에 따라 어느 쪽 라벨이든 올 수 있다.
/// * **생성은 신 라벨 고정** — 새로 만드는 LaunchAgent plist 파일명은 `current` 를 쓴다.
///
/// 별도 파일이 아니라 이 파일에 함께 두는 이유: 본 프로젝트의 `project.pbxproj` 는
/// 소스 파일을 개별 나열하므로 파일 추가는 XcodeGen 재생성을 동반한다. 라벨 상수 하나를
/// 위해 프로젝트 파일 전체를 재생성하지 않는다.
enum BrewServiceLabel {

    /// Homebrew Formula 이름 (kebab-case).
    static let formula = "fsnippet-cli"

    /// 신 네임스페이스. 신규 생성 시 쓰는 대표값.
    static let current = "sh.brew.\(formula)"

    /// 구 네임스페이스. 구버전 Homebrew 및 Cellar 내 legacy plist 가 여전히 사용한다.
    static let legacy = "homebrew.mxcl.\(formula)"

    /// 판정용 후보 전체 (신 → 구 순).
    static let all = [current, legacy]

    /// `XPC_SERVICE_NAME` 등 임의 라벨이 이 서비스의 라벨인지 판정.
    static func matches(_ label: String?) -> Bool {
        guard let label else { return false }
        return all.contains(label)
    }

    /// `launchctl list` 출력에서 실제 로드된 라벨을 찾아 반환. 미로드면 `nil`.
    static func loadedLabel(in launchctlOutput: String) -> String? {
        return all.first { launchctlOutput.contains($0) }
    }

    /// `~/Library/LaunchAgents/<label>.plist` 후보 (신 → 구).
    static var launchAgentPaths: [String] {
        return all.map { NSHomeDirectory() + "/Library/LaunchAgents/\($0).plist" }
    }

    /// 신규 등록 시 쓸 설치 경로. 파일명은 신 라벨로 고정한다.
    static var launchAgentDestPath: String {
        return NSHomeDirectory() + "/Library/LaunchAgents/\(current).plist"
    }

    /// 실제 존재하는 LaunchAgent plist 경로. 없으면 `nil`.
    static var installedLaunchAgentPath: String? {
        let fm = FileManager.default
        return launchAgentPaths.first { fm.fileExists(atPath: $0) }
    }

    /// LaunchAgent 등록 여부 (= Launch at Login 켜짐 상태).
    static var isLaunchAgentInstalled: Bool {
        return installedLaunchAgentPath != nil
    }

    /// Homebrew Cellar 가 제공하는 plist 소스 후보 (prefix × 라벨).
    ///
    /// ⚠️ 실측(Homebrew 6.0.21): Cellar 쪽 파일명과 그 안의 `Label` 은 **구 라벨 그대로**이며,
    /// `brew services` 가 `~/Library/LaunchAgents` 로 설치할 때 신 라벨로 재작성한다.
    /// 따라서 이 소스를 그대로 복사하면 파일명과 `Label` 이 어긋나므로,
    /// 복사 측에서 `Label` 을 설치 라벨에 맞춰 재작성해야 한다.
    static var plistSourcePaths: [String] {
        let prefixes = ["/opt/homebrew/opt/\(formula)", "/usr/local/opt/\(formula)"]
        return prefixes.flatMap { prefix in all.map { "\(prefix)/\($0).plist" } }
    }
}
