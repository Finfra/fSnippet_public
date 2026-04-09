import Foundation

/// fSnippet 애플리케이션의 모든 에러를 통합 관리하는 구조화된 에러 타입
enum SnippetError: LocalizedError, Equatable {
    
    // MARK: - 파일 시스템 관련 에러
    case fileNotFound(path: String)
    case fileReadFailed(path: String, reason: String)
    case fileWriteFailed(path: String, reason: String)
    case directoryNotFound(path: String)
    case permissionDenied(path: String)
    case corruptedFile(path: String, reason: String)
    
    // MARK: - 스니펫 관련 에러
    case snippetNotFound(abbreviation: String)
    case duplicateSnippet(abbreviation: String)
    case invalidSnippetFormat(fileName: String, reason: String)
    case snippetContentEmpty(fileName: String)
    case abbreviationGenerationFailed(fileName: String)
    
    // MARK: - 텍스트 대체 관련 에러
    case textReplacementFailed(reason: String)
    case clipboardOperationFailed
    case keyEventGenerationFailed(keyCode: Int)
    case accessibilityPermissionDenied
    case cgEventPostFailed(keyCode: Int)
    
    // MARK: - 검색 및 인덱싱 관련 에러
    case indexBuildFailed(reason: String)
    case searchQueryInvalid(query: String)
    case searchTimedOut(timeout: TimeInterval)
    case cacheCorrupted
    
    // MARK: - 설정 관련 에러
    case settingsLoadFailed(reason: String)
    case settingsSaveFailed(reason: String)
    case invalidSettingsFormat(reason: String)
    case settingsValidationFailed(key: String, value: String)
    
    // MARK: - 네트워크 및 외부 리소스 관련 에러
    case networkUnavailable
    case resourceDownloadFailed(url: String)
    case apiRequestFailed(endpoint: String, statusCode: Int)
    case timeoutExceeded(operation: String)
    
    // MARK: - UI 및 사용자 인터페이스 관련 에러
    case popupDisplayFailed(reason: String)
    case keyboardInterceptFailed
    case windowManagementFailed(reason: String)
    case focusManagementFailed
    
    // MARK: - 시스템 관련 에러
    case memoryAllocationFailed
    case threadCreationFailed
    case operationCancelled(operation: String)
    case systemResourceUnavailable(resource: String)
    
    // MARK: - 일반적인 에러
    case invalidInput(parameter: String, reason: String)
    case configurationError(component: String, reason: String)
    case dependencyNotAvailable(dependency: String)
    case operationNotSupported(operation: String)
    case unknown(message: String)
    
    // MARK: - LocalizedError 구현
    
    var errorDescription: String? {
        switch self {
        // 파일 시스템 관련
        case .fileNotFound(let path):
            return "파일을 찾을 수 없습니다: \(path)"
        case .fileReadFailed(let path, let reason):
            return "파일 읽기 실패: \(path) (\(reason))"
        case .fileWriteFailed(let path, let reason):
            return "파일 쓰기 실패: \(path) (\(reason))"
        case .directoryNotFound(let path):
            return "디렉토리를 찾을 수 없습니다: \(path)"
        case .permissionDenied(let path):
            return "접근 권한이 없습니다: \(path)"
        case .corruptedFile(let path, let reason):
            return "손상된 파일: \(path) (\(reason))"
            
        // 스니펫 관련
        case .snippetNotFound(let abbreviation):
            return "스니펫을 찾을 수 없습니다: '\(abbreviation)'"
        case .duplicateSnippet(let abbreviation):
            return "중복된 스니펫: '\(abbreviation)'"
        case .invalidSnippetFormat(let fileName, let reason):
            return "올바르지 않은 스니펫 형식: \(fileName) (\(reason))"
        case .snippetContentEmpty(let fileName):
            return "스니펫 내용이 비어있습니다: \(fileName)"
        case .abbreviationGenerationFailed(let fileName):
            return "약어 생성 실패: \(fileName)"
            
        // 텍스트 대체 관련
        case .textReplacementFailed(let reason):
            return "텍스트 대체 실패: \(reason)"
        case .clipboardOperationFailed:
            return "클립보드 작업 실패"
        case .keyEventGenerationFailed(let keyCode):
            return "키 이벤트 생성 실패: \(keyCode)"
        case .accessibilityPermissionDenied:
            return "접근성 권한이 필요합니다"
        case .cgEventPostFailed(let keyCode):
            return "CGEvent 전송 실패: \(keyCode)"
            
        // 검색 및 인덱싱 관련
        case .indexBuildFailed(let reason):
            return "인덱스 구축 실패: \(reason)"
        case .searchQueryInvalid(let query):
            return "올바르지 않은 검색 쿼리: '\(query)'"
        case .searchTimedOut(let timeout):
            return "검색 시간 초과: \(timeout)초"
        case .cacheCorrupted:
            return "캐시 데이터가 손상되었습니다"
            
        // 설정 관련
        case .settingsLoadFailed(let reason):
            return "설정 로드 실패: \(reason)"
        case .settingsSaveFailed(let reason):
            return "설정 저장 실패: \(reason)"
        case .invalidSettingsFormat(let reason):
            return "올바르지 않은 설정 형식: \(reason)"
        case .settingsValidationFailed(let key, let value):
            return "설정 유효성 검사 실패: \(key) = \(value)"
            
        // 네트워크 관련
        case .networkUnavailable:
            return "네트워크에 연결할 수 없습니다"
        case .resourceDownloadFailed(let url):
            return "리소스 다운로드 실패: \(url)"
        case .apiRequestFailed(let endpoint, let statusCode):
            return "API 요청 실패: \(endpoint) (상태코드: \(statusCode))"
        case .timeoutExceeded(let operation):
            return "작업 시간 초과: \(operation)"
            
        // UI 관련
        case .popupDisplayFailed(let reason):
            return "팝업 표시 실패: \(reason)"
        case .keyboardInterceptFailed:
            return "키보드 이벤트 가로채기 실패"
        case .windowManagementFailed(let reason):
            return "윈도우 관리 실패: \(reason)"
        case .focusManagementFailed:
            return "포커스 관리 실패"
            
        // 시스템 관련
        case .memoryAllocationFailed:
            return "메모리 할당 실패"
        case .threadCreationFailed:
            return "스레드 생성 실패"
        case .operationCancelled(let operation):
            return "작업이 취소되었습니다: \(operation)"
        case .systemResourceUnavailable(let resource):
            return "시스템 리소스를 사용할 수 없습니다: \(resource)"
            
        // 일반적인 에러
        case .invalidInput(let parameter, let reason):
            return "잘못된 입력: \(parameter) (\(reason))"
        case .configurationError(let component, let reason):
            return "구성 오류: \(component) (\(reason))"
        case .dependencyNotAvailable(let dependency):
            return "의존성을 사용할 수 없습니다: \(dependency)"
        case .operationNotSupported(let operation):
            return "지원되지 않는 작업: \(operation)"
        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .fileNotFound, .directoryNotFound:
            return "요청한 경로에 파일 또는 디렉토리가 존재하지 않습니다."
        case .permissionDenied:
            return "파일 시스템 접근 권한이 부족합니다."
        case .accessibilityPermissionDenied:
            return "macOS 접근성 권한이 부여되지 않았습니다."
        case .networkUnavailable:
            return "인터넷 연결이 끊어졌거나 불안정합니다."
        case .memoryAllocationFailed:
            return "사용 가능한 메모리가 부족합니다."
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound, .directoryNotFound:
            return "파일 경로를 확인하고 파일이 존재하는지 검증해주세요."
        case .permissionDenied:
            return "파일 또는 디렉토리의 권한을 확인하고 필요시 권한을 변경해주세요."
        case .accessibilityPermissionDenied:
            return "시스템 환경설정 > 보안 및 개인 정보 보호 > 접근성에서 fSnippet을 허용해주세요."
        case .networkUnavailable:
            return "네트워크 연결을 확인하고 다시 시도해주세요."
        case .memoryAllocationFailed:
            return "다른 애플리케이션을 종료하여 메모리를 확보하고 다시 시도해주세요."
        case .cacheCorrupted:
            return "앱을 재시작하면 캐시가 자동으로 재구성됩니다."
        case .duplicateSnippet(let abbreviation):
            return "다른 약어를 사용하거나 기존 '\(abbreviation)' 스니펫을 수정해주세요."
        default:
            return "앱을 재시작하거나 설정을 초기화해보세요."
        }
    }
    
    // MARK: - 에러 분류
    
    /// 에러의 심각도 레벨
    var severity: ErrorSeverity {
        switch self {
        case .memoryAllocationFailed, .threadCreationFailed, .systemResourceUnavailable:
            return .critical
        case .accessibilityPermissionDenied, .permissionDenied, .configurationError:
            return .high
        case .textReplacementFailed, .keyboardInterceptFailed, .popupDisplayFailed:
            return .medium
        case .snippetNotFound, .fileNotFound, .searchQueryInvalid:
            return .low
        default:
            return .medium
        }
    }
    
    /// 에러 카테고리
    var category: ErrorCategory {
        switch self {
        case .fileNotFound, .fileReadFailed, .fileWriteFailed, .directoryNotFound, 
             .permissionDenied, .corruptedFile:
            return .fileSystem
        case .snippetNotFound, .duplicateSnippet, .invalidSnippetFormat, 
             .snippetContentEmpty, .abbreviationGenerationFailed:
            return .snippet
        case .textReplacementFailed, .clipboardOperationFailed, .keyEventGenerationFailed, 
             .accessibilityPermissionDenied, .cgEventPostFailed:
            return .textReplacement
        case .indexBuildFailed, .searchQueryInvalid, .searchTimedOut, .cacheCorrupted:
            return .search
        case .settingsLoadFailed, .settingsSaveFailed, .invalidSettingsFormat, 
             .settingsValidationFailed:
            return .settings
        case .networkUnavailable, .resourceDownloadFailed, .apiRequestFailed, .timeoutExceeded:
            return .network
        case .popupDisplayFailed, .keyboardInterceptFailed, .windowManagementFailed, 
             .focusManagementFailed:
            return .ui
        case .memoryAllocationFailed, .threadCreationFailed, .operationCancelled, 
             .systemResourceUnavailable:
            return .system
        case .invalidInput, .configurationError, .dependencyNotAvailable, 
             .operationNotSupported, .unknown:
            return .general
        }
    }
    
    /// 자동 복구 가능 여부
    var isRecoverable: Bool {
        switch self {
        case .memoryAllocationFailed, .threadCreationFailed, .systemResourceUnavailable,
             .accessibilityPermissionDenied, .permissionDenied:
            return false
        case .networkUnavailable, .cacheCorrupted, .timeoutExceeded, .operationCancelled:
            return true
        default:
            return true
        }
    }
}

// MARK: - 보조 열거형들

/// 에러 심각도 레벨
enum ErrorSeverity: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low: return "낮음"
        case .medium: return "중간"
        case .high: return "높음"
        case .critical: return "치명적"
        }
    }
    
    var emoji: String {
        switch self {
        case .low: return "ℹ️"
        case .medium: return "⚠️"
        case .high: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// 에러 카테고리
enum ErrorCategory: String, CaseIterable {
    case fileSystem = "파일시스템"
    case snippet = "스니펫"
    case textReplacement = "텍스트대체"
    case search = "검색"
    case settings = "설정"
    case network = "네트워크"
    case ui = "사용자인터페이스"
    case system = "시스템"
    case general = "일반"
    
    var icon: String {
        switch self {
        case .fileSystem: return "📁"
        case .snippet: return "📝"
        case .textReplacement: return "✏️"
        case .search: return "🔍"
        case .settings: return "⚙️"
        case .network: return "🌐"
        case .ui: return "🖥️"
        case .system: return "⚡"
        case .general: return "❓"
        }
    }
}