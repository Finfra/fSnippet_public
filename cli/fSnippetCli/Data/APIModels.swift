import Foundation

// MARK: - 공통 모델 (Common)

/// API 응답 메타데이터
struct APIMetadata: Codable {
  let count: Int
  let total: Int
  let durationMs: Double
  enum CodingKeys: String, CodingKey {
    case count, total
    case durationMs = "duration_ms"
  }
}

/// API 에러 상세 정보
struct APIErrorDetail: Codable {
  let code: String
  let message: String
}

/// API 에러 응답
struct APIErrorResponse: Codable {
  let success: Bool
  let error: APIErrorDetail
}

// MARK: - 헬스 체크 (Health)

/// 서버 상태 응답
struct HealthResponse: Codable {
  let status: String
  let app: String
  let version: String
  let port: Int
  let uptimeSeconds: Int
  let snippetCount: Int
  let clipboardCount: Int
  enum CodingKeys: String, CodingKey {
    case status, app, version, port
    case uptimeSeconds = "uptime_seconds"
    case snippetCount = "snippet_count"
    case clipboardCount = "clipboard_count"
  }
}

// MARK: - 스니펫 (Snippets)

/// 스니펫 요약 정보 (목록용)
struct APISnippetSummary: Codable {
  let id: String
  let abbreviation: String
  let folder: String
  let keyword: String
  let description: String
  let contentPreview: String
  let tags: [String]
  let relevanceScore: Double?
  let usageCount: Int?
  let lastUsed: String?
  enum CodingKeys: String, CodingKey {
    case id, abbreviation, folder, keyword, description, tags
    case contentPreview = "content_preview"
    case relevanceScore = "relevance_score"
    case usageCount = "usage_count"
    case lastUsed = "last_used"
  }
}

/// 스니펫 상세 정보
struct APISnippetDetail: Codable {
  let id: String
  let abbreviation: String
  let folder: String
  let keyword: String
  let description: String
  let content: String
  let tags: [String]
  let fileSize: Int64
  let modifiedAt: String
  let hasPlaceholders: Bool
  let placeholders: [String]
  enum CodingKeys: String, CodingKey {
    case id, abbreviation, folder, keyword, description, content, tags, placeholders
    case fileSize = "file_size"
    case modifiedAt = "modified_at"
    case hasPlaceholders = "has_placeholders"
  }
}

/// 스니펫 검색 응답
struct APISnippetSearchResponse: Codable {
  let success: Bool
  let data: [APISnippetSummary]
  let meta: APIMetadata
}

/// 스니펫 상세 조회 응답
struct APISnippetDetailResponse: Codable {
  let success: Bool
  let data: APISnippetDetail
}

/// 스니펫 확장 요청
struct APIExpandRequest: Codable {
  let abbreviation: String
  let placeholderValues: [String: String]?
  enum CodingKeys: String, CodingKey {
    case abbreviation
    case placeholderValues = "placeholder_values"
  }
}

/// 스니펫 확장 응답
struct APIExpandResponse: Codable {
  let success: Bool
  let data: APIExpandData
}

/// 스니펫 확장 결과 데이터
struct APIExpandData: Codable {
  let originalAbbreviation: String
  let snippetId: String
  let expandedText: String
  let deleteCount: Int
  let placeholdersResolved: [String]
  enum CodingKeys: String, CodingKey {
    case snippetId = "snippet_id"
    case originalAbbreviation = "original_abbreviation"
    case expandedText = "expanded_text"
    case deleteCount = "delete_count"
    case placeholdersResolved = "placeholders_resolved"
  }
}

// MARK: - 클립보드 (Clipboard)

/// 클립보드 항목 요약 (목록용)
struct APIClipboardItem: Codable {
  let id: Int64
  let kind: String
  let textPreview: String?
  let textLength: Int?
  let appBundle: String?
  let pinned: Bool
  let createdAt: String
  enum CodingKeys: String, CodingKey {
    case id, kind, pinned
    case textPreview = "text_preview"
    case textLength = "text_length"
    case appBundle = "app_bundle"
    case createdAt = "created_at"
  }
}

/// 클립보드 항목 상세 정보
struct APIClipboardItemDetail: Codable {
  let id: Int64
  let kind: String
  let text: String?
  let uti: String?
  let sizeBytes: Int64?
  let hash: String?
  let appBundle: String?
  let pinned: Bool
  let createdAt: String
  enum CodingKeys: String, CodingKey {
    case id, kind, text, uti, hash, pinned
    case sizeBytes = "size_bytes"
    case appBundle = "app_bundle"
    case createdAt = "created_at"
  }
}

/// 클립보드 히스토리 목록 응답
struct APIClipboardHistoryResponse: Codable {
  let success: Bool
  let data: [APIClipboardItem]
  let meta: APIMetadata
}

/// 클립보드 항목 상세 조회 응답
struct APIClipboardDetailResponse: Codable {
  let success: Bool
  let data: APIClipboardItemDetail
}

// MARK: - 폴더 (Folders)

/// 폴더 요약 정보
struct APIFolderSummary: Codable {
  let name: String
  let prefix: String
  let suffix: String
  let snippetCount: Int
  let triggerBias: Int
  let isSpecial: Bool
  enum CodingKeys: String, CodingKey {
    case name, prefix, suffix
    case snippetCount = "snippet_count"
    case triggerBias = "trigger_bias"
    case isSpecial = "is_special"
  }
}

/// 폴더 목록 응답
struct APIFolderListResponse: Codable {
  let success: Bool
  let data: [APIFolderSummary]
  let meta: APIMetadata
}

/// 폴더 상세 데이터
struct APIFolderDetailData: Codable {
  let folder: APIFolderSummary
  let snippets: [APISnippetSummary]
}

/// 폴더 상세 조회 응답
struct APIFolderDetailResponse: Codable {
  let success: Bool
  let data: APIFolderDetailData
  let meta: APIMetadata
}

// MARK: - 통계 (Stats)

/// 사용 통계 항목
struct APIUsageStat: Codable {
  let abbreviation: String
  let folder: String
  let description: String
  let usageCount: Int
  let lastUsed: String?
  enum CodingKeys: String, CodingKey {
    case abbreviation, folder, description
    case usageCount = "usage_count"
    case lastUsed = "last_used"
  }
}

/// 사용 이력 로그 항목
struct APIUsageLog: Codable {
  let id: Int64
  let abbreviation: String
  let snippetPath: String
  let usedAt: String
  let triggerBy: String
  enum CodingKeys: String, CodingKey {
    case id, abbreviation
    case snippetPath = "snippet_path"
    case usedAt = "used_at"
    case triggerBy = "trigger_by"
  }
}

/// 상위 사용 통계 응답
struct APIStatsTopResponse: Codable {
  let success: Bool
  let data: [APIUsageStat]
  let meta: APIMetadata
}

/// 사용 이력 조회 응답
struct APIStatsHistoryResponse: Codable {
  let success: Bool
  let data: [APIUsageLog]
  let meta: APIMetadata
}

// MARK: - 트리거 (Triggers)

/// 트리거 키 정보
struct APITriggerKey: Codable {
  let symbol: String
  let keyCode: Int?
  let description: String
  enum CodingKeys: String, CodingKey {
    case symbol, description
    case keyCode = "key_code"
  }
}

/// 트리거 데이터
struct APITriggerData: Codable {
  let defaultTrigger: APITriggerKey
  let active: [APITriggerKey]
  enum CodingKeys: String, CodingKey {
    case defaultTrigger = "default"
    case active
  }
}

/// 트리거 조회 응답
struct APITriggerResponse: Codable {
  let success: Bool
  let data: APITriggerData
}

// MARK: - 리로드 (Reload)

/// 리로드 결과 데이터
struct APIReloadData: Codable {
  let reloadedComponents: [String]
  let snippetCount: Int
  let errors: [String]?
  let durationMs: Double
  enum CodingKeys: String, CodingKey {
    case reloadedComponents = "reloaded_components"
    case snippetCount = "snippet_count"
    case errors
    case durationMs = "duration_ms"
  }
}

/// 리로드 응답
struct APIReloadResponse: Codable {
  let success: Bool
  let data: APIReloadData
}

// MARK: - CRUD 요청/응답 (Folders & Snippets)

/// 폴더 생성 요청
struct APICreateFolderRequest: Codable {
  let name: String
}

/// 폴더 생성/삭제 응답
struct APIFolderMutationResponse: Codable {
  let success: Bool
  let data: APIFolderMutationData
}

/// 폴더 변경 결과 데이터
struct APIFolderMutationData: Codable {
  let name: String
  let message: String
}

/// 스니펫 생성 요청
struct APICreateSnippetRequest: Codable {
  let folder: String
  let keyword: String
  let name: String
  let content: String
}

/// 스니펫 생성/삭제 응답
struct APISnippetMutationResponse: Codable {
  let success: Bool
  let data: APISnippetMutationData
}

/// 스니펫 변경 결과 데이터
struct APISnippetMutationData: Codable {
  let id: String
  let message: String
}

// MARK: - v2 공통 (Phase 1)

/// v2 표준 에러 응답 (`{ ok: false, error: {code, message} }`)
struct APIV2ErrorResponse: Codable {
  let ok: Bool
  let error: APIErrorDetail
}

/// v2 성공 래퍼 (`{ ok: true, data: ... }`) — 리소스 본체 직접 반환 대신 쓸 때 사용
struct APIV2SuccessResponse<T: Encodable>: Encodable {
  let ok: Bool
  let data: T
  init(_ data: T) {
    self.ok = true
    self.data = data
  }
}

/// 파괴적 동작 확인 요청 (Danger Zone)
struct APIV2ConfirmRequest: Codable {
  let confirm: String
}

// MARK: - v2 Settings General

struct APIV2TriggerKey: Codable {
  let keyCode: Int?
  let display: String
  let token: String
}

struct APIV2Shortcut: Codable {
  let keyCode: Int?
  let modifiers: [String]
  let display: String
  let token: String
}

struct APIV2Permissions: Codable {
  let accessibility: Bool
  let automation: Bool
}

struct APIV2GeneralSettings: Codable {
  let language: String
  let appearance: String
  let settingsFolder: String
  let snippetFolder: String
  let settingsHotkey: APIV2Shortcut
  let popupHotkey: APIV2Shortcut
  let triggerKey: APIV2TriggerKey
  let triggerBias: Int
  let quickSelectModifier: String
  let permissions: APIV2Permissions
}

// MARK: - v2 Settings Popup

struct APIV2PopupSettings: Codable {
  let searchScope: String
  let popupRows: Int
  let popupWidth: Int
  let previewWindowWidth: Int
}

// MARK: - v2 Settings Behavior

struct APIV2BehaviorSettings: Codable {
  let launchAtLogin: Bool
  let hideFromMenuBar: Bool
  let showInAppSwitcher: Bool
  let showNotifications: Bool
  let playSoundOnReady: Bool
}

// MARK: - v2 Advanced Info

struct APIV2AdvancedInfo: Codable {
  let appVersion: String
  let loadedSnippets: Int
  let statisticsRetentionDays: Int
}

// MARK: - v2 Snippet Folder Rule

struct APIV2SnippetFolderRule: Codable {
  let folder: String
  let prefix: String?
  let suffix: String?
  let openable: Bool
  let ruleManaged: Bool
}

struct APIV2SnippetFolderRulePatch: Decodable {
  let prefix: String?
  let suffix: String?
  let openable: Bool?
}

// MARK: - v2 Shortcut (named shortcut CRUD)

struct APIV2ShortcutRW: Codable {
  let keyCode: Int?
  let modifiers: [String]
  let display: String
  let token: String
}

// MARK: - v2 Advanced Debug / Performance / Input

struct APIV2DebugSettings: Codable {
  let logLevel: String
  let debugLogging: Bool
  let performanceMonitoring: Bool
}

struct APIV2PerformanceSettings: Codable {
  let keyBufferSize: Int
  let searchCacheSize: Int
}

struct APIV2InputSettings: Codable {
  let forceSearchInputLanguage: String?
}

// MARK: - v2 Patch Requests (partial, all fields optional)

struct APIV2PopupPatch: Decodable {
  let searchScope: String?
  let popupRows: Int?
  let popupWidth: Int?
  let previewWindowWidth: Int?
}

struct APIV2BehaviorPatch: Decodable {
  let launchAtLogin: Bool?
  let hideFromMenuBar: Bool?
  let showInAppSwitcher: Bool?
  let showNotifications: Bool?
  let playSoundOnReady: Bool?
}

struct APIV2DebugPatch: Decodable {
  let logLevel: String?
  let debugLogging: Bool?
  let performanceMonitoring: Bool?
}

struct APIV2PerformancePatch: Decodable {
  let keyBufferSize: Int?
  let searchCacheSize: Int?
}

struct APIV2InputPatch: Decodable {
  let forceSearchInputLanguage: String?
  // nil vs absent 구분을 위해 codingPath 체크 — 기본 Decodable 동작은 absent == nil이므로
  // clear 명령은 빈 문자열("")로 전달하는 규약을 사용함
}

struct APIV2GeneralSettingsPatch: Decodable {
  let language: String?
  let appearance: String?
  let settingsFolder: String?
  let snippetFolder: String?
  let triggerBias: Int?
  let quickSelectModifier: String?
  let showMenuBar: Bool?  // Issue821: GUI 종료 시 메뉴바 복원용
}

struct APIV2HistorySettingsPatch: Decodable {
  let viewer: [String: AnyCodable]?
  let hotkeysAndFilters: [String: AnyCodable]?
  let retention: [String: AnyCodable]?
}

// MARK: - v2 Snapshot

struct APIV2SettingsSnapshot: Codable {
  let version: String
  let exportedAt: String
  let general: APIV2GeneralSettings?
  let popup: APIV2PopupSettings?
  let behavior: APIV2BehaviorSettings?
  let history: APIV2HistorySettings?
  let advanced: APIV2AdvancedSnapshot?
  let snippetFolders: [APIV2SnippetFolderRule]?
  let perFolderExcludedFiles: [String: [String]]?
}

struct APIV2AdvancedSnapshot: Codable {
  let performance: APIV2PerformanceSettings?
  let input: APIV2InputSettings?
  let debug: APIV2DebugSettings?
  let api: AnyCodable?  // RestApiSettings (read-only in snapshot)
  let globalExcludedFiles: [String]?
}

// Placeholder for any-type JSON (used in snapshot for read-only fields)
struct AnyCodable: Codable {
  let value: Any?

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = nil
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array
    } else if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict
    } else {
      value = nil
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if value == nil {
      try container.encodeNil()
    } else if let bool = value as? Bool {
      try container.encode(bool)
    } else if let int = value as? Int {
      try container.encode(int)
    } else if let double = value as? Double {
      try container.encode(double)
    } else if let string = value as? String {
      try container.encode(string)
    } else if let array = value as? [AnyCodable] {
      try container.encode(array)
    } else if let dict = value as? [String: AnyCodable] {
      try container.encode(dict)
    } else {
      try container.encodeNil()
    }
  }
}

struct APIV2HistorySettings: Codable {
  let viewer: [String: AnyCodable]?
  let hotkeysAndFilters: [String: AnyCodable]?
  let retention: [String: AnyCodable]?
}

struct APIV2RestApiSettings: Codable {
  let enabled: Bool?
  let port: Int?
  let allowExternal: Bool?
  let allowedCidr: String?
  let running: Bool?  // read-only
}

// MARK: - PaidApp Lifecycle (Phase A)

/// POST /paidapp/register 요청 모델
struct PaidAppRegistrationRequest: Codable {
  let pid: Int32
  let bundlePath: String
  let sessionId: String
  let version: String
  let startTime: Int64

  enum CodingKeys: String, CodingKey {
    case pid, bundlePath, sessionId, version, startTime
  }
}

/// POST /paidapp/register 응답 모델
struct PaidAppRegistrationResponse: Codable {
  let ok: Bool
  let sessionId: String
  let cliVersion: String
  let minPaidAppVersion: String?
  let compatible: Bool

  enum CodingKeys: String, CodingKey {
    case ok, sessionId, cliVersion, minPaidAppVersion, compatible
  }
}

/// POST /paidapp/unregister 요청 모델
struct PaidAppUnregistrationRequest: Codable {
  let sessionId: String
}

/// GET /paidapp/status 응답 — 등록된 paidApp 메타데이터
struct PaidAppStatusData: Codable {
  let pid: Int32
  let bundlePath: String
  let sessionId: String
  let version: String
  let startTime: Int64
  let registeredAt: String

  enum CodingKeys: String, CodingKey {
    case pid, bundlePath, sessionId, version, startTime, registeredAt
  }
}

/// GET /paidapp/status 응답 래퍼
struct PaidAppStatusResponse: Codable {
  let registered: Bool
  let data: PaidAppStatusData?
}

/// GET /cli/version 응답 (minPaidAppVersion 확장)
struct CliVersionResponseV2: Codable {
  let success: Bool
  let data: CliVersionData?

  struct CliVersionData: Codable {
    let app: String
    let version: String
    let build: String
    let swiftVersion: String
    let macosTarget: String
    let minPaidAppVersion: String?

    enum CodingKeys: String, CodingKey {
      case app, version, build
      case swiftVersion = "swift_version"
      case macosTarget = "macos_target"
      case minPaidAppVersion
    }
  }
}

// MARK: - Shutdown (Issue52 Phase1)

struct ShutdownRequest: Codable {
  let reason: String?
  let delayMs: Int?
}

struct ShutdownResponse: Codable {
  let accepted: Bool
  let message: String
}
