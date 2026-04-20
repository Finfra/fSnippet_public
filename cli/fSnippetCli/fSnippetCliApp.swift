import SwiftUI
import Cocoa

// MARK: - 앱 상태 (메뉴바 표시 여부)

class AppState: ObservableObject {
    static let shared = AppState()
    /// fSnippet(유료) 설치 시 false → 메뉴바 아이콘 숨김
    @Published var showMenuBar: Bool = true
}

// MARK: - App 진입점

struct fSnippetCliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        // MenuBarExtra: macOS 13+ 메뉴바 아이콘
        // isInserted: fSnippet(유료) 실행 시 메뉴바에서 제거
        // @ObservedObject로 AppState 변경 감지 + 동일 값 가드로 KVO 피드백 루프 차단
        MenuBarExtra(isInserted: Binding(
            get: { self.appState.showMenuBar },
            set: { newValue in
                guard newValue != self.appState.showMenuBar else { return }
                self.appState.showMenuBar = newValue
            }
        )) {
            MenuBarView()
        } label: {
            // 대각선으로 아래 부분을 잘라낸 번개 아이콘
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

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // 5. paid 앱 감지 시 자동 실행 + 메뉴바 숨김
        if PaidAppManager.shared.isRunning() {
            AppState.shared.showMenuBar = false
            logI("fSnippet(유료) 실행 중 — 메뉴바 아이콘 숨김")
        } else if PaidAppManager.shared.isInstalled() {
            if PaidAppManager.shared.launchPaidApp() {
                AppState.shared.showMenuBar = false
                logI("fSnippet(유료) 감지 → 자동 실행 — 메뉴바 아이콘 숨김")
            }
        }

        // fSnippet 앱 실행/종료 감시
        setupPaidAppMonitoring()

        // Issue51 Phase3: brew services 자동 동기화 (app start × brew=stopped → start)
        // skip 조건: UserDefaults fsc.autoStartBrewService=false / launchd 기동 / 이미 로드됨 / brew 미존재
        BrewServiceSync.onAppStart()

        logI("fSnippetCli 시작 완료")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 리소스 정리
        SnippetFileManager.shared.stopFolderWatching()
        APIServer.shared.stop()
        logI("fSnippetCli 종료")
    }

    // MARK: - 유료 앱 실행/종료 감시

    /// fSnippet(유료) 앱의 실행/종료를 감시하여 메뉴바 표시 상태를 동적으로 전환
    private func setupPaidAppMonitoring() {
        let workspace = NSWorkspace.shared
        let paidBundleID = "kr.finfra.fSnippet"

        // fSnippet 실행 감지 → 메뉴바 숨김
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == paidBundleID else { return }
            AppState.shared.showMenuBar = false
            logI("fSnippet(유료) 실행 감지 — 메뉴바 아이콘 숨김")
        }

        // fSnippet 종료 감지 → 메뉴바 복원
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == paidBundleID else { return }
            AppState.shared.showMenuBar = true
            logI("fSnippet(유료) 종료 감지 — 메뉴바 아이콘 복원")
        }

        // 현재 fSnippet이 실행 중인지 확인
        let isRunning = workspace.runningApplications.contains { $0.bundleIdentifier == paidBundleID }
        if isRunning {
            AppState.shared.showMenuBar = false
            logI("fSnippet(유료) 실행 중 — 메뉴바 아이콘 숨김")
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
        alert.messageText = "접근성 권한 필요"
        alert.informativeText = "fSnippetCli가 키보드 입력을 모니터링하려면 접근성 권한이 필요합니다.\n\n시스템 설정 > 개인정보 및 보안 > 접근성에서 fSnippetCli를 활성화해 주세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
