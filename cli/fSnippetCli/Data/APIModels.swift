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
