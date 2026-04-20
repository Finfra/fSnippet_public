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
/// 판정 규칙 (`XPC_SERVICE_NAME == "homebrew.mxcl.fsnippet-cli"` 로 launchd-spawned 여부 구분):
/// 1. 내가 launchd-spawned 이고 다른 인스턴스가 있으면 → **다른 인스턴스 terminate + 자신 계속 실행**
///    → brew state `started` 로 수렴
/// 2. 내가 launchd-spawned 가 아니고 다른 인스턴스가 있으면 → **자신 exit(0)**
///    → 기존 open 기동분 보존 (brew 측에서 수동 start 한 경우 등)
enum SingleInstanceGuard {

    private static let launchdServiceLabel = "homebrew.mxcl.fsnippet-cli"

    /// `true` 반환 시 호출부는 즉시 `exit(0)` 수행.
    /// 내가 승자(launchd-spawned) 인 경우 false 반환 + 다른 인스턴스 비동기 종료.
    static func shouldTerminateAsDuplicate() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return false
        }

        let all = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let myPID = NSRunningApplication.current.processIdentifier
        let others = all.filter { $0.processIdentifier != myPID }

        guard !others.isEmpty else {
            return false
        }

        let pids = others.map(\.processIdentifier)
        let iAmLaunchd = isLaunchedByLaunchd()

        if iAmLaunchd {
            // 승자 경로: 기존 open-기동 프로세스들을 terminate 하고 자신이 survive.
            logW("[single-instance] launchd-spawned (PID \(myPID)) — 기존 인스턴스 terminate (PIDs: \(pids))")
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
            logW("[single-instance] non-launchd (PID \(myPID)) — 기존 인스턴스 유지 (PIDs: \(pids)), 자신 exit")
            others.first?.activate()
            return true
        }
    }

    private static func isLaunchedByLaunchd() -> Bool {
        return ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] == launchdServiceLabel
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
