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

    let response = routeInternal(method: method, decodedPath: decodedPath, request: request, server: server)

    // Issue819: PATCH/POST settings 성공 시 ChangeTracker 기록
    if response.statusCode == 200,
       (method == "PATCH" || method == "POST" || method == "PUT" || method == "DELETE"),
       decodedPath.hasPrefix("/api/v2/settings") {
      let section = decodedPath
        .replacingOccurrences(of: "/api/v2/settings/", with: "")
        .components(separatedBy: "/").first ?? "unknown"
      ChangeTracker.shared.recordImmediate(type: "settings.changed", target: section)
    }

    return response
  }

  /// 내부 라우팅 로직
  private func routeInternal(method: String, decodedPath: String, request: APIServer.HTTPRequest, server: APIServer) -> APIServer.HTTPResponse {

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

    // ======================================================================
    // v2 — Settings CRUD
    // ======================================================================
    case ("GET", "/api/v2/settings/general"):
      return handleV2GetGeneral()
    case ("PATCH", "/api/v2/settings/general"):
      return handleV2PatchGeneral(request: request)
    case ("GET", "/api/v2/settings/popup"):
      return handleV2GetPopup()
    case ("PATCH", "/api/v2/settings/popup"):
      return handleV2PatchPopup(request: request)
    case ("GET", "/api/v2/settings/behavior"):
      return handleV2GetBehavior()
    case ("PATCH", "/api/v2/settings/behavior"):
      return handleV2PatchBehavior(request: request)
    case ("GET", "/api/v2/settings/history"):
      return handleV2GetHistory()
    case ("PATCH", "/api/v2/settings/history"):
      return handleV2PatchHistory(request: request)
    case ("GET", "/api/v2/settings/advanced/info"):
      return handleV2GetAdvancedInfo()
    case ("GET", "/api/v2/settings/advanced/debug"):
      return handleV2GetDebug()
    case ("PATCH", "/api/v2/settings/advanced/debug"):
      return handleV2PatchDebug(request: request)
    case ("GET", "/api/v2/settings/advanced/performance"):
      return handleV2GetPerformance()
    case ("PATCH", "/api/v2/settings/advanced/performance"):
      return handleV2PatchPerformance(request: request)
    case ("GET", "/api/v2/settings/advanced/input"):
      return handleV2GetInput()
    case ("PATCH", "/api/v2/settings/advanced/input"):
      return handleV2PatchInput(request: request)
    // Danger Zone — Settings Actions
    case ("POST", "/api/v2/settings/actions/reset-settings"):
      return handleV2ActionResetSettings(request: request)
    case ("POST", "/api/v2/settings/actions/reset-snippets"):
      return handleV2ActionResetSnippets(request: request)
    case ("POST", "/api/v2/settings/actions/clear-stats"):
      return handleV2ActionClearStats(request: request)
    case ("POST", "/api/v2/settings/actions/factory-reset"):
      return handleV2ActionFactoryReset(request: request)

    // Alfred Import (Advanced tab)
    case ("GET", "/api/v2/settings/advanced/alfred-import"):
      return handleV2GetAlfredImportSource()
    case ("PUT", "/api/v2/settings/advanced/alfred-import"):
      return handleV2PutAlfredImportSource(request: request)
    case ("POST", "/api/v2/settings/advanced/alfred-import/run"):
      return handleV2RunAlfredImport(request: request)

    // Excluded files — global (Advanced tab)
    case ("GET", "/api/v2/settings/advanced/excluded-files/global"):
      return handleV2GetGlobalExcluded()
    case ("POST", "/api/v2/settings/advanced/excluded-files/global/entries"):
      return handleV2PostGlobalExcluded(request: request)
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/settings/advanced/excluded-files/global/entries/"):
      let name = String(decodedPath.dropFirst("/api/v2/settings/advanced/excluded-files/global/entries/".count))
      return handleV2DeleteGlobalExcluded(filename: name.removingPercentEncoding ?? name, request: request)

    // Excluded files — per-folder (Folders tab)
    case ("GET", "/api/v2/settings/excluded-files/per-folder"):
      return handleV2GetPerFolderExcluded()
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/settings/excluded-files/per-folder/") && decodedPath.contains("/entries/"):
      return handleV2DeletePerFolderEntry(decodedPath: decodedPath, request: request)
    case ("POST", _) where decodedPath.hasPrefix("/api/v2/settings/excluded-files/per-folder/") && decodedPath.hasSuffix("/entries"):
      let rest = String(decodedPath.dropFirst("/api/v2/settings/excluded-files/per-folder/".count))
      let folder = String(rest.dropLast("/entries".count))
      return handleV2PostPerFolderEntry(folder: folder.removingPercentEncoding ?? folder, request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/settings/excluded-files/per-folder/"):
      let folder = String(decodedPath.dropFirst("/api/v2/settings/excluded-files/per-folder/".count))
      return handleV2GetPerFolderExcludedOne(folder: folder.removingPercentEncoding ?? folder)
    case ("PUT", _) where decodedPath.hasPrefix("/api/v2/settings/excluded-files/per-folder/"):
      let folder = String(decodedPath.dropFirst("/api/v2/settings/excluded-files/per-folder/".count))
      return handleV2PutPerFolderExcluded(folder: folder.removingPercentEncoding ?? folder, request: request)
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/settings/excluded-files/per-folder/"):
      let folder = String(decodedPath.dropFirst("/api/v2/settings/excluded-files/per-folder/".count))
      return handleV2DeletePerFolderExcluded(folder: folder.removingPercentEncoding ?? folder, request: request)

    case ("GET", "/api/v2/settings/snippet-folders"):
      return handleV2GetSnippetFolders()
    case ("POST", _) where decodedPath.hasPrefix("/api/v2/settings/snippet-folders/") && decodedPath.hasSuffix("/rebuild"):
      let rest = String(decodedPath.dropFirst("/api/v2/settings/snippet-folders/".count))
      let folder = String(rest.dropLast("/rebuild".count))
      return handleV2RebuildSnippetFolder(folder: folder.removingPercentEncoding ?? folder, request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/settings/snippet-folders/"):
      let folder = String(decodedPath.dropFirst("/api/v2/settings/snippet-folders/".count))
      return handleV2GetSnippetFolder(folder: folder.removingPercentEncoding ?? folder)
    case ("PATCH", _) where decodedPath.hasPrefix("/api/v2/settings/snippet-folders/"):
      let folder = String(decodedPath.dropFirst("/api/v2/settings/snippet-folders/".count))
      return handleV2PatchSnippetFolder(folder: folder.removingPercentEncoding ?? folder, request: request)

    case ("GET", "/api/v2/settings/shortcuts"):
      return handleV2GetShortcuts()
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/settings/shortcuts/"):
      let name = String(decodedPath.dropFirst("/api/v2/settings/shortcuts/".count))
      return handleV2GetShortcut(name: name)
    case ("PUT", _) where decodedPath.hasPrefix("/api/v2/settings/shortcuts/"):
      let name = String(decodedPath.dropFirst("/api/v2/settings/shortcuts/".count))
      return handleV2PutShortcut(name: name, request: request)
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/settings/shortcuts/"):
      let name = String(decodedPath.dropFirst("/api/v2/settings/shortcuts/".count))
      return handleV2DeleteShortcut(name: name, request: request)

    case ("GET", "/api/v2/settings/snapshot"):
      return handleV2GetSnapshot()
    case ("PUT", "/api/v2/settings/snapshot"):
      return handleV2PutSnapshot(request: request)

    // ======================================================================
    // v2 — Change Tracking (Issue819: 적응형 Polling)
    // ======================================================================
    case ("GET", "/api/v2/changes"):
      return handleV2GetChanges(request: request)

    // ======================================================================
    // v2 — Data endpoints (v1 슈퍼셋, Issue33)
    // ======================================================================
    // Snippets
    case ("GET", "/api/v2/snippets"):
      return handleSnippetList(request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/snippets/search"):
      return handleSnippetSearch(request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/snippets/by-abbreviation/"):
      let abbrev = String(decodedPath.dropFirst("/api/v2/snippets/by-abbreviation/".count))
      return handleGetByAbbreviation(abbrev: abbrev.removingPercentEncoding ?? abbrev)
    case ("POST", "/api/v2/snippets/expand"):
      return handleExpandSnippet(request: request)
    case ("POST", "/api/v2/snippets"):
      return handleCreateSnippet(request: request)
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/snippets/"):
      let id = String(decodedPath.dropFirst("/api/v2/snippets/".count))
      return handleDeleteSnippet(id: id.removingPercentEncoding ?? id)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/snippets/"):
      let id = String(decodedPath.dropFirst("/api/v2/snippets/".count))
      return handleGetSnippetDetail(id: id.removingPercentEncoding ?? id)

    // Clipboard
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/clipboard/search"):
      return handleClipboardSearch(request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/clipboard/history/"):
      let idStr = String(decodedPath.dropFirst("/api/v2/clipboard/history/".count))
      return handleGetClipboardDetail(idStr: idStr)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/clipboard/history"):
      return handleGetClipboardHistory(request: request)

    // Folders
    case ("GET", "/api/v2/folders"):
      return handleGetFolders()
    case ("POST", "/api/v2/folders"):
      return handleCreateFolder(request: request)
    case ("DELETE", _) where decodedPath.hasPrefix("/api/v2/folders/"):
      let name = String(decodedPath.dropFirst("/api/v2/folders/".count))
      return handleDeleteFolder(name: name.removingPercentEncoding ?? name)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/folders/"):
      let name = String(decodedPath.dropFirst("/api/v2/folders/".count))
      return handleGetFolderDetail(name: name.removingPercentEncoding ?? name, request: request)

    // Stats
    case ("GET", "/api/v2/stats/top"):
      return handleGetTopStats(request: request)
    case ("GET", _) where decodedPath.hasPrefix("/api/v2/stats/history"):
      return handleGetStatsHistory(request: request)

    // Triggers
    case ("GET", "/api/v2/triggers"):
      return handleGetTriggers()

    // CLI
    case ("GET", "/api/v2/cli/status"):
      return handleCliStatus(server: server)
    case ("GET", "/api/v2/cli/version"):
      return handleCliVersion()
    case ("POST", "/api/v2/cli/quit"):
      return handleCliQuit(request: request)

    // Shutdown (Issue52 Phase1)
    case ("POST", "/api/v2/shutdown"):
      return handleShutdown(request: request)

    // PaidApp Lifecycle (Phase A)
    case ("POST", "/api/v2/paidapp/register"):
      return handlePaidAppRegister(request: request)
    case ("POST", "/api/v2/paidapp/unregister"):
      return handlePaidAppUnregister(request: request)
    case ("GET", "/api/v2/paidapp/status"):
      return handlePaidAppStatus()

    // Reload
    case ("POST", "/api/v2/reload"):
      return handleReload()

    // Import
    case ("POST", "/api/v2/import/alfred"):
      return handleAlfredImport(request: request)

    default:
      return notFound()
    }
  }

  // MARK: - v2 Snippet Folder handlers

  /// 폴더의 openable 플래그 저장 pref key (폴더명 포함)
  private func v2FolderOpenableKey(_ folder: String) -> String {
    return "snippet_folder_openable.\(folder)"
  }

  private func v2BuildSnippetFolderRule(
    folder: String,
    ruleManaged: Bool,
    prefix: String?,
    suffix: String?
  ) -> APIV2SnippetFolderRule {
    let openable: Bool = PreferencesManager.shared.get(v2FolderOpenableKey(folder)) ?? true
    return APIV2SnippetFolderRule(
      folder: folder,
      prefix: (prefix?.isEmpty ?? true) ? nil : prefix,
      suffix: (suffix?.isEmpty ?? true) ? nil : suffix,
      openable: openable,
      ruleManaged: ruleManaged
    )
  }

  /// 디스크의 실제 폴더 목록을 rule 정보와 합쳐서 SnippetFolderRule 배열 생성.
  private func v2AllSnippetFolderRules() -> [APIV2SnippetFolderRule] {
    let allRules = RuleManager.shared.getAllRules()
    let rulesByName: [String: RuleManager.CollectionRule] =
      Dictionary(uniqueKeysWithValues: allRules.map { ($0.name, $0) })

    let folderURLs = SnippetFileManager.shared.getSnippetFolders()
    let diskFolderNames = Set(folderURLs.map { $0.lastPathComponent })

    var result: [APIV2SnippetFolderRule] = []
    var seen = Set<String>()

    // 1) 디스크 기준 폴더
    for name in diskFolderNames.sorted() {
      seen.insert(name)
      let rule = rulesByName[name]
      result.append(v2BuildSnippetFolderRule(
        folder: name,
        ruleManaged: rule != nil,
        prefix: rule?.prefix,
        suffix: rule?.suffix
      ))
    }
    // 2) rule 에만 존재하는 폴더 (디스크에는 없음)
    for (name, rule) in rulesByName where !seen.contains(name) {
      result.append(v2BuildSnippetFolderRule(
        folder: name,
        ruleManaged: true,
        prefix: rule.prefix,
        suffix: rule.suffix
      ))
    }
    return result
  }

  private func handleV2GetSnippetFolders() -> APIServer.HTTPResponse {
    return jsonResponse(v2AllSnippetFolderRules())
  }

  private func handleV2GetSnippetFolder(folder: String) -> APIServer.HTTPResponse {
    let all = v2AllSnippetFolderRules()
    guard let rule = all.first(where: { $0.folder == folder }) else {
      return v2Error(code: "not_found", message: "Snippet folder not found: \(folder)", statusCode: 404)
    }
    return jsonResponse(rule)
  }

  private func handleV2PatchSnippetFolder(folder: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2SnippetFolderRulePatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    // 폴더 존재 확인 (디스크 또는 rule)
    let all = v2AllSnippetFolderRules()
    guard all.contains(where: { $0.folder == folder }) else {
      return v2Error(code: "not_found", message: "Snippet folder not found: \(folder)", statusCode: 404)
    }

    // openable 은 preference 에만 저장
    if let openable = patch.openable {
      PreferencesManager.shared.set(openable, forKey: v2FolderOpenableKey(folder))
    }

    // prefix/suffix 중 하나라도 있으면 _rule.yml 갱신
    if patch.prefix != nil || patch.suffix != nil {
      var collections = RuleManager.shared.getAllRules()
      let existing = collections.first(where: { $0.name == folder })
      if existing == nil {
        // rule 에 없던 폴더면 새 항목 추가
        let newRule = RuleManager.CollectionRule(
          name: folder,
          suffix: patch.suffix ?? "",
          prefix: patch.prefix ?? "",
          description: nil,
          triggerBias: nil,
          prefixComment: nil,
          suffixComment: nil,
          triggerBiasComment: nil,
          descriptionComment: nil
        )
        collections.append(newRule)
      } else {
        var updated = existing!
        if let p = patch.prefix { updated.prefix = p }
        if let s = patch.suffix { updated.suffix = s }
        collections = collections.map { $0.name == folder ? updated : $0 }
      }

      let ok = RuleManager.shared.saveRules(to: nil, newCollections: collections)
      if !ok {
        return v2Error(code: "rule_save_failed", message: "Failed to save _rule.yml", statusCode: 500)
      }
    }

    // 최신 상태 재조회 후 반환
    let refreshed = v2AllSnippetFolderRules().first(where: { $0.folder == folder })
      ?? v2BuildSnippetFolderRule(folder: folder, ruleManaged: false, prefix: nil, suffix: nil)
    return jsonResponse(refreshed)
  }

  private func handleV2RebuildSnippetFolder(folder: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let all = v2AllSnippetFolderRules()
    guard all.contains(where: { $0.folder == folder }) else {
      return v2Error(code: "not_found", message: "Snippet folder not found: \(folder)", statusCode: 404)
    }
    // 폴더 개별 재빌드 API 가 없으므로 전체 재로딩으로 위임
    DispatchQueue.global().async {
      SnippetFileManager.shared.loadAllSnippets(reason: "API v2 rebuild(\(folder))", force: true)
    }
    let body = "{\"ok\":true,\"data\":{\"folder\":\"\(folder)\",\"status\":\"accepted\"}}"
    return APIServer.HTTPResponse(statusCode: 202, body: body)
  }

  // MARK: - v2 Danger Zone handlers
  // 모든 Danger Zone 은:
  //   1) localhost 강제 (requireLocalWrite)
  //   2) ConfirmRequest 의 confirm == "YES-I-KNOW" 필수 (clear-stats 는 spec 상 예외)
  //   3) 불일치 시 403 forbidden 반환 (spec §"제약")

  private static let v2ConfirmToken = "YES-I-KNOW"

  private func requireV2Confirm(_ request: APIServer.HTTPRequest) -> APIServer.HTTPResponse? {
    let (maybe, err) = decodeV2Body(request, as: APIV2ConfirmRequest.self)
    if let err = err { return err }
    guard let req = maybe else {
      return v2Error(code: "internal", message: "decode failed", statusCode: 500)
    }
    if req.confirm != APIRouter.v2ConfirmToken {
      return v2Error(
        code: "forbidden",
        message: "confirm token mismatch (expected \"\(APIRouter.v2ConfirmToken)\")",
        statusCode: 403
      )
    }
    return nil
  }

  private func v2ActionSuccess(_ action: String) -> APIServer.HTTPResponse {
    let body = "{\"ok\":true,\"data\":{\"action\":\"\(action)\",\"status\":\"done\"}}"
    return APIServer.HTTPResponse(statusCode: 200, body: body)
  }

  private func handleV2ActionResetSettings(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    if let err = requireV2Confirm(request) { return err }
    DispatchQueue.main.async {
      SettingsObservableObject.shared.resetSettingsOnly()
    }
    return v2ActionSuccess("reset-settings")
  }

  private func handleV2ActionResetSnippets(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    if let err = requireV2Confirm(request) { return err }
    DispatchQueue.main.async {
      SettingsObservableObject.shared.resetSnippetsDataOnly()
    }
    return v2ActionSuccess("reset-snippets")
  }

  private func handleV2ActionClearStats(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    // spec 상 ConfirmRequest 불필요. body 생략 허용.
    SnippetUsageManager.shared.deleteAllHistory()
    return v2ActionSuccess("clear-stats")
  }

  private func handleV2ActionFactoryReset(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    if let err = requireV2Confirm(request) { return err }
    // spec §"Factory Reset: 응답 선전송 후 내부 상태 초기화"
    // 먼저 응답을 만들고, 실제 파괴 작업은 약간 지연 후 main 큐에서 수행.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      SettingsObservableObject.shared.resetToDefaults(includeSnippets: true)
      SnippetUsageManager.shared.deleteAllHistory()
    }
    return v2ActionSuccess("factory-reset")
  }

  // MARK: - v2 Alfred Import handlers
  private static let v2AlfredSourceKey = "alfred_import_source_path"

  private func handleV2GetAlfredImportSource() -> APIServer.HTTPResponse {
    let path: String = PreferencesManager.shared.string(forKey: APIRouter.v2AlfredSourceKey, defaultValue: "")
    return jsonResponse(["sourcePath": path])
  }

  private func handleV2PutAlfredImportSource(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    struct Body: Decodable { let sourcePath: String? }
    let (maybe, err) = decodeV2Body(request, as: Body.self)
    if let err = err { return err }
    guard let path = maybe?.sourcePath, !path.isEmpty else {
      return v2Error(code: "invalid_argument", message: "sourcePath is required", statusCode: 400)
    }
    PreferencesManager.shared.set(path, forKey: APIRouter.v2AlfredSourceKey)
    return jsonResponse(["sourcePath": path])
  }

  private func handleV2RunAlfredImport(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let jobId = UUID().uuidString
    let dest = PreferencesManager.shared.string(forKey: "snippet_base_path", defaultValue: "~/Documents/finfra/fSnippetData/snippets_from_alfred")
    let sourcePath: String = PreferencesManager.shared.string(forKey: APIRouter.v2AlfredSourceKey, defaultValue: "")
    DispatchQueue.global(qos: .userInitiated).async {
      logI("🌐 v2 alfred-import job 시작: \(jobId)")
      let result: Result<AlfredImporter.ImportedStats, Error>
      if !sourcePath.isEmpty {
        let dbURL = URL(fileURLWithPath: (sourcePath as NSString).expandingTildeInPath)
        result = AlfredImporter.shared.importFromDB(dbURL: dbURL, destination: dest)
      } else {
        var panelResult: Result<AlfredImporter.ImportedStats, Error>?
        DispatchQueue.main.sync {
          panelResult = AlfredImporter.shared.pickAndImport(destination: dest)
        }
        result = panelResult ?? .failure(NSError(domain: "APIRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import 실행 실패"]))
      }
      switch result {
      case .success(let stats):
        logI("🌐 v2 alfred-import job \(jobId) 완료: total=\(stats.total)")
      case .failure(let error):
        logE("🌐 v2 alfred-import job \(jobId) 실패: \(error.localizedDescription)")
      }
    }
    let body: [String: Any] = ["jobId": jobId]
    if let data = try? JSONSerialization.data(withJSONObject: body),
       let json = String(data: data, encoding: .utf8) {
      return APIServer.HTTPResponse(statusCode: 202, body: json, headers: ["Content-Type": "application/json"])
    }
    return v2Error(code: "internal_error", message: "serialization failed", statusCode: 500)
  }

  // MARK: - v2 Excluded Files handlers
  // 저장소: PreferencesManager 의 두 키를 직접 읽고 씀 (SettingsManager.save 는
  // saveQueue + cachedSettings 이중 비동기 레이어 때문에 연속 호출 시 race 발생).
  // 한 가지 부작용: SettingsManager.cachedSettings 가 오래될 수 있으므로 쓰기 후
  // invalidateCache() 를 호출하여 다음 SnippetFileManager 로딩 시 신규 값을 읽게 함.
  private static let v2GlobalExcludedKey = "snippet_excluded_files"
  private static let v2PerFolderExcludedKey = "snippet_folder_excluded_files"

  private func v2NoContent() -> APIServer.HTTPResponse {
    return APIServer.HTTPResponse(statusCode: 204, body: "")
  }

  private func v2DecodeSingleFilename(_ request: APIServer.HTTPRequest) -> (String?, APIServer.HTTPResponse?) {
    struct Entry: Decodable { let filename: String? }
    let (maybe, err) = decodeV2Body(request, as: Entry.self)
    if let err = err { return (nil, err) }
    guard let e = maybe, let name = e.filename, !name.isEmpty else {
      return (nil, v2Error(code: "invalid_argument", message: "filename is required", statusCode: 400))
    }
    return (name, nil)
  }

  private func v2ReadGlobalExcluded() -> [String] {
    return PreferencesManager.shared.get(APIRouter.v2GlobalExcludedKey) ?? []
  }

  private func v2ReadPerFolderExcluded() -> [String: [String]] {
    return PreferencesManager.shared.get(APIRouter.v2PerFolderExcludedKey) ?? [:]
  }

  // --- Global (Advanced 탭) ---

  private func handleV2GetGlobalExcluded() -> APIServer.HTTPResponse {
    return jsonResponse(v2ReadGlobalExcluded())
  }

  private func handleV2PostGlobalExcluded(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (name, err) = v2DecodeSingleFilename(request)
    if let err = err { return err }
    guard let filename = name else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    var list = v2ReadGlobalExcluded()
    if list.contains(filename) {
      return v2Error(code: "conflict", message: "Already exists: \(filename)", statusCode: 409)
    }
    list.append(filename)
    PreferencesManager.shared.set(list, forKey: APIRouter.v2GlobalExcludedKey)
    return APIServer.HTTPResponse(statusCode: 201, body: "{\"ok\":true,\"data\":{\"filename\":\"\(filename)\"}}")
  }

  private func handleV2DeleteGlobalExcluded(filename: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    var list = v2ReadGlobalExcluded()
    guard list.contains(filename) else {
      return v2Error(code: "not_found", message: "Not in global excluded: \(filename)", statusCode: 404)
    }
    list.removeAll { $0 == filename }
    PreferencesManager.shared.set(list, forKey: APIRouter.v2GlobalExcludedKey)
    return v2NoContent()
  }

  // --- Per-folder (Folders 탭) ---

  private func handleV2GetPerFolderExcluded() -> APIServer.HTTPResponse {
    return jsonResponse(v2ReadPerFolderExcluded())
  }

  private func handleV2GetPerFolderExcludedOne(folder: String) -> APIServer.HTTPResponse {
    let map = v2ReadPerFolderExcluded()
    guard let list = map[folder] else {
      return v2Error(code: "not_found", message: "Per-folder excluded not set: \(folder)", statusCode: 404)
    }
    return jsonResponse(list)
  }

  private func handleV2PutPerFolderExcluded(folder: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: [String].self)
    if let err = err { return err }
    guard let list = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    var map = v2ReadPerFolderExcluded()
    map[folder] = list
    PreferencesManager.shared.set(map, forKey: APIRouter.v2PerFolderExcludedKey)
    return jsonResponse(list)
  }

  private func handleV2DeletePerFolderExcluded(folder: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    var map = v2ReadPerFolderExcluded()
    guard map[folder] != nil else {
      return v2Error(code: "not_found", message: "Per-folder excluded not set: \(folder)", statusCode: 404)
    }
    map.removeValue(forKey: folder)
    PreferencesManager.shared.set(map, forKey: APIRouter.v2PerFolderExcludedKey)
    return v2NoContent()
  }

  private func handleV2PostPerFolderEntry(folder: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (name, err) = v2DecodeSingleFilename(request)
    if let err = err { return err }
    guard let filename = name else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    var map = v2ReadPerFolderExcluded()
    var list = map[folder] ?? []
    if list.contains(filename) {
      return v2Error(code: "conflict", message: "Already exists in \(folder): \(filename)", statusCode: 409)
    }
    list.append(filename)
    map[folder] = list
    PreferencesManager.shared.set(map, forKey: APIRouter.v2PerFolderExcludedKey)
    return APIServer.HTTPResponse(
      statusCode: 201,
      body: "{\"ok\":true,\"data\":{\"folder\":\"\(folder)\",\"filename\":\"\(filename)\"}}"
    )
  }

  private func handleV2DeletePerFolderEntry(decodedPath: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let prefix = "/api/v2/settings/excluded-files/per-folder/"
    guard decodedPath.hasPrefix(prefix) else {
      return v2Error(code: "invalid_path", message: "Bad path", statusCode: 400)
    }
    let tail = String(decodedPath.dropFirst(prefix.count))
    guard let range = tail.range(of: "/entries/") else {
      return v2Error(code: "invalid_path", message: "Expected /entries/{filename}", statusCode: 400)
    }
    let folder = String(tail[..<range.lowerBound]).removingPercentEncoding ?? ""
    let filename = String(tail[range.upperBound...]).removingPercentEncoding ?? ""

    var map = v2ReadPerFolderExcluded()
    guard var list = map[folder] else {
      return v2Error(code: "not_found", message: "Folder not set: \(folder)", statusCode: 404)
    }
    guard list.contains(filename) else {
      return v2Error(code: "not_found", message: "Not in \(folder): \(filename)", statusCode: 404)
    }
    list.removeAll { $0 == filename }
    map[folder] = list
    PreferencesManager.shared.set(map, forKey: APIRouter.v2PerFolderExcludedKey)
    return v2NoContent()
  }

  // MARK: - v2 Shortcut name <-> preference key

  private static let v2ShortcutKeyMap: [(name: String, prefKey: String)] = [
    ("settingsHotkey", "settings.hotkey"),
    ("popupHotkey", "snippet_popup_hotkey"),
    ("togglePreviewHotkey", "history.preview.hotkey"),
    ("registerAsSnippetHotkey", "history.registerSnippet.hotkey"),
    ("toggleCollectionPauseHotkey", "history.pause.hotkey"),
    ("viewerHotkey", "history.viewer.hotkey"),
  ]

  private func v2PrefKey(forShortcutName name: String) -> String? {
    return APIRouter.v2ShortcutKeyMap.first(where: { $0.name == name })?.prefKey
  }

  /// 토큰(ex: "^⇧⌘;")을 modifiers 배열과 메인 키로 분해.
  private func v2ParseShortcutToken(_ token: String) -> (modifiers: [String], mainKey: String) {
    var mods: [String] = []
    var key = ""
    for ch in token {
      switch ch {
      case "⌃", "^": if !mods.contains("control") { mods.append("control") }
      case "⌥": if !mods.contains("option") { mods.append("option") }
      case "⌘": if !mods.contains("command") { mods.append("command") }
      case "⇧": if !mods.contains("shift") { mods.append("shift") }
      default:
        key.append(ch)
      }
    }
    return (mods, key)
  }

  private func v2BuildShortcut(token: String) -> APIV2ShortcutRW {
    let (mods, _) = v2ParseShortcutToken(token)
    return APIV2ShortcutRW(keyCode: nil, modifiers: mods, display: token, token: token)
  }

  // MARK: - v2 Shortcut handlers

  private func handleV2GetShortcuts() -> APIServer.HTTPResponse {
    let prefs = PreferencesManager.shared
    var result: [String: APIV2ShortcutRW] = [:]
    for (name, key) in APIRouter.v2ShortcutKeyMap {
      let token: String = prefs.get(key) ?? ""
      result[name] = v2BuildShortcut(token: token)
    }
    return jsonResponse(result)
  }

  private func handleV2GetShortcut(name: String) -> APIServer.HTTPResponse {
    guard let prefKey = v2PrefKey(forShortcutName: name) else {
      return v2Error(code: "not_found", message: "Unknown shortcut: \(name)", statusCode: 404)
    }
    let token: String = PreferencesManager.shared.get(prefKey) ?? ""
    return jsonResponse(v2BuildShortcut(token: token))
  }

  private func handleV2PutShortcut(name: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    guard let prefKey = v2PrefKey(forShortcutName: name) else {
      return v2Error(code: "not_found", message: "Unknown shortcut: \(name)", statusCode: 404)
    }
    let (maybe, err) = decodeV2Body(request, as: APIV2ShortcutRW.self)
    if let err = err { return err }
    guard let payload = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    // 우선순위: token 필드 > (modifiers + display 조합). display 가 비어 있으면 모디파이어만.
    let newToken: String
    if !payload.token.isEmpty {
      newToken = payload.token
    } else if !payload.display.isEmpty {
      newToken = payload.display
    } else {
      return v2Error(code: "invalid_argument", message: "token or display is required", statusCode: 400)
    }

    // 409 충돌 감지: 같은 토큰이 다른 name 에 이미 바인딩돼 있으면 거절.
    let prefs = PreferencesManager.shared
    for (otherName, otherKey) in APIRouter.v2ShortcutKeyMap where otherName != name {
      let existing: String = prefs.get(otherKey) ?? ""
      if !existing.isEmpty && existing == newToken {
        return v2Error(
          code: "conflict",
          message: "Shortcut \(newToken) already bound to \(otherName)",
          statusCode: 409
        )
      }
    }

    prefs.set(newToken, forKey: prefKey)
    // 런타임 재등록 시도 (ShortcutMgr 는 Preferences 변경 관찰자 보유 시 자동 반영)
    ShortcutMgr.shared.refreshAll()
    return jsonResponse(v2BuildShortcut(token: newToken))
  }

  private func handleV2DeleteShortcut(name: String, request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    guard let prefKey = v2PrefKey(forShortcutName: name) else {
      return v2Error(code: "not_found", message: "Unknown shortcut: \(name)", statusCode: 404)
    }
    PreferencesManager.shared.set("", forKey: prefKey)
    ShortcutMgr.shared.refreshAll()
    return APIServer.HTTPResponse(statusCode: 204, body: "")
  }

  // MARK: - v2 에러 헬퍼

  private func v2Error(code: String, message: String, statusCode: Int) -> APIServer.HTTPResponse {
    let err = APIV2ErrorResponse(ok: false, error: APIErrorDetail(code: code, message: message))
    return jsonResponse(err, statusCode: statusCode)
  }

  // MARK: - v2 Phase 1 핸들러

  private func buildV2General() -> APIV2GeneralSettings {
    let prefs = PreferencesManager.shared
    let language: String = prefs.get("language") ?? "system"
    let appearance: String = prefs.get("appearance") ?? "system"
    let settingsFolder: String = prefs.get("app_root_path")
      ?? (FileManager.default.homeDirectoryForCurrentUser
          .appendingPathComponent("Documents/finfra/fSnippetData").path)
    let snippetFolder: String = prefs.get("snippet_base_path") ?? "./snippets"

    let triggerKeyToken: String = prefs.get("snippet_trigger_key") ?? "{right_command}"
    let triggerBias: Int = prefs.get("snippet_trigger_bias") ?? 0
    let quickModifier: String = prefs.get("quick_select_modifier") ?? "command"

    let settingsHotkeyStr: String = prefs.get("settings.hotkey") ?? ""
    let popupHotkeyStr: String = prefs.get("snippet_popup_hotkey") ?? ""
    let popupKeyCode: Int? = prefs.get("snippet_popup_key_code")

    let permissions = APIV2Permissions(
      accessibility: AXIsProcessTrusted(),
      automation: false
    )

    return APIV2GeneralSettings(
      language: language,
      appearance: appearance,
      settingsFolder: settingsFolder,
      snippetFolder: snippetFolder,
      settingsHotkey: APIV2Shortcut(keyCode: nil, modifiers: [], display: settingsHotkeyStr, token: settingsHotkeyStr),
      popupHotkey: APIV2Shortcut(keyCode: popupKeyCode, modifiers: [], display: popupHotkeyStr, token: popupHotkeyStr),
      triggerKey: APIV2TriggerKey(keyCode: nil, display: triggerKeyToken, token: triggerKeyToken),
      triggerBias: triggerBias,
      quickSelectModifier: quickModifier,
      permissions: permissions
    )
  }

  private func buildV2Popup() -> APIV2PopupSettings {
    let prefs = PreferencesManager.shared
    let scope: String = prefs.get("snippet_popup_search_scope") ?? "keyword"
    let rows: Int = prefs.get("snippet_popup_rows") ?? 10
    let width: Int = {
      if let d: Double = prefs.get("snippet_popup_width") { return Int(d) }
      return prefs.get("snippet_popup_width") ?? 350
    }()
    let previewWidth: Int = {
      if let d: Double = prefs.get("history.preview.width") { return Int(d) }
      return prefs.get("history.preview.width") ?? 400
    }()
    return APIV2PopupSettings(
      searchScope: scope,
      popupRows: rows,
      popupWidth: width,
      previewWindowWidth: previewWidth
    )
  }

  private func buildV2Behavior() -> APIV2BehaviorSettings {
    let prefs = PreferencesManager.shared
    return APIV2BehaviorSettings(
      launchAtLogin: prefs.bool(forKey: "start_at_login"),
      hideFromMenuBar: prefs.bool(forKey: "hide_menu_bar_icon"),
      showInAppSwitcher: prefs.bool(forKey: "show_in_app_switcher"),
      showNotifications: prefs.bool(forKey: "show_notifications"),
      playSoundOnReady: prefs.bool(forKey: "play_ready_sound")
    )
  }

  private func buildV2AdvancedInfo() -> APIV2AdvancedInfo {
    let prefs = PreferencesManager.shared
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let loaded = SnippetIndexManager.shared.entries.count
    let retention: Int = prefs.get("stats.retentionDays") ?? 30
    return APIV2AdvancedInfo(
      appVersion: version,
      loadedSnippets: loaded,
      statisticsRetentionDays: retention
    )
  }

  private func handleV2GetGeneral() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2General())
  }

  private func handleV2GetPopup() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2Popup())
  }

  private func handleV2GetBehavior() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2Behavior())
  }

  private func handleV2GetAdvancedInfo() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2AdvancedInfo())
  }

  // MARK: - v2 공통 가드 / 헬퍼

  /// 쓰기(PATCH/PUT/POST/DELETE) 경로용 localhost 강제 가드.
  /// 비(非)localhost IP로 들어온 쓰기 요청은 `allowExternal` 설정과 무관하게 403으로 거부함.
  private func requireLocalWrite(_ request: APIServer.HTTPRequest) -> APIServer.HTTPResponse? {
    let ip = request.remoteIP
    let isLocal = ip == "127.0.0.1" || ip == "::1" || ip == "localhost" || ip.isEmpty || ip == "unknown"
    if !isLocal {
      return v2Error(code: "forbidden", message: "Write endpoints require localhost access", statusCode: 403)
    }
    return nil
  }

  /// JSON 바디 디코딩. 실패 시 (nil, errorResponse) 반환; 성공 시 (value, nil).
  private func decodeV2Body<T: Decodable>(_ request: APIServer.HTTPRequest, as type: T.Type) -> (T?, APIServer.HTTPResponse?) {
    guard let data = request.body, !data.isEmpty else {
      return (nil, v2Error(code: "invalid_argument", message: "Request body is required", statusCode: 400))
    }
    do {
      let value = try JSONDecoder().decode(T.self, from: data)
      return (value, nil)
    } catch {
      return (nil, v2Error(code: "invalid_argument", message: "Invalid JSON body: \(error.localizedDescription)", statusCode: 400))
    }
  }

  // MARK: - v2 Advanced GET builders

  private func buildV2Debug() -> APIV2DebugSettings {
    let prefs = PreferencesManager.shared
    let rawLevel: String = prefs.get("log_level") ?? "verbose"
    let level = rawLevel.lowercased()
    return APIV2DebugSettings(
      logLevel: level,
      debugLogging: prefs.bool(forKey: "debug_logging"),
      performanceMonitoring: prefs.bool(forKey: "performance_monitoring")
    )
  }

  private func buildV2Performance() -> APIV2PerformanceSettings {
    let prefs = PreferencesManager.shared
    let keyBuf: Int = prefs.get("performance.key_buffer_size") ?? 100
    let searchCache: Int = prefs.get("performance.search_cache_size") ?? 100
    return APIV2PerformanceSettings(keyBufferSize: keyBuf, searchCacheSize: searchCache)
  }

  private func buildV2Input() -> APIV2InputSettings {
    let prefs = PreferencesManager.shared
    let val: String? = prefs.get("force_search_input_language")
    let normalized = (val?.isEmpty == true) ? nil : val
    return APIV2InputSettings(forceSearchInputLanguage: normalized)
  }

  private func handleV2GetDebug() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2Debug())
  }

  private func handleV2GetPerformance() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2Performance())
  }

  private func handleV2GetInput() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2Input())
  }

  // MARK: - v2 PATCH handlers

  private func handleV2PatchPopup(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2PopupPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    if let scope = patch.searchScope {
      let allowed = ["keyword", "keywordName", "keywordNameContent"]
      guard allowed.contains(scope) else {
        return v2Error(code: "invalid_argument", message: "searchScope must be one of \(allowed)", statusCode: 400)
      }
    }
    if let rows = patch.popupRows, !(1...30).contains(rows) {
      return v2Error(code: "invalid_argument", message: "popupRows must be between 1 and 30", statusCode: 400)
    }
    if let w = patch.popupWidth, !(200...2000).contains(w) {
      return v2Error(code: "invalid_argument", message: "popupWidth must be between 200 and 2000", statusCode: 400)
    }
    if let pw = patch.previewWindowWidth, !(0...2000).contains(pw) {
      return v2Error(code: "invalid_argument", message: "previewWindowWidth must be between 0 and 2000", statusCode: 400)
    }

    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.searchScope { config["snippet_popup_search_scope"] = v }
      if let v = patch.popupRows { config["snippet_popup_rows"] = v }
      if let v = patch.popupWidth { config["snippet_popup_width"] = Double(v) }
      if let v = patch.previewWindowWidth { config["history.preview.width"] = Double(v) }
    }
    return jsonResponse(buildV2Popup())
  }

  private func handleV2PatchBehavior(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2BehaviorPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.launchAtLogin { config["start_at_login"] = v }
      if let v = patch.hideFromMenuBar { config["hide_menu_bar_icon"] = v }
      if let v = patch.showInAppSwitcher { config["show_in_app_switcher"] = v }
      if let v = patch.showNotifications { config["show_notifications"] = v }
      if let v = patch.playSoundOnReady { config["play_ready_sound"] = v }
    }
    return jsonResponse(buildV2Behavior())
  }

  private func handleV2PatchDebug(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2DebugPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    if let level = patch.logLevel {
      let allowed = ["verbose", "debug", "info", "warning", "error", "critical"]
      guard allowed.contains(level.lowercased()) else {
        return v2Error(code: "invalid_argument", message: "logLevel must be one of \(allowed)", statusCode: 400)
      }
    }

    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.logLevel { config["log_level"] = v.lowercased() }
      if let v = patch.debugLogging { config["debug_logging"] = v }
      if let v = patch.performanceMonitoring { config["performance_monitoring"] = v }
    }
    return jsonResponse(buildV2Debug())
  }

  private func handleV2PatchPerformance(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2PerformancePatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    if let v = patch.keyBufferSize, !(10...10000).contains(v) {
      return v2Error(code: "invalid_argument", message: "keyBufferSize must be between 10 and 10000", statusCode: 400)
    }
    if let v = patch.searchCacheSize, !(10...10000).contains(v) {
      return v2Error(code: "invalid_argument", message: "searchCacheSize must be between 10 and 10000", statusCode: 400)
    }

    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.keyBufferSize { config["performance.key_buffer_size"] = v }
      if let v = patch.searchCacheSize { config["performance.search_cache_size"] = v }
    }
    return jsonResponse(buildV2Performance())
  }

  private func handleV2PatchInput(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2InputPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }
    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.forceSearchInputLanguage {
        if v.isEmpty {
          config.removeValue(forKey: "force_search_input_language")
        } else {
          config["force_search_input_language"] = v
        }
      }
    }
    return jsonResponse(buildV2Input())
  }

  private func handleV2GetSnapshot() -> APIServer.HTTPResponse {
    let globalExcluded: [String]? = PreferencesManager.shared.get(APIRouter.v2GlobalExcludedKey)
    let perFolder: [String: [String]]? = PreferencesManager.shared.get(APIRouter.v2PerFolderExcludedKey)
    let snippetFolders = v2AllSnippetFolderRules()

    let advanced = APIV2AdvancedSnapshot(
      performance: buildV2Performance(),
      input: buildV2Input(),
      debug: buildV2Debug(),
      api: nil,
      globalExcludedFiles: globalExcluded
    )

    let snapshot = APIV2SettingsSnapshot(
      version: "2.0.0",
      exportedAt: isoFormatter.string(from: Date()),
      general: buildV2General(),
      popup: buildV2Popup(),
      behavior: buildV2Behavior(),
      history: buildV2History(),
      advanced: advanced,
      snippetFolders: snippetFolders,
      perFolderExcludedFiles: perFolder
    )
    return jsonResponse(snapshot)
  }

  private func handleV2PutSnapshot(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (snap, err) = decodeV2Body(request, as: APIV2SettingsSnapshot.self)
    if let err = err { return err }
    guard let snapshot = snap else {
      return v2Error(code: "invalid_argument", message: "snapshot is required", statusCode: 400)
    }

    // 부분 복원 (개선 전): 스냅샷 구조 검증만. 세부 필드 매핑은 향후 개선.
    // 현재는 요청이 유효함을 확인하고 수락함.
    // TODO: PreferencesManager 키 매핑을 정확히 파악 후 각 섹션 복원 구현

    // 제공된 섹션만 적용 (개선 전 패스스루)
    if snapshot.general != nil {
      logD("Snapshot: general 섹션 제공됨 (현재 무시)")
    }
    if snapshot.popup != nil {
      logD("Snapshot: popup 섹션 제공됨 (현재 무시)")
    }
    if snapshot.behavior != nil {
      logD("Snapshot: behavior 섹션 제공됨 (현재 무시)")
    }
    if snapshot.history != nil {
      logD("Snapshot: history 섹션 제공됨 (현재 무시)")
    }
    if snapshot.advanced != nil {
      logD("Snapshot: advanced 섹션 제공됨 (현재 무시)")
    }
    if snapshot.perFolderExcludedFiles != nil {
      logD("Snapshot: perFolderExcludedFiles 제공됨 (현재 무시)")
    }
    if snapshot.snippetFolders != nil {
      logD("Snapshot: snippetFolders 제공됨 (현재 무시)")
    }

    logI("🌐 Snapshot PUT 요청 유효성 검증 완료 (복원은 향후 구현)")
    return v2NoContent()
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

  // MARK: - Shutdown Handler (Issue52 Phase1)

  /// POST /api/v2/shutdown — cliApp 프로세스 종료 (paidApp 종료 연동용)
  private func handleShutdown(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let body = request.body.flatMap { try? JSONDecoder().decode(ShutdownRequest.self, from: $0) }
    let reason = body?.reason ?? "unspecified"
    let delayMs = max(0, body?.delayMs ?? 0)

    logI("🛑 [APIRouter] shutdown 요청: reason=\(reason), delayMs=\(delayMs)")

    let resp = ShutdownResponse(accepted: true, message: "cliApp 종료 예약됨 (delay=\(delayMs)ms)")
    guard let payload = try? JSONEncoder().encode(resp),
          let json = String(data: payload, encoding: .utf8) else {
      return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs + 100)) {
      logI("🛑 [APIRouter] cliApp 종료 실행 (reason=\(reason))")
      NSApplication.shared.terminate(nil)
    }

    return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
  }

  // MARK: - PaidApp Lifecycle Handlers (Phase A)

  /// POST /api/v2/paidapp/register — paidApp 기동 등록
  private func handlePaidAppRegister(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let bodyBytes = request.body,
          let req = try? JSONDecoder().decode(PaidAppRegistrationRequest.self, from: bodyBytes)
    else {
      return errorResponse(code: "INVALID_REQUEST", message: "요청 본문 파싱 실패", statusCode: 400)
    }

    let cliVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let minPaidVersion: String? = nil  // 추후 설정 연동 (A-10)

    do {
      let reg = try PaidAppStateStore.shared.register(req)
      let isCompatible: Bool = minPaidVersion.map { compareVersions(req.version, greaterOrEqualTo: $0) } ?? true
      let resp = PaidAppRegistrationResponse(
        ok: true,
        sessionId: reg.sessionId,
        cliVersion: cliVersion,
        minPaidAppVersion: minPaidVersion,
        compatible: isCompatible
      )
      if let encoded = try? JSONEncoder().encode(resp),
         let json = String(data: encoded, encoding: .utf8) {
        return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
      }
      return errorResponse(code: "INTERNAL_ERROR", message: "직렬화 실패", statusCode: 500)
    } catch let err as PaidAppStateStore.RegisterError {
      switch err {
      case .duplicateSession(let id):
        return errorResponse(code: "DUPLICATE_SESSION", message: "이미 등록된 sessionId: \(id)", statusCode: 409)
      case .verificationFailed(let reason):
        logW("🏷️ [APIRouter] paidApp 등록 거부: \(reason)")
        return errorResponse(code: "VERIFICATION_FAILED", message: "발신자 검증 실패: \(reason)", statusCode: 403)
      }
    } catch {
      return errorResponse(code: "INTERNAL_ERROR", message: error.localizedDescription, statusCode: 500)
    }
  }

  /// POST /api/v2/paidapp/unregister — paidApp 종료 해제
  private func handlePaidAppUnregister(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    guard let bodyBytes = request.body,
          let req = try? JSONDecoder().decode(PaidAppUnregistrationRequest.self, from: bodyBytes)
    else {
      return errorResponse(code: "INVALID_REQUEST", message: "요청 본문 파싱 실패", statusCode: 400)
    }

    do {
      try PaidAppStateStore.shared.unregister(sessionId: req.sessionId)
      return APIServer.HTTPResponse(statusCode: 200, body: "{\"ok\":true}", headers: ["Content-Type": "application/json"])
    } catch let err as PaidAppStateStore.UnregisterError {
      switch err {
      case .notFound(let id):
        return errorResponse(code: "NOT_FOUND", message: "sessionId 미등록: \(id)", statusCode: 404)
      }
    } catch {
      return errorResponse(code: "INTERNAL_ERROR", message: error.localizedDescription, statusCode: 500)
    }
  }

  /// GET /api/v2/paidapp/status — paidApp 등록 상태 조회
  private func handlePaidAppStatus() -> APIServer.HTTPResponse {
    let isoFmt = isoFormatter
    if let reg = PaidAppStateStore.shared.status() {
      let data: [String: Any] = [
        "pid": reg.pid,
        "bundlePath": reg.bundlePath,
        "sessionId": reg.sessionId,
        "version": reg.version,
        "startTime": reg.startTime,
        "registeredAt": isoFmt.string(from: reg.registeredAt)
      ]
      let resp: [String: Any] = ["registered": true, "data": data]
      if let bytes = try? JSONSerialization.data(withJSONObject: resp),
         let json = String(data: bytes, encoding: .utf8) {
        return APIServer.HTTPResponse(statusCode: 200, body: json, headers: ["Content-Type": "application/json"])
      }
    }
    let resp = "{\"registered\":false,\"data\":null}"
    return APIServer.HTTPResponse(statusCode: 200, body: resp, headers: ["Content-Type": "application/json"])
  }

  // MARK: - 버전 비교 유틸리티

  private func compareVersions(_ version: String, greaterOrEqualTo minimum: String) -> Bool {
    let vParts = version.split(separator: ".").compactMap { Int($0) }
    let mParts = minimum.split(separator: ".").compactMap { Int($0) }
    let count = max(vParts.count, mParts.count)
    for i in 0..<count {
      let v = i < vParts.count ? vParts[i] : 0
      let m = i < mParts.count ? mParts[i] : 0
      if v > m { return true }
      if v < m { return false }
    }
    return true
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

  // MARK: - v2 General PATCH

  private func handleV2PatchGeneral(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2GeneralSettingsPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    // Validate appearance enum
    if let appearance = patch.appearance {
      let allowed = ["system", "light", "dark"]
      guard allowed.contains(appearance) else {
        return v2Error(code: "invalid_argument", message: "appearance must be one of \(allowed)", statusCode: 400)
      }
    }

    // Validate quickSelectModifier enum
    if let modifier = patch.quickSelectModifier {
      let allowed = ["command", "option", "control", "shift"]
      guard allowed.contains(modifier) else {
        return v2Error(code: "invalid_argument", message: "quickSelectModifier must be one of \(allowed)", statusCode: 400)
      }
    }

    // Validate triggerBias range
    if let bias = patch.triggerBias, !(-10...10).contains(bias) {
      return v2Error(code: "invalid_argument", message: "triggerBias must be between -10 and 10", statusCode: 400)
    }

    PreferencesManager.shared.batchUpdate { config in
      if let v = patch.language { config["language"] = v }
      if let v = patch.appearance { config["appearance"] = v }
      if let v = patch.settingsFolder { config["app_root_path"] = v }
      if let v = patch.snippetFolder { config["snippet_base_path"] = v }
      if let v = patch.triggerBias { config["snippet_trigger_bias"] = v }
      if let v = patch.quickSelectModifier { config["quick_select_modifier"] = v }
    }

    // Issue821: 메뉴바 표시 상태 제어 (런타임 상태, 설정 파일 미저장)
    if let showMenuBar = patch.showMenuBar {
      DispatchQueue.main.async {
        AppState.shared.showMenuBar = showMenuBar
        logI("🔧 [Issue821] 메뉴바 표시 상태 변경: \(showMenuBar)")
      }
    }

    return jsonResponse(buildV2General())
  }

  // MARK: - v2 History GET/PATCH

  private func buildV2History() -> APIV2HistorySettings {
    // For now, return a simplified structure
    // In a full implementation, this would extract all history-related settings
    return APIV2HistorySettings(
      viewer: nil,
      hotkeysAndFilters: nil,
      retention: nil
    )
  }

  private func handleV2GetHistory() -> APIServer.HTTPResponse {
    return jsonResponse(buildV2History())
  }

  private func handleV2PatchHistory(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    if let denied = requireLocalWrite(request) { return denied }
    let (maybe, err) = decodeV2Body(request, as: APIV2HistorySettingsPatch.self)
    if let err = err { return err }
    guard let patch = maybe else { return v2Error(code: "internal", message: "decode failed", statusCode: 500) }

    // Patch implementation: store subsection updates
    // For now, this is a simplified implementation
    if let _ = patch.viewer {
      // Update viewer settings (to be implemented with full schema)
    }
    if let _ = patch.hotkeysAndFilters {
      // Update hotkeys and filters (to be implemented with full schema)
    }
    if let _ = patch.retention {
      // Update retention settings (to be implemented with full schema)
    }

    return jsonResponse(buildV2History())
  }

  // MARK: - v2 Change Tracking (Issue819)

  private func handleV2GetChanges(request: APIServer.HTTPRequest) -> APIServer.HTTPResponse {
    let since: Int
    if let sinceParam = request.query["since"], let sinceVal = Int(sinceParam) {
      since = sinceVal
    } else {
      since = 0
    }

    let response = ChangeTracker.shared.changesSince(since)
    return jsonResponse(response)
  }
}
