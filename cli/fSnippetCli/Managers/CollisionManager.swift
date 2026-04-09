import Foundation
import Cocoa

protocol CollisionManagerDelegate: AnyObject {
    func triggerCollisionMatch(_ candidate: AbbreviationMatcher.MatchCandidate)
}

/// Manages collision detection and delayed triggering for snippets
class CollisionManager {
    static let shared = CollisionManager()
    
    weak var delegate: CollisionManagerDelegate?
    
    // MARK: - Properties
    private var pendingCollisionMatch: AbbreviationMatcher.MatchCandidate?
    private var pendingCollisionTimer: DispatchWorkItem?
    private let pendingCollisionTimerQueue = DispatchQueue(label: "com.fsnippet.collisionTimer")
    
    private let abbreviationMatcher = AbbreviationMatcher() // New instance or passed in?
    // KeyEventMonitor has its own AbbreviationMatcher. 
    // If AbbreviationMatcher is stateless, creating a new one is fine.
    // Let's assume it is stateless or cheap to create for now.
    
    // MARK: - Public Methods
    
    func cancelPendingCollision() {
        if pendingCollisionMatch != nil {
            pendingCollisionMatch = nil
            pendingCollisionTimer?.cancel()
            pendingCollisionTimer = nil
            logV("💥 💥 [Collision] Pending match cancelled.")
        }
    }
    
    // Issue 479: 모든 소스(접미사 또는 트리거 키)에서 충돌을 설정하는 헬퍼
    func setupPendingCollision(candidate: AbbreviationMatcher.MatchCandidate) {
        logI("💥 💥 ⏳ [Collision] Match '\(candidate.snippet.abbreviation)' detected, but longer matches exist. Delaying trigger.")
        
        // 추가: 새로운 보류 타이머를 설정하기 전에 기존 타이머를 취소하여 리소스 누수 방지 및 Debounce 동작 보장 (Issue720_5)
        cancelPendingCollision()
        
        self.pendingCollisionMatch = candidate
        
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.triggerPendingCollisionMatch()
            }
        }
        self.pendingCollisionTimer = task
        self.pendingCollisionTimerQueue.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
    
    func validatePendingCollision(extensionChar char: String, currentBuffer: String) {
        guard let _ = pendingCollisionMatch else { return }

        // Issue 479: 실제 버퍼 내용 + 새 문자를 사용하여 충돌 유효성 검사
        // 이는 접미사 트리거(약어 내 트리거)와 키 트리거(약어 외 트리거)를 모두 지원함
        let potentialExtendedAbbr = currentBuffer + char
        
        // 새 문자가 보류 중인 일치를 더 긴 유효한 일치로 확장하는지 확인
        if abbreviationMatcher.hasLongerMatches(for: potentialExtendedAbbr) || 
           SnippetFileManager.shared.snippetMap[potentialExtendedAbbr] != nil {
            
            logV("💥 💥 [Collision] Valid extension '\(char)'. Extending wait (Cancelling Timer).")
            cancelPendingCollision()
            
        } else {
            logI("💥 💥 [Collision] Invalid extension '\(char)'. Triggering pending match now.")
            triggerPendingCollisionMatch()
            // 참고: triggerPendingCollisionMatch는 버퍼를 지움.
            // 새 문자 'char'는 지워진 버퍼에 추가됨.
        }
    }
    
    var hasPendingCollision: Bool {
        return pendingCollisionMatch != nil
    }
    
    // MARK: - Private Methods
    
    private func triggerPendingCollisionMatch() {
        guard let candidate = pendingCollisionMatch else { return }
        
        logI("💥 💥 [Collision] Timer Fired / Forced Trigger: Executing pending match '\(candidate.snippet.abbreviation)'")
        
        // Clear state first
        pendingCollisionMatch = nil
        pendingCollisionTimer?.cancel()
        pendingCollisionTimer = nil
        
        delegate?.triggerCollisionMatch(candidate)
    }
}