import SwiftUI
import Cocoa
import Darwin

// MARK: - App 진입점

struct fSnippetCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager.shared

    var body: some Scene {
        // Issue845/Issue98: cliApp menu bar is always visible.
        // Icon switches based on paidApp status: started → full bolt, else → diagonal-cut bolt.
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(nsImage: appState.paidAppStatus == .started
                ? Self.fullBoltImage()
                : Self.diagonalCutBoltImage()
            )
        }
    }

    /// Full bolt.fill icon — shown when paidApp is running (paid_cli_protocol.md §7.1)
    private static func fullBoltImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(
            systemSymbolName: "bolt.fill", accessibilityDescription: "fSnippetCli")?
            .withSymbolConfiguration(config)
            ?? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "fSnippetCli")!
        image.isTemplate = true
        return image
    }

    /// Diagonal-cut bolt — shown when paidApp is not installed or stopped (paid_cli_protocol.md §7.1)
    private static func diagonalCutBoltImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        guard let boltImage = NSImage(
            systemSymbolName: "bolt.fill", accessibilityDescription: "fSnippetCli")?
            .withSymbolConfiguration(config)
        else {
            return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "fSnippetCli")!
        }

        let size = boltImage.size
        let result = NSImage(size: size, flipped: false) { rect in
            // Clip lower 30% horizontally — shows only top 70%
            let clipRect = NSRect(x: 0, y: rect.height * 0.3, width: rect.width, height: rect.height * 0.7)
            NSBezierPath(rect: clipRect).setClip()
            boltImage.draw(in: rect)
            return true
        }
        result.isTemplate = true
        return result
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    /// 키 이벤트 모니터 (Core 엔진)
    var keyEventMonitor: KeyEventMonitor?

    /// Issue150: pairApp 패턴 차용 — accessibility 체크용 service.
    /// 폴링·revoke·자동 dismiss 모두 제거. 부팅 시 1회 alert 만.
    private let accessibilityService: AccessibilityService = SystemAccessibilityService()

    /// 중복 인스턴스 여부 — true 이면 applicationWillTerminate 에서 정리 로직 건너뜀
    private var isDuplicateInstance = false

    /// Issue181: POST /api/v2/shutdown reason="paidapp-relaunch" 수신 시 true.
    /// paidApp이 스스로 재시작하는 경로에서는 cliApp이 종료 시 terminatePaidApp()으로
    /// 새로 뜬 paidApp 인스턴스를 사살하면 안 되므로, 이 플래그로 역방향 종료 신호를 건너뜀.
    static var skipPaidAppTerminationOnExit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Issue51 Phase4 (방어 이전: main.swift exit(0) → LaunchServices 오류 발생):
        // AppKit 완전 초기화 후 중복 인스턴스를 감지하여 terminate(nil) 로 graceful 종료.
        // 이렇게 하면 LaunchServices 가 정상 종료로 인식하여 "not open anymore" 다이얼로그를 띄우지 않음.
        if SingleInstanceGuard.shouldTerminateAsDuplicate() {
            isDuplicateInstance = true
            // 기존 인스턴스에 메뉴바 복원 신호 전송 (paidApp 종료 후 아이콘이 없는 상태일 수 있음)
            DistributedNotificationCenter.default().postNotificationName(
                .fSnippetCliRestoreMenuBar,
                object: nil,
                deliverImmediately: true
            )
            NSApplication.shared.terminate(nil)
            return
        }

        // 다른 인스턴스가 직접 실행될 때 보내는 메뉴바 복원 신호 구독
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(onRestoreMenuBarSignal),
            name: .fSnippetCliRestoreMenuBar,
            object: nil
        )

        // 접근성 권한 확인
        checkAccessibilityPermission()

        // 1. 설정 로드 (_config.yml SSOT)
        PreferencesManager.shared.loadConfig()

        // 2. 스니펫 파일 매니저 초기화 — 전체 스니펫 로드 + 폴더 감시 시작
        SnippetFileManager.shared.loadAllSnippets(reason: "fSnippetCli/Launch")
        SnippetFileManager.shared.startFolderWatching()

        // 3. Core 엔진 초기화 및 키 모니터링 시작
        keyEventMonitor = KeyEventMonitor(onPotentialAbbreviation: { _ in })
        keyEventMonitor?.startMonitoring()

        // 4. API 서버 시작 (forceEnabled: api_enabled 설정 무시하고 항상 시작)
        APIServer.shared.start(forceEnabled: true)

        // 5. paid 앱 설치됐지만 미실행 시 자동 실행 (실행되면 NSWorkspace가 메뉴바 숨김 트리거)
        if PaidAppManager.shared.isInstalled(), !PaidAppManager.shared.isRunning() {
            PaidAppManager.shared.launchPaidApp()
        }

        // fSnippet 앱 실행/종료 감시
        setupPaidAppMonitoring()

        // Issue51 Phase3: brew services 자동 동기화 (app start × brew=stopped → start)
        // skip 조건: UserDefaults fsc.autoStartBrewService=false / launchd 기동 / 이미 로드됨 / brew 미존재
        BrewServiceSync.onAppStart()

        logI("fSnippetCli 시작 완료")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Issue912: Re-enable KM if cliApp exits during an active capture session.
        KeyCaptureManager.shared.emergencyRestore()

        // 중복 인스턴스로 판정된 경우 정리 로직 불필요 (초기화 자체를 건너뜀)
        guard !isDuplicateInstance else { return }

        // Issue849 fix — cliApp이 다른 cliApp 인스턴스에 의해 SingleInstanceGuard로 terminate되는
        // "인스턴스 교체" 시나리오에서는 paidApp 종료 신호를 스킵.
        // (이전 버그: launchd-spawned cliApp이 _nowage_app cliApp을 종료시키면, 종료되는 cliApp이
        //  자기가 메뉴바 Quit인 줄 알고 paidApp까지 종료시킴 → paidApp이 시작 직후 죽는 현상)
        let myPID = ProcessInfo.processInfo.processIdentifier
        let otherCliApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "kr.finfra.fSnippetCli" && $0.processIdentifier != myPID
        }
        if !otherCliApps.isEmpty {
            let otherPIDs = otherCliApps.map { $0.processIdentifier }
            logI("다른 cliApp 인스턴스 활동 중 (PIDs: \(otherPIDs)) — paidApp 종료 신호 스킵 (인스턴스 교체)")
        } else if AppDelegate.skipPaidAppTerminationOnExit {
            // Issue181 — paidApp 재시작(reason=paidapp-relaunch)으로 인한 종료:
            // paidApp이 곧(또는 이미) 새 인스턴스로 다시 뜨므로 역방향 종료 신호를 보내면
            // 새 paidApp을 사살하게 됨 → 조용히 종료만 수행.
            logI("paidApp relaunch 경로 — 역방향 종료 신호 스킵 (Issue181)")
        } else {
            // Issue849 — cliApp이 종료될 때 paidApp에 종료 신호 전송 (역방향 신호)
            // cliApp이 메뉴바에서 Quit 되었을 때, paidApp도 함께 종료되어야 함
            terminatePaidApp()
        }

        // Issue849 — KeyEventMonitor 정리 (CGEventTap 해제 + NotificationCenter 옵저버 제거)
        keyEventMonitor?.stopMonitoring()
        keyEventMonitor?.cleanup()

        // Issue52 Phase0: 모든 종료 경로(메뉴바·API·SettingsVM·Relauncher 등)의 공통 수렴점.
        // brew 가 started 상태면 여기서 stop 하여 브루 상태 일관성 보장.
        // timeout 3.0s: macOS 종료 허용 시간(5~20s) 내 충분한 여유.
        BrewServiceSync.onAppStop(timeout: 3.0)

        // 리소스 정리
        SnippetFileManager.shared.stopFolderWatching()
        APIServer.shared.stop()
        logI("fSnippetCli 종료")
        logger.flush()  // async 로그 큐 완료 대기 (종료 전 파일 기록 보장)
    }

    // MARK: - PaidApp 역방향 종료 신호 (Issue849)

    /// cliApp 종료 시 paidApp에 종료 신호를 전송하여 좀비 프로세스 방지
    /// 메뉴바에서 cliApp Quit 시 paidApp도 함께 종료되도록 함
    ///
    /// Issue101: NSWorkspace.runningApplications + bundleIdentifier 정확 일치 방식.
    /// 이전 pgrep 방식은 substring 매칭으로 cliApp(자기 자신)도 매칭하는 버그가 있었음.
    private func terminatePaidApp() {
        let paidBundleID = "kr.finfra.fSnippet"
        let paidApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == paidBundleID
        }
        guard !paidApps.isEmpty else { return }

        for app in paidApps {
            logI("paidApp 종료 신호 전송 (PID: \(app.processIdentifier))")
            app.terminate()  // graceful (SIGTERM equivalent)
        }

        // 최대 1초 대기 (50ms 간격)
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if paidApps.allSatisfy({ $0.isTerminated }) {
                logI("paidApp 정상 종료 확인")
                return
            }
            usleep(50_000)
        }

        // 강제 종료
        for app in paidApps where !app.isTerminated {
            logW("paidApp graceful 실패 — forceTerminate (PID: \(app.processIdentifier))")
            app.forceTerminate()  // SIGKILL equivalent
        }
    }

    // MARK: - 메뉴바 복원 신호 처리

    /// 중복 인스턴스가 직접 실행되었을 때 DistributedNotificationCenter 를 통해 수신
    /// Issue845: 항상 표시 방식이므로 별도 복원 불필요하나, 아이콘 상태 갱신 트리거로 유지
    @objc private func onRestoreMenuBarSignal() {
        logI("메뉴바 복원 신호 수신 — paidApp 상태 재평가")
        NotificationCenter.default.post(name: .paidAppStateChanged, object: nil, userInfo: ["isRunning": false])
    }

    // MARK: - 유료 앱 실행/종료 감시

    /// fSnippet(유료) 앱 실행/종료를 감시하여 PaidAppStateStore + AppStateManager 상태 갱신
    /// 실행 감지 → paidAppStateChanged(isRunning:true) → 아이콘 전체 bolt 전환
    /// 종료 감지 → markStaleFromWorkspace → paidAppStateChanged(isRunning:false) → 아이콘 잘린 bolt 전환
    private func setupPaidAppMonitoring() {
        let workspace = NSWorkspace.shared
        let paidBundleID = "kr.finfra.fSnippet"

        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == paidBundleID else { return }
            logI("fSnippet(유료) 실행 감지")
            // register API 수신 전 즉시 아이콘 전환
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .paidAppStateChanged, object: nil, userInfo: ["isRunning": true])
            }
        }

        // fSnippet 종료 감지 → Store stale 처리 (A-11, 직교 2채널)
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == paidBundleID else { return }
            logI("fSnippet(유료) 종료 감지")
            PaidAppStateStore.shared.markStaleFromWorkspace(pid: app.processIdentifier)
            // markStaleFromWorkspace sends notification only when pid matches.
            // Post directly to guarantee state change even if paidApp never called register.
            NotificationCenter.default.post(name: .paidAppStateChanged, object: nil, userInfo: ["isRunning": false])
            // Issue856: cliApp must NOT terminate when paidApp quits normally (Cmd+Q).
            // cliApp terminates only via "Quit All" menu → POST /api/v2/shutdown.
        }
    }

    // MARK: - 접근성 권한 체크

    /// Issue150: pairApp 패턴 차용 — 부팅 시 1회 alert 만.
    /// 폴링·revoke 핸들러·자동 dismiss·suppressBootAlertOnce 마커 모두 제거.
    /// 권한 박탈 시 system slowdown 위험은 `KeyEventMonitor.handleTapDisabled` 자체 fallback 에 위임.
    /// 권한 부여 후 사용자가 cliApp 을 재시작해야 함 (brew services restart 또는 메뉴바).
    private func checkAccessibilityPermission() {
        if accessibilityService.isAccessibilityGranted() {
            logI("접근성 권한: 승인됨")
        } else {
            logW("접근성 권한: 미승인 — 사용자 안내 alert 표시")
            AccessibilityGuidePresenter.show(service: accessibilityService)
        }
    }
}
