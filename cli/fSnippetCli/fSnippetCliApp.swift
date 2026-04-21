import SwiftUI
import Cocoa

// MARK: - App 진입점

// paidApp 실행 상태를 구독하여 cliApp 메뉴바 숨김/표시를 제어하는 ObservableObject
private final class PaidAppIconState: ObservableObject {
    @Published var isPaidAppRunning: Bool

    init() {
        // REST 채널(등록 여부) + NSWorkspace(시작 시 이미 실행 중인 경우) 양쪽 체크
        let hasRESTReg = PaidAppStateStore.shared.status() != nil
        let isWorkspaceRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "kr.finfra.fSnippet").isEmpty
        isPaidAppRunning = hasRESTReg || isWorkspaceRunning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onStateChanged(_:)),
            name: .paidAppStateChanged,
            object: nil
        )
    }

    @objc private func onStateChanged(_ notification: Notification) {
        isPaidAppRunning = notification.userInfo?["isRunning"] as? Bool ?? false
    }
}

// Issue55: paidApp 실행 시 cliApp MenuBarExtra 숨김 — isInserted 바인딩 복원
// paidApp 실행 중에는 paidApp이 자체 MenuBarExtra를 표시하므로 cliApp 아이콘 숨김
struct fSnippetCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var iconState = PaidAppIconState()

    var body: some Scene {
        // paidApp 미실행 시만 cliApp 메뉴바 표시 (isInserted 바인딩)
        MenuBarExtra(isInserted: Binding(
            get: { !iconState.isPaidAppRunning },
            set: { _ in }
        )) {
            MenuBarView()
        } label: {
            // cliApp 단독 실행 상태: 아래 30% 잘린 bolt (paidApp 미연결 표시)
            Image(nsImage: Self.diagonalCutBoltImage())
        }
    }

    /// bolt.fill을 대각선으로 잘라 아래 부분을 투명하게 만든 메뉴바 아이콘
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
            // 아래 30%를 수평으로 잘라냄 (위 70%만 표시)
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

    /// Issue42 Phase B: 접근성 권한 폴링 타이머
    /// 권한 미승인 상태로 기동된 경우, 5초 주기로 `AXIsProcessTrusted()` 재검사하여
    /// 사용자가 시스템 설정에서 권한을 부여하면 `KeyEventMonitor`를 자동 재초기화함.
    private var accessibilityPollingTimer: Timer?

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

        // 1. 설정 로드
        PreferencesManager.shared.loadConfig()

        // 1-1. _setting.yml 기본 파일 보장
        SettingYmlLoader.ensureDefaultFile()

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

        // Issue52 Phase0: 모든 종료 경로(메뉴바·API·SettingsVM·Relauncher 등)의 공통 수렴점.
        // brew 가 started 상태면 여기서 stop 하여 브루 상태 일관성 보장.
        // timeout 3.0s: macOS 종료 허용 시간(5~20s) 내 충분한 여유.
        BrewServiceSync.onAppStop(timeout: 3.0)

        // 리소스 정리
        SnippetFileManager.shared.stopFolderWatching()
        APIServer.shared.stop()
        logI("fSnippetCli 종료")
    }

    // MARK: - 메뉴바 복원 신호 처리

    /// 중복 인스턴스가 직접 실행되었을 때 DistributedNotificationCenter 를 통해 수신
    /// paidApp 종료 후 메뉴바 아이콘이 숨겨진 상태에서 직접 실행 시 복원 트리거
    @objc private func onRestoreMenuBarSignal() {
        logI("메뉴바 복원 신호 수신 — paidApp 미실행 상태로 강제 전환")
        NotificationCenter.default.post(name: .paidAppStateChanged, object: nil, userInfo: ["isRunning": false])
    }

    // MARK: - 유료 앱 실행/종료 감시

    /// fSnippet(유료) 앱 실행/종료를 감시하여 PaidAppStateStore + 메뉴바 표시 상태 갱신
    /// 실행 감지 → paidAppStateChanged(isRunning:true) → isInserted=false(cliApp 메뉴바 숨김)
    /// 종료 감지 → markStaleFromWorkspace → paidAppStateChanged(isRunning:false) → isInserted=true(복원)
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
            // markStaleFromWorkspace 는 pid 일치 시에만 발송하므로,
            // REST register 없이 실행된 paidApp 종료 시 누락될 수 있음 → 직접 발송으로 보장
            NotificationCenter.default.post(name: .paidAppStateChanged, object: nil, userInfo: ["isRunning": false])
            // paidApp 종료 시 cliApp도 함께 종료 (brew service 포함)
            // applicationWillTerminate 에서 BrewServiceSync.onAppStop() 자동 호출됨
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                logI("🛑 paidApp 종료 연동 — cliApp 종료")
                NSApplication.shared.terminate(nil)
            }
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

        if trusted {
            logI("접근성 권한: 승인됨")
        } else {
            logW("접근성 권한: 미승인")
            showAccessibilityAlert()
            // Issue42 Phase B: 권한 부여 감지를 위한 폴링 시작
            startAccessibilityPolling()
        }
    }

    /// Issue42 Phase B: 접근성 권한 부여 감지 폴링
    ///
    /// 권한 미승인 상태로 기동된 경우 5초 주기로 `AXIsProcessTrusted()`를 재검사함.
    /// 권한이 감지되면 타이머를 중단하고 `KeyEventMonitor`를 재초기화하여
    /// 사용자가 앱 재시작 없이 키 감지 기능을 사용할 수 있도록 함.
    /// 최대 10분(120회) 폴링 후 자동 종료하여 불필요한 타이머 유지를 방지함.
    private func startAccessibilityPolling() {
        guard accessibilityPollingTimer == nil else { return }
        let startTime = Date()
        let maxDuration: TimeInterval = 600  // 10분

        accessibilityPollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if AXIsProcessTrusted() {
                timer.invalidate()
                self.accessibilityPollingTimer = nil
                logI("✅ 접근성 권한 부여 감지 — KeyEventMonitor 재초기화")
                self.reinitializeKeyEventMonitor()
            } else if Date().timeIntervalSince(startTime) > maxDuration {
                timer.invalidate()
                self.accessibilityPollingTimer = nil
                logW("⚠️ 접근성 권한 폴링 시간 초과 (10분) — 앱 재시작 필요")
            }
        }
        logI("⏱️ 접근성 권한 폴링 시작 (5초 주기, 최대 10분)")
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

    /// 접근성 권한 미승인 시 사용자에게 알림 표시
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "Alert title when accessibility permission is not granted")
        alert.informativeText = NSLocalizedString("fSnippetCli requires accessibility permission to monitor keyboard input.\n\nPlease enable fSnippetCli in System Settings > Privacy & Security > Accessibility.", comment: "Alert body explaining how to grant accessibility permission")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Open System Settings", comment: "Button to open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: "Button to dismiss the alert"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
