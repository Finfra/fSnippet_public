import AppKit
import Foundation

/// Issue51 Phase4 (pairApp Issue39 Full Mirror): 동일 Bundle ID 의 다른 실행 인스턴스가 있을 때
/// **launchd-bootstrap 프로세스가 우선권** 을 갖도록 조정.
///
/// 배경: `open` 으로 기동된 앱이 `onAppStart` 에서 `brew services start` 를 호출하면
/// launchd 가 별도 프로세스를 spawn 함. 과거 구현은 신규 프로세스가 무조건 exit 하여
/// `brew services list` 가 `stopped` 로 남는 문제 발생 → launchd-bootstrap 프로세스가
/// 승자가 되도록 규칙 변경.
///
/// 판정 규칙 (`XPC_SERVICE_NAME` 이 `BrewServiceLabel.all` 중 하나면 launchd-spawned):
///
/// ⚠️ Issue206: 이 라벨은 과거 `homebrew.mxcl.fsnippet-cli` 로 하드코딩돼 있었다.
/// Homebrew 가 네임스페이스를 `sh.brew.*` 로 바꾸자 launchd 기동 프로세스가
/// non-launchd 로 오판되어 아래 2번(패자) 경로를 타고 자살했고, 그 결과
/// `brew services` 는 stopped 로 남고 권한 없는 인스턴스만 생존했다.
/// 라벨 판정은 반드시 `BrewServiceLabel` 을 경유한다.
/// 1. 내가 launchd-spawned 이고 다른 인스턴스가 있으면 → **다른 인스턴스 terminate + 자신 계속 실행**
///    → brew state `started` 로 수렴
/// 2. 내가 launchd-spawned 가 아니고 다른 인스턴스가 있으면 → **자신 exit(0)**
///    → 기존 open 기동분 보존 (brew 측에서 수동 start 한 경우 등)
enum SingleInstanceGuard {

    /// `true` 반환 시 호출부는 즉시 `exit(0)` 수행.
    /// 내가 승자(launchd-spawned) 인 경우 false 반환 + 다른 인스턴스 비동기 종료.
    static func shouldTerminateAsDuplicate() -> Bool {
        // Issue124: XCTest 환경에서는 단일 인스턴스 가드 비활성화 (테스트 호스트 부팅 허용)
        // prj5#Issue99: an isolated test instance must coexist with the user's instance —
        // neither replace it nor exit.
        if !RuntimeIsolation.allowsLiveSideEffects {
            return false
        }
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return false
        }

        let all = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        // Issue53: NSRunningApplication.current.processIdentifier 는 AppKit 미초기화 상태에서
        // -1 반환 → getpid() 로 교체하여 실제 PID 확보.
        let myPID = pid_t(getpid())
        let others = all.filter { $0.processIdentifier != myPID }

        guard !others.isEmpty else {
            return false
        }

        let pids = others.map(\.processIdentifier)
        let iAmLaunchd = isLaunchedByLaunchd()
        let xpcLabel = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] ?? "nil"
        let expectedLabels = BrewServiceLabel.all.joined(separator: "|")

        if iAmLaunchd {
            // 승자 경로: 기존 open-기동 프로세스들을 terminate 하고 자신이 survive.
            logW("[single-instance] launchd-spawned (PID \(myPID), XPC=\(xpcLabel), 기대=\(expectedLabels)) — 기존 인스턴스 terminate (PIDs: \(pids))")
            for other in others {
                if !other.terminate() {
                    logW("[single-instance] ⚠️ terminate 요청 실패 PID \(other.processIdentifier) — forceTerminate 시도")
                    other.forceTerminate()
                }
            }
            // REST 포트 3015 bind 경합 방지 — 기존 프로세스가 실제 종료될 때까지 대기 (최대 3초).
            waitForOthersToExit(bundleID: bundleID, myPID: myPID, timeout: 3.0)
            return false
        } else {
            // 패자 경로: 기존 인스턴스 유지, 자신 exit.
            // Issue206: 기대 라벨을 함께 남긴다. 다음에 Homebrew 가 네임스페이스를 또 바꾸면
            // "XPC 는 서비스 라벨인데 기대 목록에 없다" 가 로그 한 줄로 드러난다.
            logW("[single-instance] non-launchd (PID \(myPID), XPC=\(xpcLabel), 기대=\(expectedLabels)) — 기존 인스턴스 유지 (PIDs: \(pids)), 자신 exit")
            others.first?.activate()
            return true
        }
    }

    private static func isLaunchedByLaunchd() -> Bool {
        // Issue206: 신(`sh.brew.*`)·구(`homebrew.mxcl.*`) 라벨 양쪽 허용.
        return BrewServiceLabel.matches(ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"])
    }

    /// 기존 인스턴스들이 실제 사라질 때까지 폴링. 100ms 간격, 최대 `timeout` 초.
    private static func waitForOthersToExit(bundleID: String, myPID: pid_t, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let remaining = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != myPID }
            if remaining.isEmpty {
                logI("[single-instance] 기존 인스턴스 종료 확인")
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Issue209: 타임아웃을 경고만 하고 넘어가면 구 인스턴스가 그대로 살아남는다.
        //
        // 실측 2026-09-05 재부팅 직후 — PID 1250(구) 이 terminate·forceTerminate 에 모두
        // 응답하지 않아 3초 타임아웃 후 방치됐고, 33분 뒤까지 생존하며 권한 안내 alert 를
        // 두 개(구·신) 띄웠다. 미승인 alert 가 modal 로 run loop 을 잡고 있으면 Cocoa 종료
        // 요청이 처리되지 않는다. 최후 수단으로 SIGKILL 을 보낸다 — terminate·forceTerminate
        // 가 이미 실패한 뒤이므로 정상 종료 기회는 충분히 준 상태다.
        let stubborn = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
        guard !stubborn.isEmpty else {
            logI("[single-instance] 기존 인스턴스 종료 확인 (타임아웃 직전)")
            return
        }

        let stubbornPIDs = stubborn.map(\.processIdentifier)
        logW(
            "[single-instance] ⚠️ 기존 인스턴스 종료 대기 타임아웃 (\(timeout)s) — "
                + "SIGKILL 폴백 (PIDs: \(stubbornPIDs))"
        )
        for app in stubborn {
            if kill(app.processIdentifier, SIGKILL) != 0 {
                logE("[single-instance] ❌ SIGKILL 실패 PID \(app.processIdentifier) — 포트 충돌 가능")
            }
        }

        // SIGKILL 은 즉시 반영되지만 프로세스 테이블 정리에 약간의 여유를 준다 (포트 3015 해제).
        Thread.sleep(forTimeInterval: 0.3)
        let survivors = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
        if survivors.isEmpty {
            logI("[single-instance] ✅ SIGKILL 후 기존 인스턴스 종료 확인")
        } else {
            logE(
                "[single-instance] ❌ SIGKILL 후에도 잔존 (PIDs: "
                    + "\(survivors.map(\.processIdentifier))) — 포트 충돌 가능"
            )
        }
    }
}

// MARK: - prj5#Issue99: runtime isolation (test host / isolated test instance)

/// Single decision point for "must this process stay away from the user's live install?".
///
/// Two cases:
/// * **XCTest host** — the unit-test bundle is injected into a full cliApp launch. It must
///   not read/write the user's data root, bind the REST port, install a second CGEventTap,
///   touch brew services or launch the paidApp.
/// * **Isolated instance** (`fSnippetCli_isolated=1`) — an integration-test instance started
///   next to the user's running cliApp (see `_tool/fsc-isolated.sh`). It keeps the engine and
///   REST (on the port from its own `_config.yml`) but must not kill/replace the user's
///   instance, sync brew services or drive the paidApp.
///
/// Kept in this file for the same reason as `BrewServiceLabel`: the pbxproj lists sources
/// individually, so a new file would mean regenerating the project for a tiny type.
enum RuntimeIsolation {

    static let isolatedEnvKey = "fSnippetCli_isolated"

    static func isHostedByXCTest(environment: [String: String]) -> Bool {
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    static func isIsolatedInstance(environment: [String: String]) -> Bool {
        return environment[isolatedEnvKey] == "1"
    }

    static var isHostedByXCTest: Bool {
        return isHostedByXCTest(environment: ProcessInfo.processInfo.environment)
    }

    static var isIsolatedInstance: Bool {
        return isIsolatedInstance(environment: ProcessInfo.processInfo.environment)
    }

    /// Instance replacement, brew-service sync and paidApp launch/terminate are only allowed
    /// for a normal (user) instance.
    static var allowsLiveSideEffects: Bool {
        return !isHostedByXCTest && !isIsolatedInstance
    }

    /// Key monitoring and the REST server run in a normal or isolated instance, never in the
    /// XCTest host (the tests call the engine types directly).
    static var allowsEngineStartup: Bool {
        return !isHostedByXCTest
    }

    /// Per-process temp data root used by the XCTest host when no ENV override is given.
    /// Never persisted to UserDefaults (the defaults domain is shared with the user's app).
    static let testHostAppRootPath: String = {
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("fSnippetCliTests-\(getpid())/fSnippetData")
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).appendingPathComponent("snippets"),
            withIntermediateDirectories: true)
        return path
    }()
}
