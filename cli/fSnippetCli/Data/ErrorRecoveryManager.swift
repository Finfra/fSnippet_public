import Foundation
import Cocoa

/// 에러 복구 및 관리 시스템
/// SnippetError에 대한 자동 복구 로직과 사용자 안내를 제공
class ErrorRecoveryManager {
    
    // MARK: - Singleton
    
    static let shared = ErrorRecoveryManager()
    
    // MARK: - Properties
    
    private let recoveryQueue = DispatchQueue(label: "error.recovery", qos: .utility)
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 1.0
    
    // 복구 시도 기록
    private var recoveryAttempts: [String: Int] = [:]
    private let attemptsLock = NSLock()
    
    // 에러 통계
    @Atomic private var errorStats: [ErrorCategory: Int] = [:]
    @Atomic private var recoveryStats: [ErrorCategory: Int] = [:]
    
    private init() {}
    
    // MARK: - 메인 복구 메서드
    
    /// 에러에 대한 복구 시도
    /// - Parameters:
    ///   - error: 발생한 SnippetError
    ///   - fallback: 복구 실패 시 실행할 대체 로직
    ///   - completion: 복구 결과 콜백
    func handleError<T>(
        _ error: SnippetError,
        fallback: @escaping () -> T,
        completion: @escaping (Result<T, SnippetError>) -> Void
    ) {
        // 에러 통계 기록
        recordError(error)
        
        // 복구 가능성 확인
        guard error.isRecoverable else {
            logE("🔫 복구 불가능한 에러: \(error.errorDescription ?? "Unknown")")
            showErrorAlert(for: error)
            completion(.failure(error))
            return
        }
        
        // 복구 시도 횟수 확인
        let errorKey = getErrorKey(for: error)
        let attemptCount = getAttemptCount(for: errorKey)
        
        guard attemptCount < maxRetryAttempts else {
            logE("🔫 최대 복구 시도 횟수 초과: \(error.errorDescription ?? "Unknown")")
            showErrorAlert(for: error, isMaxAttemptsReached: true)
            completion(.failure(error))
            return
        }
        
        // 비동기로 복구 시도
        recoveryQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            self.incrementAttemptCount(for: errorKey)
            
            // 복구 지연 (네트워크 오류 등의 경우)
            if self.shouldDelay(for: error) {
                Thread.sleep(forTimeInterval: self.retryDelay * Double(attemptCount + 1))
            }
            
            // 구체적 복구 시도
            self.performRecovery(for: error) { success in
                DispatchQueue.main.async {
                    if success {
                        logV("🔫 에러 복구 성공: \(error.errorDescription ?? "Unknown")")
                        self.recordRecovery(for: error)
                        self.resetAttemptCount(for: errorKey)
                        
                        // 복구 성공 시 결과 반환 (fallback을 성공으로 간주)
                        completion(.success(fallback()))
                    } else {
                        // 복구 실패 시 재귀적으로 다시 시도
                        self.handleError(error, fallback: fallback, completion: completion)
                    }
                }
            }
        }
    }
    
    /// 동기식 에러 처리 (단순한 경우)
    /// - Parameters:
    ///   - error: 발생한 에러
    ///   - fallback: 대체값
    /// - Returns: 복구된 값 또는 fallback
    func handleErrorSync<T>(_ error: SnippetError, fallback: () -> T) -> T {
        recordError(error)
        
        if let recovered = performImmediateRecovery(for: error) as? T {
            recordRecovery(for: error)
            return recovered
        }
        
        logW("🔫 즉시 복구 실패, fallback 사용: \(error.errorDescription ?? "Unknown")")
        return fallback()
    }
    
    // MARK: - 구체적 복구 로직
    
    private func performRecovery(for error: SnippetError, completion: @escaping (Bool) -> Void) {
        switch error {
        case .fileNotFound(let path):
            handleFileNotFound(path: path, completion: completion)
            
        case .directoryNotFound(let path):
            handleDirectoryNotFound(path: path, completion: completion)
            
        case .cacheCorrupted:
            handleCacheCorruption(completion: completion)
            
        case .networkUnavailable:
            handleNetworkUnavailable(completion: completion)
            
        case .accessibilityPermissionDenied:
            handleAccessibilityPermission(completion: completion)
            
        case .settingsLoadFailed, .invalidSettingsFormat:
            handleSettingsRecovery(completion: completion)
            
        case .indexBuildFailed:
            handleIndexRecovery(completion: completion)
            
        case .clipboardOperationFailed:
            handleClipboardRecovery(completion: completion)
            
        default:
            logD("🔫 구체적 복구 로직이 없는 에러: \(error)")
            completion(false)
        }
    }
    
    // MARK: - 개별 복구 핸들러
    
    private func handleFileNotFound(path: String, completion: @escaping (Bool) -> Void) {
        logI("🔫 파일 복구 시도: \(path)")
        
        // 백업 위치 확인
        let backupPath = path + ".backup"
        if FileManager.default.fileExists(atPath: backupPath) {
            do {
                try FileManager.default.copyItem(atPath: backupPath, toPath: path)
                logV("🔫 백업에서 파일 복원 성공: \(path)")
                completion(true)
                return
            } catch {
                logE("🔫 백업 복원 실패: \(error)")
            }
        }
        
        // 기본 파일 생성 시도
        if createDefaultFile(at: path) {
            logV("🔫 기본 파일 생성 성공: \(path)")
            completion(true)
        } else {
            completion(false)
        }
    }
    
    private func handleDirectoryNotFound(path: String, completion: @escaping (Bool) -> Void) {
        logI("🔫 디렉토리 복구 시도: \(path)")
        
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logV("🔫 디렉토리 생성 성공: \(path)")
            completion(true)
        } catch {
            logE("🔫 디렉토리 생성 실패: \(path) - \(error)")
            completion(false)
        }
    }
    
    private func handleCacheCorruption(completion: @escaping (Bool) -> Void) {
        logV("🔫 캐시 복구 시도")
        
        // 캐시 디렉토리 정리 (번들ID별 분리)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.nowage.fSnippet"
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(bundleID)
        
        if let cacheURL = cacheURL {
            do {
                try FileManager.default.removeItem(at: cacheURL)
                try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
                logV("🔫 캐시 정리 및 재생성 완료")
                completion(true)
            } catch {
                logE("🔫 캐시 복구 실패: \(error)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    private func handleNetworkUnavailable(completion: @escaping (Bool) -> Void) {
        logV("🔫 네트워크 연결 확인 중...")
        
        // 간단한 연결 테스트
        var request = URLRequest(url: URL(string: "https://www.google.com")!)
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let isConnected = (response as? HTTPURLResponse)?.statusCode == 200
            logV("🔫 네트워크 연결 테스트 결과: \(isConnected ? "성공" : "실패")")
            completion(isConnected)
        }.resume()
    }
    
    private func handleAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        logV("🔫 접근성 권한 확인 중...")
        
        // 권한 상태 재확인
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if hasPermission {
            logV("🔫 접근성 권한 확인됨")
            completion(true)
        } else {
            logW("🔫 접근성 권한이 여전히 없음")
            // 사용자에게 권한 설정 안내
            showAccessibilityPermissionAlert()
            completion(false)
        }
    }
    
    private func handleSettingsRecovery(completion: @escaping (Bool) -> Void) {
        logV("🔫 설정 복구 시도")
        
        // 설정을 기본값으로 초기화
        UserDefaults.standard.removeObject(forKey: "snippetSettings")
        
        // 새로운 기본 설정 생성
        let settingsManager = SettingsManager.shared
        let defaultSettings = SnippetSettings.default
        settingsManager.save(defaultSettings)
        
        logV("🔫 설정이 기본값으로 복원됨")
        completion(true)
    }
    
    private func handleIndexRecovery(completion: @escaping (Bool) -> Void) {
        logI("🔫 스니펫 인덱스 재구성 시도")
        
        // 백그라운드에서 인덱스 재구성
        DispatchQueue.global(qos: .utility).async {
            // 메인 스니펫 매니저를 통해 인덱스 재구성 요청
            NotificationCenter.default.post(name: NSNotification.Name("RebuildSnippetIndex"), object: nil)
            
            DispatchQueue.main.async {
                logV("🔫 인덱스 재구성 요청 완료")
                completion(true)
            }
        }
    }
    
    private func handleClipboardRecovery(completion: @escaping (Bool) -> Void) {
        logV("🔫 클립보드 복구 시도")
        
        // 클립보드 접근 재시도
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let testString = "test"
            
            pasteboard.clearContents()
            let success = pasteboard.setString(testString, forType: .string)
            
            if success && pasteboard.string(forType: .string) == testString {
                pasteboard.clearContents() // 테스트 내용 제거
                logV("🔫 클립보드 복구 성공")
                completion(true)
            } else {
                logE("🔫 클립보드 복구 실패")
                completion(false)
            }
        }
    }
    
    // MARK: - 즉시 복구 로직
    
    private func performImmediateRecovery(for error: SnippetError) -> Any? {
        switch error {
        case .snippetNotFound:
            return [] // 빈 스니펫 배열 반환
            
        case .searchQueryInvalid:
            return [] // 빈 검색 결과 반환
            
        case .invalidInput:
            return nil // nil 반환하여 기본값 사용 유도
            
        default:
            return nil
        }
    }
    
    // MARK: - 헬퍼 메서드
    
    private func createDefaultFile(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let defaultContent = "// Default file created by fSnippet error recovery\n"
        
        do {
            try defaultContent.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    private func shouldDelay(for error: SnippetError) -> Bool {
        switch error {
        case .networkUnavailable, .timeoutExceeded, .apiRequestFailed:
            return true
        default:
            return false
        }
    }
    
    private func getErrorKey(for error: SnippetError) -> String {
        return "\(error.category.rawValue)_\(error.severity.rawValue)"
    }
    
    // MARK: - 시도 횟수 관리
    
    private func getAttemptCount(for key: String) -> Int {
        attemptsLock.lock()
        defer { attemptsLock.unlock() }
        return recoveryAttempts[key] ?? 0
    }
    
    private func incrementAttemptCount(for key: String) {
        attemptsLock.lock()
        defer { attemptsLock.unlock() }
        recoveryAttempts[key] = (recoveryAttempts[key] ?? 0) + 1
    }
    
    private func resetAttemptCount(for key: String) {
        attemptsLock.lock()
        defer { attemptsLock.unlock() }
        recoveryAttempts.removeValue(forKey: key)
    }
    
    // MARK: - 통계 관리
    
    private func recordError(_ error: SnippetError) {
        _errorStats.modify { stats in
            stats[error.category, default: 0] += 1
        }
        logD("🔫 에러 기록: \(error.category.rawValue) (총 \(errorStats[error.category] ?? 0)회)")
    }
    
    private func recordRecovery(for error: SnippetError) {
        _recoveryStats.modify { stats in
            stats[error.category, default: 0] += 1
        }
        logV("🔫 복구 성공 기록: \(error.category.rawValue) (총 \(recoveryStats[error.category] ?? 0)회)")
    }
    
    // MARK: - 사용자 알림
    
    private func showErrorAlert(for error: SnippetError, isMaxAttemptsReached: Bool = false) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = error.severity == .critical ? .critical : .warning
            alert.messageText = error.severity.emoji + " " + (error.errorDescription ?? "알 수 없는 오류")
            
            if let suggestion = error.recoverySuggestion {
                alert.informativeText = suggestion
            }
            
            if isMaxAttemptsReached {
                alert.informativeText += "\n\n최대 복구 시도 횟수에 도달했습니다."
            }
            
            alert.addButton(withTitle: "확인")
            
            if error.category == .settings || error.category == .system {
                alert.addButton(withTitle: "설정 열기")
            }
            
            let response = alert.runModal()
            
            if response == .alertSecondButtonReturn {
                self.openSystemPreferences(for: error)
            }
        }
    }
    
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "🔐 접근성 권한 필요"
            alert.informativeText = "fSnippet이 정상적으로 작동하려면 접근성 권한이 필요합니다.\n\n시스템 환경설정 > 보안 및 개인 정보 보호 > 접근성에서 fSnippet을 허용해주세요."
            alert.addButton(withTitle: "설정 열기")
            alert.addButton(withTitle: "취소")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
    
    private func openSystemPreferences(for error: SnippetError) {
        switch error.category {
        case .settings, .system:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        default:
            break
        }
    }
    
    // MARK: - 공개 통계 API
    
    /// 에러 통계 반환
    /// - Returns: 카테고리별 에러 발생 횟수
    func getErrorStatistics() -> [ErrorCategory: Int] {
        return errorStats
    }
    
    /// 복구 통계 반환
    /// - Returns: 카테고리별 복구 성공 횟수
    func getRecoveryStatistics() -> [ErrorCategory: Int] {
        return recoveryStats
    }
    
    /// 복구 성공률 반환
    /// - Returns: 카테고리별 복구 성공률 (0.0 ~ 1.0)
    func getRecoveryRate() -> [ErrorCategory: Double] {
        var rates: [ErrorCategory: Double] = [:]
        
        for category in ErrorCategory.allCases {
            let errors = errorStats[category] ?? 0
            let recoveries = recoveryStats[category] ?? 0
            
            if errors > 0 {
                rates[category] = Double(recoveries) / Double(errors)
            } else {
                rates[category] = 0.0
            }
        }
        
        return rates
    }
    
    /// 통계 초기화
    func resetStatistics() {
        errorStats = [:]
        recoveryStats = [:]
        attemptsLock.lock()
        recoveryAttempts.removeAll()
        attemptsLock.unlock()
        
        logV("🔫 에러 복구 통계가 초기화되었습니다")
    }
}