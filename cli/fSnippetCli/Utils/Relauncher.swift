import Foundation
import AppKit

/// 앱 재시작 유틸리티
class Relauncher {
    
    /// 앱을 종료하고 즉시 다시 실행합니다.
    /// Issue729: NSWorkspace.openApplication 기반으로 통일 (LSUIElement 앱 호환성)
    static func relaunchApp() {
        logI("🔁 [Relauncher] 앱 재시작 요청됨")

        let bundleURL = Bundle.main.bundleURL

        // 메인 큐에서 비동기 실행 (로그 기록 시간 확보)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            logI("🔁 [Relauncher] 재시작 실행: \(bundleURL.path)")

            // Issue729: NSWorkspace.openApplication 사용 (LSUIElement 앱에서도 안정적)
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true

            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { app, error in
                if let error = error {
                    logE("🔁 ❌ [Relauncher] NSWorkspace 실행 실패: \(error)")

                    // Fallback: open -n 명령 사용
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = ["-n", bundleURL.path]

                    do {
                        try task.run()
                        logI("🔁 [Relauncher] open -n Fallback 성공, 앱 종료")
                        DispatchQueue.main.async {
                            NSApp.terminate(nil)
                        }
                    } catch {
                        logE("🔁 ❌ [Relauncher] open -n Fallback도 실패: \(error)")
                    }
                } else {
                    logI("🔁 [Relauncher] NSWorkspace 새 인스턴스 실행 성공, 앱 종료")
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
}
