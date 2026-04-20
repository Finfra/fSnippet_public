import AppKit

/// paidApp (fSnippet) 설치 및 실행 상태 감지 (Issue52 Phase2)
enum PaidAppDetector {
  static let bundleIdPrefix = "kr.finfra.fSnippet"

  /// paidApp이 현재 실행 중인지 여부
  static func isRunning() -> Bool {
    NSWorkspace.shared.runningApplications.contains { app in
      guard let bid = app.bundleIdentifier else { return false }
      return bid.hasPrefix(bundleIdPrefix) && !bid.hasSuffix("Cli")
    }
  }

  /// paidApp 설치 경로
  static func installedURL() -> URL? {
    let candidates = [
      "/Applications/fSnippet.app",
      "/Applications/_nowage_app/fSnippet.app",
    ]
    return candidates.compactMap { path in
      FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }.first
  }

  /// paidApp 실행 (설치되어 있으면 open, 없으면 false)
  @discardableResult
  static func launch() -> Bool {
    guard let url = installedURL() else {
      logW("PaidAppDetector: fSnippet 설치 경로를 찾지 못함")
      return false
    }
    NSWorkspace.shared.open(url)
    return true
  }

  /// paidApp 설정창 열기 — Issue827 Phase B
  /// URL Scheme 우선 (fsnippet://command?action=settings&source=cliApp),
  /// 롤백 플래그(fsc.disableUrlScheme) 활성 시 SettingsWindowManager fallback
  static func openSettings() {
    let disableUrlScheme = UserDefaults.standard.bool(forKey: "fsc.disableUrlScheme")
    guard !disableUrlScheme, let schemeURL = URL(string: "fsnippet://command?action=settings&source=cliApp") else {
      // rollback: 기존 REST 기반 경로
      SettingsWindowManager.shared.showSettings()
      return
    }

    if isRunning() {
      // 실행 중 → URL Scheme 직접 전달
      NSWorkspace.shared.open(schemeURL)
    } else {
      // 미실행 → 앱 먼저 기동 후 URL Scheme 전달 (~1초 대기)
      guard launch() else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        NSWorkspace.shared.open(schemeURL)
      }
    }
  }
}
