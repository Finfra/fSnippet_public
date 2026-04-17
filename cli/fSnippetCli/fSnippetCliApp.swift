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
    private func checkAccessibilityPermission() {
        // prompt: true — 권한 미승인 시 macOS 시스템 팝업 표시 + Accessibility 목록 자동 추가 (Issue816)
        // 참고: 개발 빌드 시 바이너리 서명 변경으로 매번 팝업 발생할 수 있으나, Release 배포에서는 정상
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            logI("접근성 권한: 승인됨")
        } else {
            logW("접근성 권한: 미승인")
            showAccessibilityAlert()
        }
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
