import Foundation

/// 스니펫 삭제 길이 계산 및 전략을 담는 결과 구조체
struct CalculationResult {
    let deleteLength: Int
    let strategy: String
    let debugInfo: String
}

/// 약어 매칭 시 실제로 삭제해야 할 글자 수를 계산하는 매니저
class DeleteLengthManager {
    static let shared = DeleteLengthManager()

    /// 삭제 길이 계산 (Refactored for TriggerProcessor Logic Integration)
    func calculate(
        snippet: SnippetEntry,
        matchedLength: Int,
        triggeredByKey: Bool,
        rule: RuleManager.CollectionRule?,
        effectiveSuffix: String,
        triggerBias: Int,
        auxBias: Int,
        isKeyBuffered: Bool = false,
        matchedString: String? = nil,
        isImplicitTrigger: Bool = false,

        triggerKeyLabel: String? = nil,
        hasLongerMatches: Bool = false,
        isOptionKey: Bool = false
    ) -> CalculationResult {
        // let startTime = Date()
        var baseLen = 0
        var strategyInfo = ""
        var debugDetails = ""

        // 1. 기본 길이 결정 (항상 버퍼 매칭 길이 기반)
        if let ms = matchedString {
            baseLen = getVisualLength(of: ms)
            strategyInfo = "Visual from MatchedString"
            debugDetails = "VisualMatched(\(baseLen))"
        } else {
            baseLen = matchedLength
            strategyInfo = "MatchedLength fallback"
            debugDetails = "Matched(\(baseLen))"
        }

        // 2. 트리거 방식에 따른 보정
        if triggeredByKey {
            strategyInfo += " (Explicit Key)"

            // ✅ Centralized Logic from TriggerProcessor
            if triggerKeyLabel != nil, let r = rule {
                // Determine Visual Length of Trigger
                var triggerVisualLen = 0
                if isImplicitTrigger {  // Issue 697: explicitKey(단축키)에 의한 호출일 때만 트리거 길이를 수동 추가
                    if !r.suffix.isEmpty {
                        // suffix가 특수 키(Single Shortcut)인지 먼저 확인
                        if SingleShortcutMapper.shared.isValidSingleShortcut(r.suffix) {
                            triggerVisualLen = SingleShortcutMapper.shared.getVisualCount(
                                for: r.suffix)
                        } else {
                            triggerVisualLen = SingleShortcutMapper.shared.getVisualCount(
                                for: "{\(r.suffix)}")  // Suffix char as token if applicable
                            if triggerVisualLen == 0 {
                                triggerVisualLen = r.suffix.count  // Fallback to character count if not a known trigger
                            }
                        }
                    } else if let label = triggerKeyLabel {
                        let isSpecialKey = SingleShortcutMapper.shared.isValidSingleShortcut(label)
                        if isSpecialKey {
                            triggerVisualLen = SingleShortcutMapper.shared.getVisualCount(
                                for: label)
                        }
                    }
                }
                if triggerVisualLen > 0 {
                    baseLen += triggerVisualLen
                    debugDetails += " + TriggerVisual(\(triggerVisualLen))"
                }

                // B. Collision Adjustment
                // PrefixOnly & Normal Key: +VisualLen (Treat as Visible/Pending)
                if hasLongerMatches {
                    // Issue 561_2: Removed CollisionComp for PrefixOnly.
                    // It double-counted the trigger key (once in matchedLength, once here) causing over-deletion.
                }
            } else {
                debugDetails += " - NoLabel/Legacy(0)"
            }
        } else {
            strategyInfo += " (Buffer Match)"
            debugDetails += " - ImplicitTrigger(0)"
        }

        // 3. 편향 적용
        let finalLen = baseLen + triggerBias + auxBias
        let safeLen = max(0, finalLen)

        logD(
            "📏 [DeleteLengthManager] Result: \(safeLen) (\(debugDetails) + Bias(\(triggerBias)) + Aux(\(auxBias)))"
        )

        // let duration = Date().timeIntervalSince(startTime)
        // logPerf("📏 DeleteLength Calculation", duration: duration)

        return CalculationResult(
            deleteLength: safeLen,
            strategy: strategyInfo,
            debugInfo: debugDetails + " + Bias(\(triggerBias)) + Aux(\(auxBias))"
        )
    }

    /// 약어의 시각적 길이 계산
    func getVisualLength(of text: String) -> Int {
        var visualLength = 0
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            if scanner.scanString("{") != nil {
                if let tokenContent = scanner.scanUpToCharacters(
                    from: CharacterSet(charactersIn: "}")), scanner.scanString("}") != nil
                {
                    let fullToken = "{\(tokenContent)}"
                    let count = SingleShortcutMapper.shared.getVisualCount(for: fullToken)
                    visualLength += count
                } else {
                    visualLength += 1
                }
            } else {
                if scanner.scanCharacter() != nil {
                    visualLength += 1
                }
            }
        }
        return visualLength
    }
}
