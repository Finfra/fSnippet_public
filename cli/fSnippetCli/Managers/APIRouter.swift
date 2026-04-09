import Foundation
import AppKit

// MARK: - API 라우터

/// REST API 라우터 - URL 매핑 및 핸들러 디스패치
class APIRouter {
  static let shared = APIRouter()
  private init() {}

  private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
  }()

  private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  /// 요청 라우팅
  func route(request: APIServer.HTTPRequest, server: APIServer) -> APIServer.HTTPResponse {
    let path = request.path
    let method = request.method.uppercased()
    let decodedPath = path.removingPercentEncoding ?? path

    logD("🌐 API 요청: \(method) \(decodedPath)")

    switch (method, decodedPath) {
    case ("GET", "/"):
      return handleHealthCheck(server: server)

    case ("GET", "/api/v1/snippets"):
      return handleSnippetList(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/snippets/search"):
      return handleSnippetSearch(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/snippets/by-abbreviation/"):
      let abbrev = String(decodedPath.dropFirst("/api/v1/snippets/by-abbreviation/".count))
      return handleGetByAbbreviation(abbrev: abbrev.removingPercentEncoding ?? abbrev)

    case ("POST", "/api/v1/snippets/expand"):
      return handleExpandSnippet(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/snippets/"):
      let id = String(decodedPath.dropFirst("/api/v1/snippets/".count))
      return handleGetSnippetDetail(id: id.removingPercentEncoding ?? id)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/clipboard/search"):
      return handleClipboardSearch(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/clipboard/history/"):
      let idStr = String(decodedPath.dropFirst("/api/v1/clipboard/history/".count))
      return handleGetClipboardDetail(idStr: idStr)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/clipboard/history"):
      return handleGetClipboardHistory(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/folders/"):
      let name = String(decodedPath.dropFirst("/api/v1/folders/".count))
      return handleGetFolderDetail(name: name.removingPercentEncoding ?? name, request: request)

    case ("GET", "/api/v1/folders"):
      return handleGetFolders()

    case ("GET", "/api/v1/stats/top"):
      return handleGetTopStats(request: request)

    case ("GET", _) where decodedPath.hasPrefix("/api/v1/stats/history"):
      return handleGetStatsHistory(request: request)

    case ("GET", "/api/v1/triggers"):
      return handleGetTriggers()

    // Settings 엔드포인트
    case ("GET", "/api/v1/settings"):
      return handleGetSettings()

    // fSnippetCli 전용 엔드포인트
    case ("GET", "/api/v1/cli/status"):
      return handleCliStatus(server: server)
    case ("GET", "/api/v1/cli/version"):
      return handleCliVersion()
    case ("POST", "/api/v1/cli/quit"):
      return handleCliQuit(request: request)

    // Reload 엔드포인트
    case ("POST", "/api/v1/reload"):
      return handleReload()

    // Alfred Import 엔드포인트
    case ("POST", "/api/v1/import/alfred"):
      return handleAlfredImport(request: request)

    // CRUD 엔드포인트 — 폴더 생성/삭제
    case ("POST", "/api/v1/folders"):
      return handleCreateFolder(request: request)

    case ("DELETE", _) where decodedPath.hasPrefix("/api/v1/folders/"):
      let name = String(decodedPath.dropFirst("/api/v1/folders/".count))
      return handleDeleteFolder(name: name.removingPercentEncoding ?? name)

    // CRUD 엔드포인트 — 스니펫 생성/삭제
    case ("POST", "/api/v1/snippets"):
      return handleCreateSnippet(request: request)

    case ("DELETE", _) where decodedPath.hasPrefix("/api/v1/snippets/"):
      let id = String(decodedPath.dropFirst("/api/v1/snippets/".count))
      return handleDeleteSnippet(id: id.removingPercentEncoding ?? id)

    default:
      return notFound()
    }
  }

  // MARK: - 헬퍼

  private func jsonResponse<T: Encodable>(_ value: T, statusCode: Int = 200) -> APIServer.HTTPResponse {
    do {
      let data = try encoder.encode(value)
      // Data→String→Data 왕복 변환 없이 원본 Data를 직접 전달하여
      // 제어문자(\t, \n 등) 이스케이프가 손실되지 않도록 함 (jq 호환성)
      return APIServer.HTTPResponse(statusCode: statusCode, bodyData: data)
    } catch {
      logE("🌐 ❌ JSON 인코딩 실패: \(error)")
      return errorResponse(code: "INTERNAL_ERROR", message: "JSON encoding failed", statusCode: 500)
    }
  }

  private func errorResponse(code: String, message: String, statusCode: Int) -> APIServer.HTTPResponse {
    let err = APIErrorResponse(success: false, error: APIErrorDetail(code: code, message: message))
    return jsonResponse(err, statusCode: statusCode)
  }

  private func notFound() -> APIServer.HTTPResponse {
    return errorResponse(code: "NOT_FOUND", message: "Endpoint not found", statusCode: 404)
  }

  // MARK: - Health Check

  private func handleHealthCheck(server: APIServer) -> APIServer.HTTPResponse {
    let snippetCount = SnippetIndexManager.shared.entries.count
    let (clipItems, _) = ClipboardDB.shared.search(query: "", limit: 1, offset: 0)
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    let response = HealthResponse(
      status: "ok",
      app: "fSnippet",
      version: version,
      port: Int(server.currentPort),
      uptimeSeconds: server.uptimeSeconds,
      snippetCount: snippetCount,
      clipboardCount: clipItems.count
    )
    return jsonResponse(response)
  }

  // MARK: - Snippet List

  private func handleSnippetList(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let limit = min(Int(request.query["limit"] ?? "50") ?? 50, 200)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)
    let folderFilter = request.query["folder"]

    let startTime = CFAbsoluteTimeGetCurrent()

    var allEntries = SnippetIndexManager.shared.entries

    if let folder = folderFilter {
      allEntries = allEntries.filter { $0.folderName.lowercased() == folder.lowercased() }
    }

    let total = allEntries.count
    let paged = Array(allEntries.dropFirst(offset).prefix(limit))
    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let data = paged.map { entry in
      APISnippetSummary(
        id: entry.id,
        abbreviation: entry.abbreviation,
        folder: entry.folderName,
        keyword: extractKeyword(from: entry.fileName),
        description: entry.snippetDescription,
        contentPreview: String(entry.content.prefix(100)),
        tags: entry.tags,
        relevanceScore: nil,
        usageCount: nil,
        lastUsed: nil
      )
    }

    return jsonResponse(APISnippetSearchResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: total, durationMs: duration)
    ))
  }

  // MARK: - Snippet Search

  private func handleSnippetSearch(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let q = request.query["q"], !q.isEmpty else {
      return errorResponse(code: "MISSING_QUERY", message: "Search query 'q' is required", statusCode: 400)
    }

    let limit = min(Int(request.query["limit"] ?? "20") ?? 20, 100)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)
    let folderFilter = request.query["folder"]

    let startTime = CFAbsoluteTimeGetCurrent()

    var results = SnippetIndexManager.shared.search(term: q, scope: .content, maxResults: limit + offset)

    if let folder = folderFilter {
      results = results.filter { $0.folderName.lowercased() == folder.lowercased() }
    }

    let total = results.count
    let paged = Array(results.dropFirst(offset).prefix(limit))
    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let data = paged.map { entry in
      APISnippetSummary(
        id: entry.id,
        abbreviation: entry.abbreviation,
        folder: entry.folderName,
        keyword: extractKeyword(from: entry.fileName),
        description: entry.snippetDescription,
        contentPreview: String(entry.content.prefix(100)),
        tags: entry.tags,
        relevanceScore: entry.relevanceScore(for: q),
        usageCount: nil,
        lastUsed: nil
      )
    }

    return jsonResponse(APISnippetSearchResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: total, durationMs: duration)
    ))
  }

  // MARK: - Get By Abbreviation

  private func handleGetByAbbreviation(abbrev: String) -> APIServer.HTTPResponse {
    let entries = SnippetIndexManager.shared.entries
    guard let entry = entries.first(where: { $0.abbreviation == abbrev }) else {
      return errorResponse(code: "NOT_FOUND", message: "Snippet not found for abbreviation: \(abbrev)", statusCode: 404)
    }
    return snippetDetailResponse(entry)
  }

  // MARK: - Get Snippet Detail

  private func handleGetSnippetDetail(id: String) -> APIServer.HTTPResponse {
    let entries = SnippetIndexManager.shared.entries
    guard let entry = entries.first(where: { $0.id == id }) else {
      return errorResponse(code: "NOT_FOUND", message: "Snippet not found: \(id)", statusCode: 404)
    }
    return snippetDetailResponse(entry)
  }

  private func snippetDetailResponse(_ entry: SnippetEntry) -> APIServer.HTTPResponse {
    let placeholderPattern = #"\{\{([^}:]+)(?::([^}]*))?\}\}"#
    let regex = try? NSRegularExpression(pattern: placeholderPattern)
    let range = NSRange(entry.content.startIndex..., in: entry.content)
    let matches = regex?.matches(in: entry.content, range: range) ?? []
    var placeholders: [String] = []
    for match in matches {
      if let nameRange = Range(match.range(at: 1), in: entry.content) {
        let name = String(entry.content[nameRange]).trimmingCharacters(in: .whitespaces)
        if !placeholders.contains(name) {
          placeholders.append(name)
        }
      }
    }

    let detail = APISnippetDetail(
      id: entry.id,
      abbreviation: entry.abbreviation,
      folder: entry.folderName,
      keyword: extractKeyword(from: entry.fileName),
      description: entry.snippetDescription,
      content: entry.content,
      tags: entry.tags,
      fileSize: entry.fileSize,
      modifiedAt: isoFormatter.string(from: entry.modificationDate),
      hasPlaceholders: !placeholders.isEmpty,
      placeholders: placeholders
    )
    return jsonResponse(APISnippetDetailResponse(success: true, data: detail))
  }

  // MARK: - Expand Snippet

  private func handleExpandSnippet(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let bodyData = request.body,
          let expandReq = try? JSONDecoder().decode(APIExpandRequest.self, from: bodyData) else {
      return errorResponse(code: "INVALID_REQUEST", message: "Invalid JSON body", statusCode: 400)
    }

    let entries = SnippetIndexManager.shared.entries
    guard let entry = entries.first(where: { $0.abbreviation == expandReq.abbreviation }) else {
      return errorResponse(code: "NOT_FOUND", message: "No snippet matches: \(expandReq.abbreviation)", statusCode: 404)
    }

    var expandedText = entry.content
    var resolvedPlaceholders: [String] = []

    if let values = expandReq.placeholderValues {
      let pattern = #"\{\{([^}:]+)(?::([^}]*))?\}\}"#
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsContent = expandedText as NSString
        let matches = regex.matches(in: expandedText, range: NSRange(location: 0, length: nsContent.length))
        for match in matches.reversed() {
          if let nameRange = Range(match.range(at: 1), in: expandedText) {
            let name = String(expandedText[nameRange]).trimmingCharacters(in: .whitespaces)
            if let replacement = values[name] {
              let fullRange = Range(match.range, in: expandedText)!
              expandedText.replaceSubrange(fullRange, with: replacement)
              if !resolvedPlaceholders.contains(name) {
                resolvedPlaceholders.append(name)
              }
            }
          }
        }
      }
    }

    let data = APIExpandData(
      originalAbbreviation: expandReq.abbreviation,
      snippetId: entry.id,
      expandedText: expandedText,
      deleteCount: entry.abbreviation.count,
      placeholdersResolved: resolvedPlaceholders
    )
    return jsonResponse(APIExpandResponse(success: true, data: data))
  }

  // MARK: - Clipboard History

  private func handleGetClipboardHistory(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let limit = min(Int(request.query["limit"] ?? "50") ?? 50, 200)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)
    let kindFilter = request.query["kind"]
    let appFilter = request.query["app"]
    let pinnedFilter = request.query["pinned"]

    let startTime = CFAbsoluteTimeGetCurrent()
    let (items, _) = ClipboardDB.shared.search(
      query: "", limit: limit + offset, offset: 0, appBundle: appFilter, kind: kindFilter
    )

    var filtered = items
    if let pinned = pinnedFilter {
      let isPinned = pinned == "true" || pinned == "1"
      filtered = filtered.filter { ($0.pinned != 0) == isPinned }
    }

    let total = filtered.count
    let paged = Array(filtered.dropFirst(offset).prefix(limit))
    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let data = paged.map { item in
      APIClipboardItem(
        id: item.id ?? 0,
        kind: item.kind,
        textPreview: item.text.map { String($0.prefix(100)) },
        textLength: item.text?.count,
        appBundle: item.appBundle,
        pinned: item.pinned != 0,
        createdAt: isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.createdAt)))
      )
    }

    return jsonResponse(APIClipboardHistoryResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: total, durationMs: duration)
    ))
  }

  // MARK: - Clipboard Detail

  private func handleGetClipboardDetail(idStr: String) -> APIServer.HTTPResponse {
    guard let id = Int64(idStr) else {
      return errorResponse(code: "INVALID_ID", message: "Invalid clipboard item ID", statusCode: 400)
    }

    let (items, _) = ClipboardDB.shared.search(query: "", limit: 10000, offset: 0)
    guard let item = items.first(where: { $0.id == id }) else {
      return errorResponse(code: "NOT_FOUND", message: "Clipboard item not found", statusCode: 404)
    }

    let fullText = ClipboardDB.shared.fetchFullText(id: id)

    let detail = APIClipboardItemDetail(
      id: item.id ?? 0,
      kind: item.kind,
      text: fullText ?? item.text,
      uti: item.uti,
      sizeBytes: item.sizeBytes,
      hash: item.hash,
      appBundle: item.appBundle,
      pinned: item.pinned != 0,
      createdAt: isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.createdAt)))
    )
    return jsonResponse(APIClipboardDetailResponse(success: true, data: detail))
  }

  // MARK: - Clipboard Search

  private func handleClipboardSearch(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let q = request.query["q"], !q.isEmpty else {
      return errorResponse(code: "MISSING_QUERY", message: "Search query 'q' is required", statusCode: 400)
    }

    let limit = min(Int(request.query["limit"] ?? "50") ?? 50, 200)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)

    let startTime = CFAbsoluteTimeGetCurrent()
    let (items, _) = ClipboardDB.shared.search(query: q, limit: limit + offset, offset: 0)

    let total = items.count
    let paged = Array(items.dropFirst(offset).prefix(limit))
    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let data = paged.map { item in
      APIClipboardItem(
        id: item.id ?? 0,
        kind: item.kind,
        textPreview: item.text.map { String($0.prefix(100)) },
        textLength: item.text?.count,
        appBundle: item.appBundle,
        pinned: item.pinned != 0,
        createdAt: isoFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(item.createdAt)))
      )
    }

    return jsonResponse(APIClipboardHistoryResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: total, durationMs: duration)
    ))
  }

  // MARK: - Folders

  private func handleGetFolders() -> APIServer.HTTPResponse {
    let startTime = CFAbsoluteTimeGetCurrent()

    let allEntries = SnippetIndexManager.shared.entries
    var folderMap: [String: [SnippetEntry]] = [:]
    for entry in allEntries {
      folderMap[entry.folderName, default: []].append(entry)
    }

    let allRules = RuleManager.shared.getAllRulesDict()

    let data = folderMap.keys.sorted().map { folderName -> APIFolderSummary in
      let entries = folderMap[folderName] ?? []
      let rule = allRules[folderName]
      let isSpecial = folderName.hasPrefix("_")

      return APIFolderSummary(
        name: folderName,
        prefix: rule?.prefix ?? extractFolderPrefix(from: folderName),
        suffix: rule?.suffix ?? TriggerKeyManager.shared.getCurrentDefaultSymbol(),
        snippetCount: entries.count,
        triggerBias: rule?.triggerBias ?? 0,
        isSpecial: isSpecial
      )
    }

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    return jsonResponse(APIFolderListResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: data.count, durationMs: duration)
    ))
  }

  private func handleGetFolderDetail(name: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let limit = min(Int(request.query["limit"] ?? "50") ?? 50, 200)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)

    let startTime = CFAbsoluteTimeGetCurrent()
    let allEntries = SnippetIndexManager.shared.entries
    let folderEntries = allEntries.filter { $0.folderName == name }

    guard !folderEntries.isEmpty else {
      return errorResponse(code: "NOT_FOUND", message: "Folder not found: \(name)", statusCode: 404)
    }

    let rule = RuleManager.shared.getRule(for: name)
    let isSpecial = name.hasPrefix("_")

    let folder = APIFolderSummary(
      name: name,
      prefix: rule?.prefix ?? extractFolderPrefix(from: name),
      suffix: rule?.suffix ?? TriggerKeyManager.shared.getCurrentDefaultSymbol(),
      snippetCount: folderEntries.count,
      triggerBias: rule?.triggerBias ?? 0,
      isSpecial: isSpecial
    )

    let paged = Array(folderEntries.dropFirst(offset).prefix(limit))
    let snippets = paged.map { entry in
      APISnippetSummary(
        id: entry.id,
        abbreviation: entry.abbreviation,
        folder: entry.folderName,
        keyword: extractKeyword(from: entry.fileName),
        description: entry.snippetDescription,
        contentPreview: String(entry.content.prefix(100)),
        tags: entry.tags,
        relevanceScore: nil,
        usageCount: nil,
        lastUsed: nil
      )
    }

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    return jsonResponse(APIFolderDetailResponse(
      success: true,
      data: APIFolderDetailData(folder: folder, snippets: snippets),
      meta: APIMetadata(count: snippets.count, total: folderEntries.count, durationMs: duration)
    ))
  }

  // MARK: - Stats

  private func handleGetTopStats(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let limit = min(Int(request.query["limit"] ?? "10") ?? 10, 50)
    let startTime = CFAbsoluteTimeGetCurrent()

    let topStats = SnippetUsageManager.shared.getTopStats(limit: limit)
    let data = topStats.map { stat in
      APIUsageStat(
        abbreviation: stat.snippetName,
        folder: stat.folderName,
        description: stat.snippetName,
        usageCount: stat.usageCount,
        lastUsed: stat.lastUsed.isEmpty ? nil : stat.lastUsed
      )
    }

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    return jsonResponse(APIStatsTopResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: data.count, durationMs: duration)
    ))
  }

  private func handleGetStatsHistory(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let limit = min(Int(request.query["limit"] ?? "100") ?? 100, 1000)
    let offset = max(Int(request.query["offset"] ?? "0") ?? 0, 0)
    let from = request.query["from"]
    let to = request.query["to"]

    let startTime = CFAbsoluteTimeGetCurrent()

    let (items, total) = SnippetUsageManager.shared.getHistory(limit: limit, offset: offset, from: from, to: to)
    let data = items.map { item in
      APIUsageLog(
        id: item.id,
        abbreviation: item.snippetName,
        snippetPath: "\(item.folderName)/\(item.snippetName)",
        usedAt: item.usedAt,
        triggerBy: item.triggerBy
      )
    }

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    return jsonResponse(APIStatsHistoryResponse(
      success: true, data: data,
      meta: APIMetadata(count: data.count, total: total, durationMs: duration)
    ))
  }

  // MARK: - Triggers

  private func handleGetTriggers() -> APIServer.HTTPResponse {
    let defaultKey = TriggerKeyManager.shared.defaultTriggerKey
    let activeKeys = TriggerKeyManager.shared.activeTriggerKeys

    let defaultTrigger = APITriggerKey(
      symbol: defaultKey?.displayCharacter ?? TriggerKeyManager.shared.getCurrentDefaultSymbol(),
      keyCode: defaultKey.flatMap { Int($0.keyCode) },
      description: defaultKey?.displayName ?? "Default"
    )

    let active = activeKeys.map { key in
      APITriggerKey(
        symbol: key.displayCharacter,
        keyCode: Int(key.keyCode),
        description: key.displayName
      )
    }

    return jsonResponse(APITriggerResponse(
      success: true,
      data: APITriggerData(defaultTrigger: defaultTrigger, active: active)
    ))
  }

  // MARK: - Settings

  private func handleGetSettings() -> APIServer.HTTPResponse {
    // 환경변수 fSnippetCli_config → 기본 경로 순 (PreferencesManager.resolveAppRootPath 동일 로직)
    let appRootPath = PreferencesManager.resolveAppRootPath()
    let configPath = (appRootPath as NSString).appendingPathComponent("_config.yml")

    var configDict: [String: Any] = [:]
    if let data = FileManager.default.contents(atPath: configPath),
       let content = String(data: data, encoding: .utf8) {
      // 간단한 YAML 파싱: "key: value" 형태의 preferences 섹션
      var inPreferences = false
      for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "preferences:" { inPreferences = true; continue }
        if inPreferences && !line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.isEmpty {
          inPreferences = false
        }
        if inPreferences {
          let parts = trimmed.components(separatedBy: ": ")
          if parts.count >= 2 {
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: ": ")
              .trimmingCharacters(in: .whitespaces)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if let boolVal = Bool(value) { configDict[key] = boolVal }
            else if let intVal = Int(value) { configDict[key] = intVal }
            else { configDict[key] = value }
          }
        }
      }
    }

    let response: [String: Any] = [
      "success": true,
      "data": [
        "app_root_path": appRootPath,
        "config_path": configPath,
        "config": configDict
      ] as [String: Any]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
      return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
    }
    return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
  }

  // MARK: - 유틸리티

  private func extractKeyword(from fileName: String) -> String {
    let nameWithoutExt = (fileName as NSString).deletingPathExtension
    return nameWithoutExt.components(separatedBy: "===").first ?? nameWithoutExt
  }

  private func extractFolderPrefix(from folderName: String) -> String {
    let capitals = folderName.filter { $0.isUppercase }
    return capitals.isEmpty ? folderName.lowercased() : capitals.lowercased()
  }

  // MARK: - fSnippetCli 전용 엔드포인트

  /// GET /api/cli/status — fSnippetCli 상태 정보
  private func handleCliStatus(server: APIServer) -> APIServer.HTTPResponse {
    let snippetCount = SnippetIndexManager.shared.entries.count
    let status: [String: Any] = [
      "success": true,
      "data": [
        "app": "fSnippetCli",
        "status": "running",
        "uptime_seconds": server.uptimeSeconds,
        "snippet_count": snippetCount,
        "pid": ProcessInfo.processInfo.processIdentifier,
        "memory_usage_mb": ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
      ] as [String: Any]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: status),
       let json = String(data: data, encoding: .utf8) {
      return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
    }
    return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
  }

  /// GET /api/cli/version — fSnippetCli 버전 정보
  private func handleCliVersion() -> APIServer.HTTPResponse {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    let response: [String: Any] = [
      "success": true,
      "data": [
        "app": "fSnippetCli",
        "version": version,
        "build": build,
        "swift_version": "5.0",
        "macos_target": "14.0"
      ] as [String: Any]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: response),
       let json = String(data: data, encoding: .utf8) {
      return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
    }
    return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
  }

  /// POST /api/cli/quit — fSnippetCli 종료 (X-Confirm 헤더 필수)
  private func handleCliQuit(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard request.headers["x-confirm"] == "true" || request.headers["X-Confirm"] == "true" else {
      return errorResponse(code: "MISSING_HEADER", message: "X-Confirm: true 헤더가 필요합니다", statusCode: 400)
    }
    // 1초 후 종료 (응답 전송 후)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      NSApplication.shared.terminate(nil)
    }
    let response: [String: Any] = [
      "success": true,
      "data": ["message": "fSnippetCli가 1초 후 종료됩니다"]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: response),
       let json = String(data: data, encoding: .utf8) {
      return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
    }
    return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
  }

  // MARK: - Reload

  /// POST /api/v1/reload — 스니펫, 규칙, 설정을 런타임에 재로딩
  private func handleReload() -> APIServer.HTTPResponse {
    let startTime = CFAbsoluteTimeGetCurrent()

    var reloadedComponents: [String] = []
    var errors: [String] = []

    // 1. 설정 로드
    let settings = SettingsManager.shared.load()
    reloadedComponents.append("settings")

    // 2. 규칙 재로딩
    let ruleFilePath = (settings.basePath as NSString).appendingPathComponent("_rule.yml")
    if RuleManager.shared.loadRules(from: ruleFilePath) {
      reloadedComponents.append("rules")
    } else {
      errors.append("규칙 파일 로드 실패: \(ruleFilePath)")
    }

    // 3. 스니펫 파일 재로딩
    SnippetFileManager.shared.updateRootFolder(settings.basePath)
    SnippetFileManager.shared.loadAllSnippets(reason: "API/reload", force: true)
    reloadedComponents.append("snippets")

    // 4. 스니펫 인덱스 재구성
    SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)
    reloadedComponents.append("index")

    // 5. 트리거 키 설정 리로드
    TriggerKeyManager.shared.reloadSettings()
    reloadedComponents.append("triggers")

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    let snippetCount = SnippetIndexManager.shared.entries.count

    logI("🌐 Reload 완료: \(reloadedComponents.joined(separator: ", ")) (\(String(format: "%.1f", duration))ms)")

    let data = APIReloadData(
      reloadedComponents: reloadedComponents,
      snippetCount: snippetCount,
      errors: errors.isEmpty ? nil : errors,
      durationMs: duration
    )
    return jsonResponse(APIReloadResponse(success: errors.isEmpty, data: data))
  }

  // MARK: - Alfred Import

  /// POST /api/import/alfred — Alfred 스니펫 DB에서 임포트
  /// Body: {"db_path": "/path/to/snippets.alfdb"} 또는 빈 body (NSOpenPanel 사용)
  private func handleAlfredImport(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let dest = PreferencesManager.shared.string(forKey: "snippet_base_path", defaultValue: "~/Documents/finfra/fSnippetData/snippets_from_alfred")

    // body에서 db_path 추출 시도
    var dbPath: String?
    if let bodyData = request.body,
       let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
       let path = json["db_path"] as? String {
      dbPath = path
    }

    let result: Result<AlfredImporter.ImportedStats, Error>

    if let dbPath = dbPath {
      // db_path가 지정된 경우: 직접 임포트
      let dbURL = URL(fileURLWithPath: (dbPath as NSString).expandingTildeInPath)
      result = AlfredImporter.shared.importFromDB(dbURL: dbURL, destination: dest)
    } else {
      // db_path가 없는 경우: NSOpenPanel 사용 (메인 스레드에서 실행)
      var panelResult: Result<AlfredImporter.ImportedStats, Error>?
      DispatchQueue.main.sync {
        panelResult = AlfredImporter.shared.pickAndImport(destination: dest)
      }
      result = panelResult ?? .failure(NSError(domain: "APIRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import 실행 실패"]))
    }

    switch result {
    case .success(let stats):
      let response: [String: Any] = [
        "success": true,
        "data": [
          "total": stats.total,
          "collections": stats.collections,
          "destination": dest
        ] as [String: Any]
      ]
      if let data = try? JSONSerialization.data(withJSONObject: response),
         let json = String(data: data, encoding: .utf8) {
        return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
      }
      return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)

    case .failure(let error):
      return errorResponse(code: "IMPORT_FAILED", message: error.localizedDescription, statusCode: 400)
    }
  }

  // MARK: - CRUD: 폴더 생성/삭제

  /// POST /api/v1/folders — 새 스니펫 폴더 생성
  private func handleCreateFolder(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let bodyData = request.body,
          let req = try? JSONDecoder().decode(APICreateFolderRequest.self, from: bodyData) else {
      return errorResponse(code: "INVALID_REQUEST", message: "유효한 JSON body 필요 (name 필드)", statusCode: 400)
    }

    let name = req.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      return errorResponse(code: "INVALID_REQUEST", message: "폴더명이 비어있음", statusCode: 400)
    }

    // 파일시스템 안전 검증: 경로 탈출 방지
    guard !name.contains("/") && !name.contains("..") else {
      return errorResponse(code: "INVALID_REQUEST", message: "폴더명에 '/' 또는 '..'를 포함할 수 없음", statusCode: 400)
    }

    let rootURL = SnippetFileManager.shared.rootFolderURL
    let folderURL = rootURL.appendingPathComponent(name)

    // 이미 존재하는지 확인
    if FileManager.default.fileExists(atPath: folderURL.path) {
      return errorResponse(code: "ALREADY_EXISTS", message: "폴더가 이미 존재함: \(name)", statusCode: 409)
    }

    do {
      try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
      logI("🌐 폴더 생성 완료: \(name)")

      // 스니펫 인덱스 리로드
      SnippetFileManager.shared.loadAllSnippets(reason: "API/createFolder", force: true)

      let data = APIFolderMutationData(name: name, message: "폴더 생성 완료")
      return jsonResponse(APIFolderMutationResponse(success: true, data: data), statusCode: 201)
    } catch {
      logE("🌐 ❌ 폴더 생성 실패: \(error)")
      return errorResponse(code: "CREATE_FAILED", message: "폴더 생성 실패: \(error.localizedDescription)", statusCode: 500)
    }
  }

  /// DELETE /api/v1/folders/{name} — 스니펫 폴더 삭제
  private func handleDeleteFolder(name: String) -> APIServer.HTTPResponse {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      return errorResponse(code: "INVALID_REQUEST", message: "폴더명이 비어있음", statusCode: 400)
    }

    guard !trimmedName.contains("/") && !trimmedName.contains("..") else {
      return errorResponse(code: "INVALID_REQUEST", message: "폴더명에 '/' 또는 '..'를 포함할 수 없음", statusCode: 400)
    }

    let rootURL = SnippetFileManager.shared.rootFolderURL
    let folderURL = rootURL.appendingPathComponent(trimmedName)

    guard FileManager.default.fileExists(atPath: folderURL.path) else {
      return errorResponse(code: "NOT_FOUND", message: "폴더를 찾을 수 없음: \(trimmedName)", statusCode: 404)
    }

    // 폴더 내 파일 수 확인
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
    let snippetFiles = contents.filter { !$0.hasPrefix(".") && !$0.hasPrefix("_") }

    if !snippetFiles.isEmpty {
      return errorResponse(
        code: "FOLDER_NOT_EMPTY",
        message: "폴더에 \(snippetFiles.count)개의 파일이 있음. 비어있는 폴더만 삭제 가능",
        statusCode: 409
      )
    }

    do {
      try FileManager.default.removeItem(at: folderURL)
      logI("🌐 폴더 삭제 완료: \(trimmedName)")

      // 스니펫 인덱스 리로드
      SnippetFileManager.shared.loadAllSnippets(reason: "API/deleteFolder", force: true)

      let data = APIFolderMutationData(name: trimmedName, message: "폴더 삭제 완료")
      return jsonResponse(APIFolderMutationResponse(success: true, data: data))
    } catch {
      logE("🌐 ❌ 폴더 삭제 실패: \(error)")
      return errorResponse(code: "DELETE_FAILED", message: "폴더 삭제 실패: \(error.localizedDescription)", statusCode: 500)
    }
  }

  // MARK: - CRUD: 스니펫 생성/삭제

  /// POST /api/v1/snippets — 새 스니펫 파일 생성
  private func handleCreateSnippet(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let bodyData = request.body,
          let req = try? JSONDecoder().decode(APICreateSnippetRequest.self, from: bodyData) else {
      return errorResponse(code: "INVALID_REQUEST", message: "유효한 JSON body 필요 (folder, keyword, name, content 필드)", statusCode: 400)
    }

    let folder = req.folder.trimmingCharacters(in: .whitespacesAndNewlines)
    let keyword = req.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = req.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = req.content

    guard !folder.isEmpty else {
      return errorResponse(code: "INVALID_REQUEST", message: "folder가 비어있음", statusCode: 400)
    }
    guard !name.isEmpty else {
      return errorResponse(code: "INVALID_REQUEST", message: "name이 비어있음", statusCode: 400)
    }

    // 경로 탈출 방지
    guard !folder.contains("/") && !folder.contains("..") else {
      return errorResponse(code: "INVALID_REQUEST", message: "folder에 '/' 또는 '..'를 포함할 수 없음", statusCode: 400)
    }

    let rootURL = SnippetFileManager.shared.rootFolderURL
    let folderURL = rootURL.appendingPathComponent(folder)

    // 폴더 존재 여부 확인
    guard FileManager.default.fileExists(atPath: folderURL.path) else {
      return errorResponse(code: "NOT_FOUND", message: "폴더를 찾을 수 없음: \(folder)", statusCode: 404)
    }

    // 파일명 생성: keyword===name.txt (keyword가 비어있으면 ===name.txt)
    let fileName: String
    if keyword.isEmpty {
      fileName = "===\(name).txt"
    } else {
      fileName = "\(keyword)===\(name).txt"
    }

    let fileURL = folderURL.appendingPathComponent(fileName)

    // 이미 존재하는지 확인
    if FileManager.default.fileExists(atPath: fileURL.path) {
      return errorResponse(code: "ALREADY_EXISTS", message: "스니펫이 이미 존재함: \(fileName)", statusCode: 409)
    }

    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      let snippetId = "\(folder)/\(fileName)"
      logI("🌐 스니펫 생성 완료: \(snippetId)")

      // 스니펫 인덱스 리로드
      SnippetFileManager.shared.loadAllSnippets(reason: "API/createSnippet", force: true)
      let settings = SettingsManager.shared.load()
      SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)

      let data = APISnippetMutationData(id: snippetId, message: "스니펫 생성 완료")
      return jsonResponse(APISnippetMutationResponse(success: true, data: data), statusCode: 201)
    } catch {
      logE("🌐 ❌ 스니펫 생성 실패: \(error)")
      return errorResponse(code: "CREATE_FAILED", message: "스니펫 생성 실패: \(error.localizedDescription)", statusCode: 500)
    }
  }

  /// DELETE /api/v1/snippets/{id} — 스니펫 파일 삭제
  /// id 형식: "folder/keyword===name.txt" (URL 인코딩됨)
  private func handleDeleteSnippet(id: String) -> APIServer.HTTPResponse {
    let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedId.isEmpty else {
      return errorResponse(code: "INVALID_REQUEST", message: "스니펫 ID가 비어있음", statusCode: 400)
    }

    // 경로 탈출 방지
    guard !trimmedId.contains("..") else {
      return errorResponse(code: "INVALID_REQUEST", message: "ID에 '..'를 포함할 수 없음", statusCode: 400)
    }

    // ID에서 폴더와 파일명 분리
    let components = trimmedId.components(separatedBy: "/")
    guard components.count >= 2 else {
      return errorResponse(code: "INVALID_REQUEST", message: "유효하지 않은 스니펫 ID 형식 (folder/filename 형태 필요)", statusCode: 400)
    }

    let rootURL = SnippetFileManager.shared.rootFolderURL
    let fileURL = rootURL.appendingPathComponent(trimmedId)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return errorResponse(code: "NOT_FOUND", message: "스니펫을 찾을 수 없음: \(trimmedId)", statusCode: 404)
    }

    do {
      try FileManager.default.removeItem(at: fileURL)
      logI("🌐 스니펫 삭제 완료: \(trimmedId)")

      // 스니펫 인덱스 리로드 (캐시 무효화)
      SnippetFileManager.shared.loadAllSnippets(reason: "API/deleteSnippet", force: true)
      let settings = SettingsManager.shared.load()
      SnippetIndexManager.shared.loadSnippets(basePath: settings.basePath)

      let data = APISnippetMutationData(id: trimmedId, message: "스니펫 삭제 완료")
      return jsonResponse(APISnippetMutationResponse(success: true, data: data))
    } catch {
      logE("🌐 ❌ 스니펫 삭제 실패: \(error)")
      return errorResponse(code: "DELETE_FAILED", message: "스니펫 삭제 실패: \(error.localizedDescription)", statusCode: 500)
    }
  }
}
