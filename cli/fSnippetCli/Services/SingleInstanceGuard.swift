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
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
        {
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
        logW("[single-instance] ⚠️ 기존 인스턴스 종료 대기 타임아웃 (\(timeout)s) — 포트 충돌 가능")
    }
}
