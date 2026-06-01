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

  /// paidApp 설정창 열기 — Issue827 Phase B / Issue111
  /// URL Scheme 우선 (fsnippet://command?action=settings&source=cliApp),
  /// 롤백 플래그(fsc.disableUrlScheme) 활성 시 SettingsWindowManager fallback.
  ///
  /// paid_cli_protocol §3.5: REST register `bundlePath`가 있으면 1차 채널로 사용해
  /// LaunchServices의 잘못된 URL Scheme 매핑(옛 Bundle ID/백업 경로 등)을 우회.
  ///
  /// Note (Issue903): For already-running paidApp, use DistributedNotification "fSnippetOpenSettings"
  /// via PaidAppManager.openSettings(). This method is now primarily called for the .stopped case
  /// (paidApp not running) to launch and then open settings via URL scheme.
  static func openSettings() {
    let disableUrlScheme = UserDefaults.standard.bool(forKey: "fsc.disableUrlScheme")
    guard !disableUrlScheme, let schemeURL = URL(string: "fsnippet://command?action=settings&source=cliApp") else {
      // rollback: 기존 REST 기반 경로
      SettingsWindowManager.shared.showSettings()
      return
    }
    route(schemeURL, label: "Settings")
  }

  /// paidApp 새 스니펫 추가 창 열기 — Issue157 (paid_cli_protocol §1.2 new-snippet)
  /// URL Scheme: fsnippet://command?action=new-snippet&keyword=<sanitized>&source=cliApp
  static func openNewSnippet(keyword: String) {
    let sanitized = sanitizeKeyword(keyword)
    var comps = URLComponents(string: "fsnippet://command")!
    comps.queryItems = [
      URLQueryItem(name: "action", value: "new-snippet"),
      URLQueryItem(name: "source", value: "cliApp"),
    ]
    if !sanitized.isEmpty {
      comps.queryItems?.append(URLQueryItem(name: "keyword", value: sanitized))
    }
    guard let schemeURL = comps.url else {
      logW("🆕 [NewSnippet] URL 생성 실패 — keyword=\(keyword)")
      return
    }
    route(schemeURL, label: "NewSnippet")
  }

  /// §1.2 keyword 검증: 화이트리스트 [a-z0-9A-Z\-_.], 64자(ASCII 1byte) 제한
  private static func sanitizeKeyword(_ raw: String) -> String {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
    let filtered = String(raw.unicodeScalars.filter { allowed.contains($0) })
    return String(filtered.prefix(64))
  }

  /// URL Scheme 라우팅 공통 경로 — register된 bundlePath 1차, LaunchServices 2차 안전망.
  private static func route(_ schemeURL: URL, label: String) {
    // 1차 채널 — register된 bundlePath로 URL을 강제 라우팅 (LaunchServices 캐시 우회)
    if let registered = PaidAppStateStore.shared.status(),
       FileManager.default.fileExists(atPath: registered.bundlePath) {
      let bundleURL = URL(fileURLWithPath: registered.bundlePath)
      logI("🪟 [\(label)] register bundlePath 사용: \(registered.bundlePath)")
      let schemeURLCapture = schemeURL
      NSWorkspace.shared.open(
        [schemeURL],
        withApplicationAt: bundleURL,
        configuration: NSWorkspace.OpenConfiguration()
      ) { _, error in
        if let error {
          logW("🪟 [\(label)] 1차 채널 실패: \(error.localizedDescription) — LaunchServices 폴백")
          DispatchQueue.main.async {
            NSWorkspace.shared.open(schemeURLCapture)
          }
        }
      }
      return
    }

    // 2차 안전망 — LaunchServices 기본 라우팅
    logI("🪟 [\(label)] LaunchServices 라우팅 폴백")
    if isRunning() {
      NSWorkspace.shared.open(schemeURL)
    } else {
      guard launch() else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        NSWorkspace.shared.open(schemeURL)
      }
    }
  }
}
