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

    /// Accessibility 권한 런타임 모니터 타이머 (Issue42 Phase B + Issue117 통합)
    /// 5초 주기로 `AXIsProcessTrusted()`를 재검사하여 양방향 전이를 감지함:
    ///   - 부여 전이(`false → true`): `KeyEventMonitor` 자동 재초기화 (Issue42)
    ///   - 박탈 전이(`true → false`): CGEventTap 정리 + NSAlert + 자체 종료 (Issue117)
    /// 박탈 시 즉시 종료하므로 시스템 슬로다운(`handleTapDisabled` 재시도 루프) 차단.
    private var accessibilityMonitorTimer: Timer?

    /// 직전 폴링 시점의 trusted 상태 — 전이(grant/revoke) 감지에 사용
    private var lastAccessibilityTrusted: Bool = false

    /// Issue149: 표시 중인 accessibility alert — grant 전이 감지 시 abortModal 로 자동 dismiss
    private var pendingAccessibilityAlert: NSAlert?

    /// 중복 인스턴스 여부 — true 이면 applicationWillTerminate 에서 정리 로직 건너뜀
    private var isDuplicateInstance = false

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

    /// 접근성 권한 확인 및 요청
    /// CGEventTap, 키 시뮬레이션 등 핵심 기능에 필수
    ///
    /// Issue42 Phase A (2026-04-19): pairApp(fWarrangeCli) 패턴 이식.
    /// 시스템 "Accessibility Access" 프롬프트와 커스텀 NSAlert가 중첩되는 문제를 해결하기 위해
    /// `AXIsProcessTrustedWithOptions(prompt: true)` → `AXIsProcessTrusted()`로 전환.
    /// 시스템 프롬프트는 표시하지 않고, 커스텀 NSAlert로만 사용자 안내 + 시스템 설정 deep link 제공.
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        lastAccessibilityTrusted = trusted

        if trusted {
            logI("접근성 권한: 승인됨")
        } else {
            // Issue148: revoke 직후 launchd 가 KeepAlive 로 재시작했을 때 boot alert 를 1회 skip.
            // 직전 인스턴스의 handleAccessibilityRevoked() 가 alert 를 이미 노출했으므로
            // respawn 후 동일 anlert 가 또 뜨면 사용자에게 같은 다이얼로그가 두 번 보임.
            let suppressKey = "suppressBootAlertOnce"
            let shouldSuppress = UserDefaults.standard.bool(forKey: suppressKey)
            if shouldSuppress {
                UserDefaults.standard.removeObject(forKey: suppressKey)
                logW("접근성 권한: 미승인 — Issue148 suppressBootAlertOnce 마커로 boot alert skip")
            } else {
                logW("접근성 권한: 미승인")
                showAccessibilityAlert()
            }
        }
        // Issue117: 시작 상태와 무관하게 양방향 모니터 가동 (grant/revoke 모두 감지)
        startAccessibilityMonitoring()
    }

    /// Accessibility 권한 런타임 양방향 모니터 (Issue42 Phase B + Issue117)
    ///
    /// 5초 주기로 `AXIsProcessTrusted()`를 재검사하여 직전 상태 대비 전이를 감지함:
    ///   - 미승인 → 승인: `reinitializeKeyEventMonitor()` (Issue42)
    ///   - 승인 → 미승인: `handleAccessibilityRevoked()` — 알림 + 자체 종료 (Issue117)
    /// 박탈 즉시 CGEventTap을 정리하여 `handleTapDisabled` 재시도 루프로 인한
    /// 시스템 슬로다운을 차단함.
    private func startAccessibilityMonitoring() {
        guard accessibilityMonitorTimer == nil else { return }

        accessibilityMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let nowTrusted = AXIsProcessTrusted()
            let wasTrusted = self.lastAccessibilityTrusted

            if !wasTrusted && nowTrusted {
                // grant 전이
                self.lastAccessibilityTrusted = true
                logI("✅ 접근성 권한 부여 감지 — KeyEventMonitor 재초기화")
                // Issue149: 표시 중인 alert 자동 dismiss (사용자가 OFF→ON 토글 후 alert 가 그대로 남는 문제 회피)
                if self.pendingAccessibilityAlert != nil {
                    DispatchQueue.main.async {
                        NSApplication.shared.abortModal()
                        self.pendingAccessibilityAlert = nil
                        logI("✅ 접근성 alert 자동 dismiss (grant 전이)")
                    }
                }
                self.reinitializeKeyEventMonitor()
            } else if wasTrusted && !nowTrusted {
                // revoke 전이 — Issue117
                self.lastAccessibilityTrusted = false
                logE("🛑 Accessibility 권한 박탈 감지 — 앱 종료 절차 진입")
                timer.invalidate()
                self.accessibilityMonitorTimer = nil
                self.handleAccessibilityRevoked()
            }
        }
        logI("⏱️ 접근성 권한 모니터링 시작 (5초 주기, 양방향 전이 감지)")
    }

    /// Issue42 Phase B: KeyEventMonitor 재초기화
    ///
    /// 권한 부여 감지 시 호출됨. 기존 monitor를 cleanup + 새 인스턴스 생성 + startMonitoring.
    /// CGEventTap 핸들이 권한 미승인으로 실패 상태였다면 새로 생성된 monitor에서
    /// Tap이 정상 등록되어 키 이벤트 감지가 활성화됨.
    private func reinitializeKeyEventMonitor() {
        keyEventMonitor?.stopMonitoring()
        keyEventMonitor?.cleanup()
        keyEventMonitor = KeyEventMonitor(onPotentialAbbreviation: { _ in })
        keyEventMonitor?.startMonitoring()
        logI("✅ KeyEventMonitor 재초기화 완료 — 키 이벤트 감지 활성화")
    }

    /// Issue117: 런타임 권한 박탈 처리 — CGEventTap 정리 + NSAlert + 자체 종료
    ///
    /// 권한 박탈 시 `CGEventTap`이 비활성화되며 `handleTapDisabled` 콜백이 폭주하여
    /// 메인 큐를 점유 → 시스템 전반 슬로다운을 유발함. 박탈 감지 시 즉시 monitor를
    /// 정리하여 재시도 루프를 차단하고, 사용자에게 안내 후 자체 종료함.
    private func handleAccessibilityRevoked() {
        // 1. CGEventTap 완전 정리 — 재시도 루프 차단 (slowdown 방지의 핵심)
        keyEventMonitor?.stopMonitoring()
        keyEventMonitor?.cleanup()
        keyEventMonitor = nil
        logI("🛑 KeyEventMonitor 정리 완료 — CGEventTap 재시도 루프 차단")

        // Issue148: launchd KeepAlive 가 재시작할 때 boot alert 가 또 표시되는 것을 차단.
        // checkAccessibilityPermission() 이 이 마커를 보면 alert 를 1회 skip 하고 마커를 지움.
        UserDefaults.standard.set(true, forKey: "suppressBootAlertOnce")

        // 2. 사용자 안내 NSAlert
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "Accessibility Permission Revoked",
            comment: "Alert title when accessibility permission is revoked at runtime"
        )
        alert.informativeText = NSLocalizedString(
            "Accessibility permission for fSnippetCli has been revoked.\n\nThe app will quit. Re-grant the permission in System Settings > Privacy & Security > Accessibility, then relaunch the app.",
            comment: "Alert body explaining revocation and quit"
        )
        alert.alertStyle = .critical
        alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: "Button to open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Button to quit the app"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        // 3. 자체 종료 — 응답과 무관 (시스템 설정 열기 후에도 종료)
        logI("🛑 Accessibility 권한 박탈 — 자체 종료 호출")
        NSApplication.shared.terminate(nil)
    }

    /// 접근성 권한 미승인 시 사용자에게 알림 표시
    /// Issue149: alert 인스턴스를 ivar 로 보관하여 grant 전이 시 polling 이 abortModal 로 자동 dismiss
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "Alert title when accessibility permission is not granted")
        alert.informativeText = NSLocalizedString(
            "fSnippetCli requires accessibility permission to monitor keyboard input.\n\n시스템 설정 > 개인정보 보호 및 보안 > 접근성에서 fSnippetCli 를 허용해주세요.\n\nbrew 재배포 직후 권한 매칭이 깨졌을 수 있습니다. 이 경우 토글을 OFF → ON 한 번 다시 누르면 됩니다.",
            comment: "Alert body explaining how to grant accessibility permission")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: "Button to open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: "Button to dismiss the alert"))

        pendingAccessibilityAlert = alert
        let response = alert.runModal()
        pendingAccessibilityAlert = nil

        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
