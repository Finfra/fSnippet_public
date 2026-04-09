import ApplicationServices
import Foundation

/// 텍스트 대체 상태 변경 알림을 위한 프로토콜
protocol TextReplacementCoordinatorDelegate: AnyObject {
    func replacementStatusDidChange(isReplacing: Bool)

    // ✅ Issue 568_1: Event Tap Control for Shortcuts
    func requestEventMonitoringSuspension()
    func requestEventMonitoringResumption()
}

/// 개선된 텍스트 대체 작업 조정 클래스
class TextReplacementCoordinator {

    // MARK: - 속성

    private let textReplacer = TextReplacer.shared
    private var isPerformingReplacement = false {
        didSet {
            // ✅ 상태 변경 시 델리게이트에 알림
            if oldValue != isPerformingReplacement {
                delegate?.replacementStatusDidChange(isReplacing: isPerformingReplacement)
                logV("🚦 [TextReplacementCoordinator] 대체 상태 변경 알림: \(isPerformingReplacement)")
            }
        }
    }

    // ✅ 상태 변경 델리게이트
    weak var delegate: TextReplacementCoordinatorDelegate?

    // MARK: - Initialization

    init() {
        // ✅ TextReplacer의 델리게이트로 등록하여 Suspension 요청 수신
        textReplacer.delegate = self
    }

    // MARK: - 콜백

    typealias ReplacementCompletion = (Bool, String?) -> Void

    // MARK: - 공개 메서드

    func performReplacement(
        snippet: SnippetEntry,
        fromPopup: Bool,
        deleteLength: Int,
        referenceFrame: NSRect? = nil,  // ✅ Issue233: 기준 프레임
        completion: @escaping ReplacementCompletion
    ) {
        let startTime = Date()

        // 중복 실행 방지
        guard !isPerformingReplacement else {
            logW("🚦 텍스트 대체가 이미 진행 중입니다")
            completion(false, "이미 진행 중인 텍스트 대체가 있습니다")
            return
        }

        logV("🚦 텍스트 대체 시작: \(snippet.abbreviation) -> \(snippet.fileName)")

        // ✅ 텍스트 대체 플래그 설정 - didSet이 호출되어 델리게이트에 알림
        isPerformingReplacement = true

        // 파일 내용 읽기 (빈 파일 경로의 경우 빈 내용 사용)
        let content: String

        if snippet.filePath.path.isEmpty {
            // ✅ 빈 파일 경로의 경우 (모디파이어 기반 suffix 삭제 전용)
            content = ""
            logV("🚦 [Coordinator] 빈 스니펫 - 삭제 전용 모드")
        } else {
            // ✅ 일반 스니펫 파일 읽기
            do {
                content = try String(contentsOf: snippet.filePath, encoding: .utf8)
                logV("🚦 [Coordinator] 스니펫 파일 읽기 성공: '\(content.prefix(50))...' (\(content.count)자)")
                // logI("🚦 [Coordinator] 파일 경로: \(snippet.filePath.path)")
            } catch {
                let errorMessage = "파일 읽기 실패: \(error.localizedDescription)"
                logE(errorMessage)
                completeReplacement(success: false, error: errorMessage, completion: completion)
                return
            }
        }

        // 삭제할 길이 계산
        let lengthToDelete = calculateDeleteLength(
            snippet: snippet,
            fromPopup: fromPopup,
            deleteLength: deleteLength
        )

        // 삭제 길이 유효성 검증
        guard lengthToDelete >= 0 else {
            let error = "잘못된 삭제 길이: \(lengthToDelete)"
            logE(error)
            completeReplacement(success: false, error: error, completion: completion)
            return
        }

        // 실제 텍스트 대체 수행 - 완료 시 시간 측정
        performActualReplacement(
            content: content,
            lengthToDelete: lengthToDelete,
            snippet: snippet,
            referenceFrame: referenceFrame
        ) { success, error in
            let duration = Date().timeIntervalSince(startTime)
            // 성공 실패 여부와 상관없이 시도 시간 기록
            logPerf("🚦 Text Replacement: '\(snippet.abbreviation)'", duration: duration)

            completion(success, error)
        }
    }

    /// 현재 텍스트 대체 진행 상태
    var isReplacing: Bool {
        return isPerformingReplacement
    }

    // MARK: - 비공개 메서드

    private func calculateDeleteLength(
        snippet: SnippetEntry,
        fromPopup: Bool,
        deleteLength: Int
    ) -> Int {
        var lengthToDelete: Int

        if fromPopup {
            lengthToDelete = deleteLength
            logV("🚦 팝업 선택 - 검색어 \(deleteLength)자만 삭제 (triggerBias 적용)")
        } else {
            // ✅ Issue38 해결: 즉시 확장 모드에서도 triggerBias가 적용된 deleteLength 사용
            lengthToDelete = deleteLength

            logI(
                "🚦 트리거 확장: \(lengthToDelete)자 삭제"
            )
        }

        return max(0, lengthToDelete)
    }

    private func performActualReplacement(
        content: String,
        lengthToDelete: Int,
        snippet: SnippetEntry,
        referenceFrame: NSRect? = nil,
        completion: @escaping ReplacementCompletion
    ) {
        // ✅ 플레이스홀더 포함 여부 선판단
        // - 플레이스홀더가 있는 경우, 삭제 길이가 0이라도 TextReplacer.replaceTextSync 경로로 보내어
        //   플레이스홀더 입력 UI 및 마커 처리가 동작하도록 함.
        // Issue 568: Shortcuts execute syntax {(...)} also needs placeholder path
        let hasPlaceholders = content.contains("{{") || content.contains("{(")

        if hasPlaceholders {
            // ✅ 삭제용 가짜 문자열("xxx") 대신 실제 타이핑한 텍스트 추출 (취소 시 복원 목적)
            let rawBuffer = BufferManager.shared.getCurrentText()
            let visualBuffer = rawBuffer.replacingOccurrences(
                of: "\\{.*?\\}", with: "", options: .regularExpression)

            let abbreviationForDeletion: String
            if visualBuffer.count >= lengthToDelete && lengthToDelete > 0 {
                abbreviationForDeletion = String(visualBuffer.suffix(lengthToDelete))
                logV(
                    "🚦 [Coordinator] 플레이스홀더 감지됨 → replaceTextSync (삭제/복원 실제: '\(abbreviationForDeletion)')"
                )
            } else {
                abbreviationForDeletion = String(repeating: "x", count: max(0, lengthToDelete))
                logV(
                    "🚦 [Coordinator] 플레이스홀더 감지됨 → replaceTextSync (삭제/복원 가짜 폴백: '\(abbreviationForDeletion)')"
                )
            }

            // Issue 549: Pass snippet file path for relative path resolution
            textReplacer.replaceTextAsync(
                abbreviation: abbreviationForDeletion,
                with: content,
                referenceFrame: referenceFrame,
                snippetPath: snippet.filePath.path
            ) { [weak self] success, error in
                if success {
                    self?.completeReplacement(success: true, error: nil, completion: completion)
                } else {
                    let errorInfo = error?.localizedDescription ?? "알 수 없는 오류"
                    logE("🚦 텍스트 대체 실패(플레이스홀더 경로): \(errorInfo)")
                    self?.completeReplacement(
                        success: false, error: errorInfo, completion: completion)
                }
            }
            return
        }

        // lengthToDelete가 0인 경우 삭제 없이 바로 삽입
        if lengthToDelete == 0 {
            logV("🚦 삭제 없이 텍스트 삽입 (Async)")
            // Use async replacement with empty abbreviation
            textReplacer.replaceTextAsync(
                abbreviation: "",
                with: content,
                referenceFrame: referenceFrame,
                snippetPath: snippet.filePath.path,
                completion: { [weak self] success, error in
                    if success {
                        self?.completeReplacement(success: true, error: nil, completion: completion)
                    } else {
                        let errorInfo = error?.localizedDescription ?? "텍스트 삽입 실패"
                        logE(errorInfo)
                        self?.completeReplacement(
                            success: false, error: errorInfo, completion: completion)
                    }
                }
            )
            return
        }

        // 일반적인 텍스트 대체 (삭제 + 삽입)
        logV("🚦 [Coordinator] 텍스트 대체 수행: \(lengthToDelete)자 삭제 후 \(content.count)자 삽입")
        logI("🚦 [Coordinator] 삽입할 내용: '\(content.prefix(50))...'")

        // ✅ 삭제용 가짜 문자열("xxx") 대신 실제 타이핑한 텍스트 추출 (취소 시 복원 목적)
        let rawBuffer = BufferManager.shared.getCurrentText()
        let visualBuffer = rawBuffer.replacingOccurrences(
            of: "\\{.*?\\}", with: "", options: .regularExpression)

        let abbreviationForDeletion: String
        if visualBuffer.count >= lengthToDelete && lengthToDelete > 0 {
            abbreviationForDeletion = String(visualBuffer.suffix(lengthToDelete))
            logV("🚦 [Coordinator] 삭제/복원용 실제 텍스트 추출: '\(abbreviationForDeletion)'")
        } else {
            abbreviationForDeletion = String(repeating: "x", count: max(0, lengthToDelete))
            logV("🚦 [Coordinator] 삭제/복원용 가짜 문자열 폴백: '\(abbreviationForDeletion)'")
        }

        // Issue 549: Pass snippet file path here as well
        textReplacer.replaceTextAsync(
            abbreviation: abbreviationForDeletion,
            with: content,
            referenceFrame: referenceFrame,
            snippetPath: snippet.filePath.path
        ) { [weak self] success, error in
            if success {
                self?.completeReplacement(success: true, error: nil, completion: completion)
            } else {
                let errorInfo = error?.localizedDescription ?? "알 수 없는 오류"
                logE("🚦 텍스트 대체 실패: \(errorInfo)")
                self?.completeReplacement(success: false, error: errorInfo, completion: completion)
            }
        }
    }

    /// 텍스트 대체 완료 처리
    private func completeReplacement(
        success: Bool,
        error: String?,
        completion: @escaping ReplacementCompletion
    ) {
        // ✅ 플래그 해제 - didSet이 호출되어 델리게이트에 알림
        isPerformingReplacement = false

        if success {
            logV("🚦 텍스트 대체 성공: '\(error ?? "")'")
        } else {
            logE("🚦 텍스트 대체 실패: \(error ?? "알 수 없는 오류")")
        }

        // 완료 콜백 호출
        completion(success, error)
    }
}

// MARK: - TextReplacerDelegate 구현

extension TextReplacementCoordinator: TextReplacerDelegate {
    func requestEventMonitoringSuspension() {
        // 상위 델리게이트(KeyEventMonitor)에게 전달
        delegate?.requestEventMonitoringSuspension()
    }

    func requestEventMonitoringResumption() {
        // 상위 델리게이트(KeyEventMonitor)에게 전달
        delegate?.requestEventMonitoringResumption()
    }

    // Issue797: Placeholder 창 표시 시 replacement 상태 일시 해제
    // CGEventTapManager에서 isReplacing && isAppActive 조건으로 키 이벤트를 차단하므로,
    // Placeholder 입력 중에는 replacement 상태를 해제하여 키보드 입력을 허용
    func requestReplacementSuspension() {
        if isPerformingReplacement {
            isPerformingReplacement = false
            logV("🚦 [Issue797] Placeholder 입력을 위해 replacement 상태 일시 해제")
        }
    }

    func requestReplacementResumption() {
        if !isPerformingReplacement {
            isPerformingReplacement = true
            logV("🚦 [Issue797] Placeholder 입력 완료 — replacement 상태 복원")
        }
    }
}
