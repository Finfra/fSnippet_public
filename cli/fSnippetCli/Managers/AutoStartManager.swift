import Foundation
import ServiceManagement

// MARK: - OBSOLETE (Issue47, 2026-04-19)
// 본 매니저의 SMAppService.mainApp.register()/unregister() 경로는
// Issue45 에서 채택된 `brew services` 표준 배포와 배타적이므로 obsolete 처리됨.
// - 오픈소스 배포 표준: `brew services start/stop/info` (LaunchAgent)
// - SMAppService 와 LaunchAgent 동시 등록은 동일 바이너리 이중 기동 원인
// - API v2 `launchAtLogin` / prefs `start_at_login` 는 backward compat 용으로 존재하나
//   실제 Login Item 등록/해제는 수행하지 않음 (no-op + 경고 로그)
// 참조: ~/_doc/3.Resource/_ICT/_OS/MacOS/homebrew_tap_deploy.md §7-5-C

class AutoStartManager {
    static let shared = AutoStartManager()

    private init() {}

    func setAutoStart(_ enabled: Bool) {
        logW("📅 AutoStart: obsolete 경로 호출됨 (enabled=\(enabled)) — Issue47: brew services 배타 원칙, SMAppService 경로 비활성화. 자동 기동은 `brew services start fsnippet-cli` 를 사용하세요.")
    }

    func isAutoStartEnabled() -> Bool {
        return false
    }
}
