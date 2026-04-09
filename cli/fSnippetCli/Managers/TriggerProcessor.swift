import Cocoa
import Foundation

protocol TriggerProcessorDelegate: AnyObject {
    /// Requests text replacement
    func performTextReplacement(
        snippet: SnippetEntry, deleteLength: Int, triggerMethod: String)
}

/// Handles trigger detection logic (Suffixes, Trigger Keys) and delegates execution.
class TriggerProcessor {
    static let shared = TriggerProcessor()

    weak var delegate: TriggerProcessorDelegate?

    private let abbreviationMatcher: AbbreviationMatcher

    // ✅ DI: Allow dependency injection for testing
    init(abbreviationMatcher: AbbreviationMatcher = AbbreviationMatcher()) {
        self.abbreviationMatcher = abbreviationMatcher
    }

    // MARK: - Public API

    /// Processes an explicit trigger key (e.g., from shortcut resolution)
    /// Returns true if a trigger action was executed (snippet expanded).
    func processTriggerKey(_ triggerKey: EnhancedTriggerKey, buffer: String) -> Bool {
        // Match Preparation: Get the 'clean' buffer (without the trigger)
        let triggerSeq = triggerKey.keySequence
        let triggerChar = triggerKey.displayCharacter
        let cleanBuffer: String

        if !triggerChar.isEmpty && buffer.hasSuffix(triggerChar) {
            cleanBuffer = String(buffer.dropLast(triggerChar.count))
        } else if !triggerSeq.isEmpty && buffer.hasSuffix(triggerSeq) {
            cleanBuffer = String(buffer.dropLast(triggerSeq.count))
        } else {
            cleanBuffer = buffer
        }

        let checkBufferForCollision = cleanBuffer + (triggerChar.isEmpty ? triggerSeq : triggerChar)

        if abbreviationMatcher.hasLongerMatches(for: checkBufferForCollision) {
            logI(
                "⚡️ [Issue479] Longer match found for '\(checkBufferForCollision)'. Delaying trigger via Collision Logic."
            )
            return false
        }

        let allRules = RuleManager.shared.getEffectiveRules()
        var bestCandidate: (candidate: AbbreviationMatcher.MatchCandidate, baseLength: Int)? = nil

        // Issue 621_3: O(N) 루프 밖에서 공통 연산 미리 계산 (최적화)
        let settings = SettingsManager.shared.load()
        let defaultSymbol = settings.defaultSymbol
        let unwrappedDefault = EnhancedTriggerKey.unwrapBraces(defaultSymbol)
        let unwrappedTriggerChar = EnhancedTriggerKey.unwrapBraces(triggerKey.displayCharacter)
        let unwrappedSeq = EnhancedTriggerKey.unwrapBraces(triggerKey.keySequence)
        let baseBias = settings.triggerBias
        let auxBias = AppSettingManager.shared.tuning.triggerBiasAux

        let isGlobalTrigger =
            (triggerKey.displayCharacter == defaultSymbol)
            || (unwrappedTriggerChar == unwrappedDefault)
            || PSKeyManager.shared.areKeysEquivalent(triggerKey.displayCharacter, defaultSymbol)

        for rule in allRules {

            let normalizedRuleSuffix = EnhancedTriggerKey.unwrapBraces(rule.suffix)

            let isSuffixMatch =
                (!rule.suffix.isEmpty
                    && (normalizedRuleSuffix.contains(triggerKey.displayCharacter)
                        || normalizedRuleSuffix == unwrappedSeq
                        || normalizedRuleSuffix == triggerKey.id
                        || PSKeyManager.shared.areKeysEquivalent(
                            normalizedRuleSuffix, triggerKey.displayCharacter)
                        || PSKeyManager.shared.areKeysEquivalent(
                            normalizedRuleSuffix, unwrappedSeq)))

            let isSuffixTrigger = isSuffixMatch || (rule.suffix.isEmpty && isGlobalTrigger)

            if isSuffixTrigger {
                let effectiveRuleSuffix = PSKeyManager.shared.resolveEffectiveKey(rule.suffix)
                let searchBuffer = cleanBuffer + effectiveRuleSuffix

                if let match = abbreviationMatcher.findBestMatch(in: searchBuffer, rule: rule) {
                    let matchedString = String(searchBuffer.suffix(match.matchedLength))

                    // ✅ DeleteLengthManager now handles all length logic (Issue 559 Refactor)
                    // Pass the trigger key context so Manager can decide visual length & compensation.

                    let calcResult = DeleteLengthManager.shared.calculate(
                        snippet: match.snippet,
                        matchedLength: match.matchedLength,
                        triggeredByKey: true,
                        rule: rule,
                        effectiveSuffix: triggerKey.displayCharacter,
                        triggerBias: baseBias,
                        auxBias: auxBias,
                        isKeyBuffered: false,
                        matchedString: matchedString,
                        isImplicitTrigger: true,
                        // triggerKeyLabel is essential for Manager to calculate visual length
                        triggerKeyLabel: triggerKey.displayCharacter.isEmpty
                            ? triggerKey.keySequence : triggerKey.displayCharacter,
                        hasLongerMatches: false  // Explicit key trigger usually doesn't have "pending" longer matches in this context
                    )

                    let adjustedDeleteLength = calcResult.deleteLength
                    let baseLength = match.matchedLength - effectiveRuleSuffix.count

                    logD(
                        "⚡️ [TriggerProcessor] Rule '\(rule.name)' matched: '\(match.snippet.abbreviation)' (MatchLen: \(match.matchedLength), BaseLen: \(baseLength), Suffix: '\(effectiveRuleSuffix)')"
                    )

                    // Determine Tier (Priority)
                    let tierPriority: AbbreviationMatcher.MatchPriority
                    if !rule.prefix.isEmpty && !rule.suffix.isEmpty {
                        tierPriority = .combinedShortcut  // Tier 1
                    } else {
                        tierPriority = .suffixShortcut  // Tier 3
                    }

                    // Determine Component Priority
                    // For trigger key, the effective suffix IS the/part of trigger key
                    let compPriority = SingleShortcutMapper.shared.getComponentPriority(
                        for: rule.suffix)

                    // Construct Candidate with Priority
                    let candidate = AbbreviationMatcher.MatchCandidate(
                        snippet: match.snippet,
                        deleteLength: adjustedDeleteLength,
                        triggerMethod: "key_suffix",
                        priority: tierPriority,
                        componentPriority: compPriority,
                        description: "BaseLen: \(baseLength)"
                    )

                    // Compare with Best Candidate
                    if bestCandidate == nil {
                        bestCandidate = (candidate, baseLength)
                    } else if let (bestC, bestBase) = bestCandidate {
                        // Priority Fix (Greedy - GLOBAL PRIORITY)
                        // 1. Base Length (Greedy) - Always prefer longer match for explicit trigger
                        if baseLength > bestBase {
                            bestCandidate = (candidate, baseLength)
                        } else if baseLength == bestBase {
                            // 2. Tier
                            if candidate.priority < bestC.priority {
                                bestCandidate = (candidate, baseLength)
                            } else if candidate.priority == bestC.priority {
                                // 3. Component Priority
                                if candidate.componentPriority < bestC.componentPriority {
                                    bestCandidate = (candidate, baseLength)
                                }
                            }
                        }
                    }
                }
            }
        }

        if let winner = bestCandidate?.candidate {
            delegate?.performTextReplacement(
                snippet: winner.snippet,
                deleteLength: winner.deleteLength,
                triggerMethod: winner.triggerMethod
            )
            return true
        }

        return false
    }

    /// Checks for suffix matches in the current buffer (General Loop)
    // ✅ [Issue Trigger Action] Enum to differentiate trigger behavior
    enum TriggerAction {
        case none
        case consumed  // Trigger key is consumed (Standard, e.g. Suffix)
        case matchPassthrough  // Trigger key is typed (Text match, e.g. Prefix-Only)
    }

    /// Checks if the current buffer matches any suffix rules or patterns.
    /// - Returns: TriggerAction indicating if a match was found and how to handle the key.
    /// - Parameter rules: Optional rules to verify against (Dependency Injection for Testing). Defaults to RuleManager.shared.getEffectiveRules().
    func checkForSuffixMatches(
        buffer: String, keyInfo: KeyEventInfo, rules: [RuleManager.CollectionRule]? = nil
    ) -> TriggerAction {
        let activeRules = rules ?? RuleManager.shared.getEffectiveRules()
        let keySpec = keyInfo.normalizedKeySpec()

        var bestCandidate: AbbreviationMatcher.MatchCandidate? = nil
        var bestAction: TriggerAction = .none

        let isOptionWrapper = keyInfo.modifiers.contains(.option)

        // Issue 621_3: O(N) 루프 밖에서 공통 연산 및 반복 연산 캐싱 (최적화)
        let settings = SettingsManager.shared.load()
        let baseBias = settings.triggerBias
        let auxBias = AppSettingManager.shared.tuning.triggerBiasAux

        let targetPrefix = keySpec.hasPrefix("{") ? keySpec : "{\(keySpec)}"
        let unwrappedKeySpec = SingleShortcutMapper.shared.unwrap(keySpec)
        let triggerAsSuffix = KeyRenderingManager.shared.sanitizeInputCharacter(keySpec)
        let triggerKeyLabel = SingleShortcutMapper.shared.getKeyLabel(for: keyInfo.keyCode)

        // Rule.suffix 값에 대한 resolveEffectiveKey 결과를 캐싱하여 O(N) 루프 내 중복 연산 제거
        var effectiveSuffixCache: [String: String] = [:]
        var unwrappedRuleSuffixCache: [String: String] = [:]

        for rule in activeRules {
            // 1. Prefix Shortcuts (Tier 2 or Tier 1 if combined)
            // Note: Prefix Shortcuts are usually treated here if they don't have a suffix.
            // If they HAVE a suffix, they are caught by the Suffix Logic below (Tier 1).

            // Check for Tier 2: Prefix Only (Rule has Prefix, No Suffix)
            // Or just check if this key matches the prefix.

            if rule.prefix.hasPrefix("{") && rule.prefix.hasSuffix("}")
                && rule.prefix == targetPrefix
            {
                if let candidate = abbreviationMatcher.findPrefixShortcutMatch(
                    buffer: buffer, rule: rule)
                {
                    // Candidate already has priority set by AbbreviationMatcher (likely .prefixShortcut)
                    // We need to verify/adjust if it's actually Tier 1 (if rule has suffix too? but we are triggered by Prefix key...)
                    // If triggered by Prefix Key, it's a Prefix Trigger.
                    // If rule has suffix, and we trigger by prefix, is it valid?
                    // Usually Combined Shortcut requires BOTH. If we type Prefix, we haven't typed Suffix yet.
                    // So it's effectively a "Prefix Start" match?
                    // No, findPrefixShortcutMatch checks for "Partial Match" or "Full Match"?
                    // It checks if snippet matches `prefix + keyword`.
                    // If rule has suffix, we might need suffix.
                    // But `findPrefixShortcutMatch` is for "Prefix AS Trigger".

                    if bestCandidate == nil {
                        bestCandidate = candidate
                        bestAction = .consumed
                    } else if let bestC = bestCandidate {
                        // Issue652: 강제 언래핑(!.) 대신 if let 바인딩 사용
                        // Compare Priority
                        if candidate.priority < bestC.priority {
                            bestCandidate = candidate
                            bestAction = .consumed
                        } else if candidate.priority == bestC.priority {
                            if candidate.componentPriority < bestC.componentPriority {
                                bestCandidate = candidate
                                bestAction = .consumed
                            } else if candidate.componentPriority == bestC.componentPriority {
                                if candidate.deleteLength > bestC.deleteLength {
                                    bestCandidate = candidate
                                    bestAction = .consumed
                                }
                            }
                        }
                    }
                }
            }

            // 2. Standard Suffix / Combined Trigger
            // 캐시를 확인하고 없으면 계산 후 저장
            let effectiveSuffix: String
            if let cached = effectiveSuffixCache[rule.suffix] {
                effectiveSuffix = cached
            } else {
                effectiveSuffix = PSKeyManager.shared.resolveEffectiveKey(rule.suffix)
                effectiveSuffixCache[rule.suffix] = effectiveSuffix
            }
            let isSuffixMatch = !rule.suffix.isEmpty && buffer.hasSuffix(effectiveSuffix)

            let unwrappedRuleSuffix: String
            if let cached = unwrappedRuleSuffixCache[rule.suffix] {
                unwrappedRuleSuffix = cached
            } else {
                unwrappedRuleSuffix = SingleShortcutMapper.shared.unwrap(rule.suffix)
                unwrappedRuleSuffixCache[rule.suffix] = unwrappedRuleSuffix
            }
            let isTokenMatch = !rule.suffix.isEmpty && (unwrappedRuleSuffix == unwrappedKeySpec)

            let isTriggerMatch =
                !rule.suffix.isEmpty
                && (PSKeyManager.shared.areKeysEquivalent(effectiveSuffix, triggerAsSuffix)
                    || isTokenMatch)
            let isPrefixOnlyRule = rule.suffix.isEmpty && !rule.prefix.isEmpty

            if isSuffixMatch || isTriggerMatch || isPrefixOnlyRule {
                var searchBuffer = buffer

                if !isSuffixMatch && isTriggerMatch {
                    if !isTokenMatch {
                        // Issue718: trigger 문자를 소비(strip)한 후 effective suffix 추가
                        // processTriggerKey의 cleanBuffer 패턴과 동일하게 정렬
                        // 방지: ",,apple," + "{keypad_comma}" → ",,apple,{keypad_comma}" (오탐)
                        // 정상: ",,apple," - "," + "{keypad_comma}" → ",,apple{keypad_comma}"
                        if !triggerAsSuffix.isEmpty && searchBuffer.hasSuffix(triggerAsSuffix) {
                            searchBuffer = String(searchBuffer.dropLast(triggerAsSuffix.count))
                        }
                        searchBuffer += effectiveSuffix
                    }
                }

                if let match = abbreviationMatcher.findBestMatch(in: searchBuffer, rule: rule) {
                    let triggerBias = baseBias + (rule.triggerBias ?? 0)
                    let matchedString = String(searchBuffer.suffix(match.matchedLength))

                    logD(
                        "⚡️ [TriggerProcessor] Matching found: '\(match.snippet.abbreviation)' in '\(searchBuffer)' (MatchedLen: \(match.matchedLength))"
                    )

                    // ✅ Simplified Logic: All validation moved to DeleteLengthManager (Issue 503 Refactor)
                    // We just pass the context: triggerKeyLabel and hasLongerMatches.

                    let hasLonger = abbreviationMatcher.hasLongerMatches(
                        for: match.snippet.abbreviation)

                    let calcResult = DeleteLengthManager.shared.calculate(
                        snippet: match.snippet,
                        matchedLength: match.matchedLength,
                        triggeredByKey: true,
                        rule: rule,
                        effectiveSuffix: effectiveSuffix,
                        triggerBias: triggerBias,
                        auxBias: auxBias,
                        isKeyBuffered: false,  // Ignored by updated Manager logic
                        matchedString: matchedString,
                        isImplicitTrigger: false,
                        triggerKeyLabel: triggerKeyLabel,
                        hasLongerMatches: hasLonger,
                        isOptionKey: isOptionWrapper
                    )

                    let deleteLen = calcResult.deleteLength
                    logD(
                        "⚡️ [TriggerProcessor] Calculated deleteLen: \(deleteLen) (Plan: \(calcResult.strategy))"
                    )

                    // Collision logic is now inside DeleteLengthManager. No manual adjustment needed here.
                    if hasLonger {
                        logD(
                            "⚡️ [TriggerProcessor] Longer match found. DeleteLengthManager handled the adjustment."
                        )
                    }

                    // Determine Tier (Priority)
                    // Tier 1: Combined (Prefix + Suffix)
                    // Tier 3: Suffix Only
                    // (Tier 2 is Prefix Shortcut, handled above)

                    let tierPriority: AbbreviationMatcher.MatchPriority
                    if !rule.prefix.isEmpty && !rule.suffix.isEmpty {
                        tierPriority = .combinedShortcut  // Tier 1
                    } else {
                        tierPriority = .suffixShortcut  // Tier 3
                    }

                    // Determine Component Priority
                    let compPriority = SingleShortcutMapper.shared.getComponentPriority(
                        for: rule.suffix)

                    // ✅ Issue 698: TextReplacementCoordinator의 -1 보정 로직이 제거되었으므로, 해당 보정 상쇄용으로 있던 불필요한 사전 보정 코드 삭제.
                    let finalDeleteLen = max(0, deleteLen)

                    let candidate = AbbreviationMatcher.MatchCandidate(
                        snippet: match.snippet,
                        deleteLength: finalDeleteLen,
                        triggerMethod: "key_trigger",
                        priority: tierPriority,
                        componentPriority: compPriority,
                        description: "deleteLength: \(finalDeleteLen)"
                    )
                    logD(
                        "⚡️ [TriggerProcessor] Candidate '\(match.snippet.abbreviation)' -> finalDeleteLen: \(finalDeleteLen) (base: \(deleteLen))"
                    )

                    if bestCandidate == nil {
                        bestCandidate = candidate
                        bestAction = .consumed
                    } else if let bestC = bestCandidate {
                        // Issue652: 강제 언래핑(!.) 대신 if let 바인딩 사용
                        // Compare Priority (Issue 563 Fix)
                        // 1. Base Length (Greedy) - GLOBAL PRIORITY
                        // Always prefer longer matches for suffix triggers.
                        if candidate.deleteLength > bestC.deleteLength {
                            bestCandidate = candidate
                            bestAction = .consumed
                        } else if candidate.deleteLength == bestC.deleteLength {
                            // 2. Tier
                            if candidate.priority < bestC.priority {
                                bestCandidate = candidate
                                bestAction = .consumed
                            } else if candidate.priority == bestC.priority {
                                // 3. Component Priority
                                if candidate.componentPriority < bestC.componentPriority {
                                    bestCandidate = candidate
                                    bestAction = .consumed
                                }
                            }
                        }
                    }
                }
            }
        }

        if let winner = bestCandidate {
            // Sync Execution (No Async)
            delegate?.performTextReplacement(
                snippet: winner.snippet,
                deleteLength: winner.deleteLength,
                triggerMethod: winner.triggerMethod
            )
            return bestAction
        }

        return .none
    }
}
