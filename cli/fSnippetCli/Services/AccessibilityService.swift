import Foundation
import AppKit
import ApplicationServices

// MARK: - Protocol

/// Issue150: pairApp(fWarrangeCli) pattern — protocol facade for accessibility checks.
/// Decouples permission probing from UI presentation so tests can stub the system call.
protocol AccessibilityService {
    func isAccessibilityGranted() -> Bool
    func openAccessibilitySettings()
}

// MARK: - Default implementation

final class SystemAccessibilityService: AccessibilityService {

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        // ⚠️ Issue227: 여기서 권한 요청 프롬프트를 띄우지 않는다.
        //
        // Issue222 는 목록 재등록을 노리고 `prompt: true` 를 넣었지만, 실행 중인 프로세스는
        // 접근성 목록에 스스로를 되돌릴 수 없다. 아무것도 해결하지 못하는 창이 하나 더
        // 뜨는 것으로만 끝났다. 목록 등록은 **새 프로세스의 첫 tap 생성 시도**에서 macOS 가
        // 알아서 처리하므로, 이 앱이 직접 요청할 이유가 없다.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Issue207: 권한 승인 감시 (grant watcher)

/// 미승인 상태로 기동한 프로세스가 사용자가 권한을 켠 뒤 **재시작 없이** 살아나게 한다.
///
/// macOS 접근성 권한은 프로세스 시작 시점에 평가되고 실행 중 프로세스에 소급되지 않는다.
/// 그래서 안내대로 시스템 설정 토글을 켠 사용자가 "시키는 대로 했는데 동작하지 않는" 상태에
/// 놓였다. 신규 설치자는 최초 실행 시 반드시 이 경로를 지나므로 전원이 겪는다.
///
/// ⚠️ **Issue150 과의 경계** — Issue150 은 접근성 폴링을 제거했다. 여기서 되살리는 것은 그것이
/// 아니다. 제거된 것은 *권한 박탈(revoke) 감지 폴링·자동 dismiss·반복 alert* 였고, 이 감시자는
/// 정반대 방향의 1회성 승격 감지다. 다음 네 가지를 지켜야 Issue150 회귀가 아니다.
///
/// 1. **미승인으로 기동한 경우에만 시작**한다 — 승인 상태로 뜬 프로세스는 아무것도 하지 않는다
/// 2. **승인을 감지하면 즉시 스스로 멈춘다** — 상시 폴링이 남지 않는다
/// 3. **권한 박탈은 감지하지 않는다** — Issue150 결정 유지 (`KeyEventMonitor.handleTapDisabled` 소관)
/// 4. **alert 를 다시 띄우지 않는다** — 부팅 시 1회 원칙 유지
final class AccessibilityGrantWatcher {

    static let shared = AccessibilityGrantWatcher()

    /// 폴링 간격. 사용자가 시스템 설정에서 토글을 켜는 동작이라 초 단위면 충분하다.
    private static let pollInterval: TimeInterval = 2.0
    /// 상한. 켤 생각이 없는 사용자를 상대로 무한 폴링하지 않는다.
    private static let timeout: TimeInterval = 600.0

    private let queue = DispatchQueue(label: "kr.finfra.fSnippetCli.accessibility-grant-watch")
    private var timer: DispatchSourceTimer?
    private var elapsed: TimeInterval = 0

    private init() {}

    /// 미승인 상태일 때만 감시를 시작한다. 이미 승인됐거나 이미 감시 중이면 아무것도 하지 않는다.
    ///
    /// - Parameter onGranted: 승인 전환을 감지했을 때 실행할 복구 동작.
    ///   **메인 스레드에서 호출된다** — `CGEventTapManager.setupEventTap()` 이
    ///   `CFRunLoopGetCurrent()` 에 소스를 등록하므로, 백그라운드 스레드에서 재생성하면
    ///   돌지 않는 run loop 에 붙어 이벤트가 영영 오지 않는다.
    func startIfNeeded(service: AccessibilityService, onGranted: @escaping () -> Void) {
        guard !service.isAccessibilityGranted() else { return }
        guard timer == nil else {
            logD("♿️ [GrantWatcher] 이미 감시 중 — 중복 시작 무시")
            return
        }

        logI("♿️ [GrantWatcher] 접근성 권한 승인 감시 시작 (\(Int(Self.pollInterval))s 간격, 상한 \(Int(Self.timeout / 60))분)")

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.pollInterval, repeating: Self.pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.elapsed += Self.pollInterval

            if service.isAccessibilityGranted() {
                logI("♿️ [GrantWatcher] ✅ 접근성 권한 승인 감지 (\(Int(self.elapsed))s 경과) — 키 감지 복구 시도")
                self.stop()
                // run loop 소스 등록 때문에 반드시 메인 스레드에서 복구한다.
                DispatchQueue.main.async(execute: onGranted)
                return
            }

            if self.elapsed >= Self.timeout {
                logW("♿️ [GrantWatcher] 승인 감시 상한 도달 (\(Int(self.elapsed))s) — 감시 종료. "
                    + "권한을 켠 뒤에는 앱을 재시작해야 키 감지가 살아난다.")
                self.stop()
            }
        }
        self.timer = timer
        timer.resume()
    }

    /// 감시 종료. 이미 멈춰 있으면 아무것도 하지 않는다.
    func stop() {
        timer?.cancel()
        timer = nil
        elapsed = 0
    }
}
