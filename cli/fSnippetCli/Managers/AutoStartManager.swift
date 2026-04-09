import Foundation
import ServiceManagement

class AutoStartManager {
    static let shared = AutoStartManager()

    private init() {}

    func setAutoStart(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp

            do {
                if enabled {
                    if service.status == .enabled {
                        logV("📅 AutoStart 이미 활성화됨")
                        return
                    }
                    try service.register()
                    logV("📅 AutoStart 활성화 성공")
                } else {
                    if service.status == .notFound {
                        logV("📅 AutoStart 이미 비활성화됨")
                        return
                    }
                    try service.unregister()
                    logV("📅 AutoStart 비활성화 성공")
                }
            } catch {
                logE("📅 AutoStart 설정 실패: \(error)")
            }
        } else {
            // macOS 13 미만 지원 (필요 시 구현, 현재는 로그만)
            logW("📅 AutoStart: macOS 13.0 이상이 필요합니다.")
        }
    }

    func isAutoStartEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
