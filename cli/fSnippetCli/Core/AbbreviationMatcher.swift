import Foundation

/// Abbreviation 매칭 및 스니펫 검색을 담당하는 클래스
class AbbreviationMatcher {

    private let snippetFileManager: SnippetFileManager
    private let snippetIndexManager = SnippetIndexManager.shared

    init(snippetFileManager: SnippetFileManager = .shared) {
        self.snippetFileManager = snippetFileManager
    }

    // MARK: - Types

    enum MatchPriority: Int, Comparable {
        case combinedShortcut = 1  // Highest (Prefix + Suffix) - Tier 1
        case prefixShortcut = 2  // High (Prefix Only) - Tier 2
        case suffixShortcut = 3  // Normal (Suffix Only) - Tier 3

        static func < (lhs: MatchPriority, rhs: MatchPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    struct MatchCandidate {
        let snippet: SnippetEntry
        let deleteLength: Int
        let triggerMethod: String
        let priority: MatchPriority
        let componentPriority: SingleShortcutMapper.ComponentPriority  // Issue 562: Component Priority
        let description: String
    }

    // MARK: - Public Methods

    /// abbreviation 후보가 실제 snippet과 매칭되는지 확인
    func validateCandidates(_ candidates: [String]) -> SnippetEntry? {
        var matchedSnippets: [SnippetEntry] = []

        // 모든 후보에 대해 검색 수행
        for candidate in candidates {
            let searchResults = SnippetIndexManager.shared.search(term: candidate, maxResults: 10)
            matchedSnippets.append(contentsOf: searchResults)
        }

        // 중복 제거 및 관련성 순으로 정렬 (Issue 526: 점수가 같으면 긴 약어 우선)
        let uniqueSnippets = Array(Set(matchedSnippets)).sorted { first, second in
            let firstScore = candidates.compactMap { first.relevanceScore(for: $0) }.max() ?? 0
            let secondScore = candidates.compactMap { second.relevanceScore(for: $0) }.max() ?? 0

            if abs(firstScore - secondScore) < 0.001 {
                return first.abbreviation.count > second.abbreviation.count
            }
            return firstScore > secondScore
        }

        guard !uniqueSnippets.isEmpty else {
            logD("🧩 매칭되는 스니펫 없음: \(candidates)")
            return nil
        }

        // 완전 일치가 있는 경우만 처리
        if let exactMatch = uniqueSnippets.first(where: { snippet in
            candidates.contains(snippet.abbreviation)
        }) {
            logV("🧩 완전 일치 스니펫 발견: \(exactMatch.abbreviation)")
            return exactMatch
        }

        // 완전 일치가 없는 경우 확장하지 않음 (유사 매칭 방지)
        logD("🧩 완전 일치 스니펫 없음 - 유사 매칭 방지")
        return nil
    }

    /// 검색어로 스니펫 후보들 찾기
    func findSnippetCandidates(searchTerm: String) -> [SnippetEntry] {
        guard !searchTerm.isEmpty else {
            // 검색어가 비어있으면 전체 목록 반환
            return getAllSnippets()
        }

        logV("🧩 스니펫 후보 검색: '\(searchTerm)'")

        // SnippetFileManager에서 우선 확인 (더 안정적)
        // SnippetFileManager에서 우선 확인 (더 안정적)
        let fileManagerMap = snippetFileManager.snippetMap
        logD("🧩 [AbbreviationMatcher] fileManagerMap count: \(fileManagerMap.count)")

        if !fileManagerMap.isEmpty {
            let allCandidates = fileManagerMap.flatMap { (key, paths) in
                paths.map { path in createSnippetEntry(from: key, path: path) }
            }
            logV("🧩 [AbbreviationMatcher] Using filterCandidates via FileManager")
            return filterCandidates(allCandidates, with: searchTerm)
        } else {
            // 백업: SnippetIndexManager 시도
            logW(
                "🧩 [AbbreviationMatcher] Map empty -> Fallback to SnippetIndexManager (Abbreviation Scope)"
            )
            return SnippetIndexManager.shared.search(
                term: searchTerm, scope: .abbreviation, maxResults: 100)
        }
    }

    /// 모든 스니펫 목록 가져오기
    func getAllSnippets() -> [SnippetEntry] {
        // SnippetFileManager에서 우선 확인
        let fileManagerMap = snippetFileManager.snippetMap

        if !fileManagerMap.isEmpty {
            return fileManagerMap.flatMap { (key, paths) in
                paths.map { path in createSnippetEntry(from: key, path: path) }
            }
        } else {
            // 백업: SnippetIndexManager 시도
            return SnippetIndexManager.shared.search(term: "", maxResults: 100)
        }
    }

    /// Issue33: 특정 abbreviation으로 스니펫 찾기
    /// Issue 452_3: 선택적 폴더 필터로 중복 지원
    func findSnippetByAbbreviation(_ abbreviation: String, folderFilter: String? = nil)
        -> SnippetEntry?
    {
        let candidates = findSnippetsByAbbreviation(abbreviation)

        if let folder = folderFilter {
            if let match = candidates.first(where: { $0.folderName == folder }) {
                logV(
                    "🧩 [AbbreviationMatcher] 스니펫 발견 (Scoped): '\(abbreviation)' -> '\(match.filePath.lastPathComponent)'"
                )
                return match
            }
            logV(
                "🧩 [AbbreviationMatcher] Key found but folder mismatch: '\(abbreviation)' (Wanted: \(folder))"
            )
            return nil
        }

        if let first = candidates.first {
            logV(
                "🧩 [AbbreviationMatcher] 스니펫 발견: '\(abbreviation)' -> '\(first.filePath.lastPathComponent)'"
            )
            return first
        }

        logD("🧩 [AbbreviationMatcher] 스니펫 찾을 수 없음: '\(abbreviation)'")
        return nil
    }

    /// Issue 456: 고급 우선순위 지정을 위해 키에 대한 모든 후보 반환
    func findSnippetsByAbbreviation(_ abbreviation: String) -> [SnippetEntry] {
        let startTime = Date()
        defer {
            logPerf(
                "🧩 Abbreviation Search (All): '\(abbreviation)'",
                duration: Date().timeIntervalSince(startTime))
        }

        // SnippetFileManager에서 직접 확인
        let fileManagerMap = snippetFileManager.snippetMap

        if let paths = fileManagerMap[abbreviation] {
            return paths.map { createSnippetEntry(from: abbreviation, path: $0) }
        }

        return []
    }

    /// 후보군 필터링
    func filterCandidates(_ candidates: [SnippetEntry], with searchTerm: String) -> [SnippetEntry] {
        if searchTerm.isEmpty {
            return candidates
        }

        let settings = SettingsManager.shared.load()
        let triggerKey = settings.defaultSymbol

        logD("🧩 후보 필터링 시작: 검색어 '\(searchTerm)', 전체 후보 \(candidates.count)개")

        let filtered = candidates.filter { candidate in
            // abbreviation에서 트리거 키를 제거한 부분이 검색어로 시작하는지 확인
            let abbreviationWithoutTrigger =
                candidate.abbreviation.hasSuffix(triggerKey)
                ? String(candidate.abbreviation.dropLast(triggerKey.count))
                : candidate.abbreviation

            let matches = abbreviationWithoutTrigger.lowercased().hasPrefix(searchTerm.lowercased())

            if matches {
                logV("🧩 매칭: '\(candidate.abbreviation)' <- '\(searchTerm)'")
            }

            return matches
        }

        logD("🧩 필터링 완료: \(filtered.count)개 결과")
        return filtered
    }

    /// Issue Fix: 지정된 약어에 대해 더 긴 매칭이 있는지 확인
    /// "충돌 시 지연 트리거(Delayed Trigger on Collision)" 로직 구현에 사용됨.
    func hasLongerMatches(for abbreviation: String) -> Bool {
        let fileManagerMap = snippetFileManager.snippetMap

        // 맵의 키 중 약어로 시작하지만 더 긴 것이 있는지 확인
        // 최적화: Trie를 사용하거나 맵 크기가 관리 가능하므로(수백/수천) 반복할 수 있음
        // 일반적으로 2000개 미만의 스니펫이므로 반복은 허용 가능(약 0.1ms)
        // 엄격한 필터링: 약어로 시작하고 길이가 더 긴 경우

        // 참고: 여기서 abbreviation은 전체 키(예: ",c")입니다.
        // ",cat", ",could" 등을 찾습니다.

        // 빠른 종료: 비어있는 경우
        if abbreviation.isEmpty { return false }

        // 대소문자 구분 체크? 트리거는 주로 대소문자를 구분합니다(매처에 따라 다름).
        // AbbreviationMatcher는 주로 정확한 키 조회를 사용합니다.
        // 접두사에 대해 정확한 일치가 필요하다고 가정합시다.

        // 성능: 파일 관리자 맵(메모리) 우선 확인
        for key in fileManagerMap.keys {
            if key.count > abbreviation.count && key.hasPrefix(abbreviation) {
                logV("🧩 [AbbreviationMatcher] Found longer match for '\(abbreviation)': '\(key)'")
                return true
            }
        }

        return false
    }

    // MARK: - Private Methods

    /// 키와 경로로부터 SnippetEntry 생성
    func createSnippetEntry(from key: String, path: String) -> SnippetEntry {
        let url = URL(fileURLWithPath: path)
        return SnippetEntry(
            id: key,
            abbreviation: key,
            filePath: url,
            folderName: url.deletingLastPathComponent().lastPathComponent,
            fileName: url.lastPathComponent,
            description: nil,

            // ✅ Issue219: Correctly parse snippet description here (Fix for inconsistent display)
            snippetDescription: {
                let baseFileName = url.deletingPathExtension().lastPathComponent
                if baseFileName.contains("===") {
                    let parts = baseFileName.components(separatedBy: "===")
                    if parts.count > 1 {
                        let desc = SnippetItem.decodeKeyword(parts[1])
                        return desc.hasSuffix("_") ? String(desc.dropLast()) : desc
                    }
                }
                return ""
            }(),

            content: "",
            tags: [],
            fileSize: 0,
            modificationDate: Date(),
            isActive: true
        )
    }

    // MARK: - Advanced Matching (Refactored Logic)

    /// 버퍼와 규칙을 기반으로 최적의 스니펫 매칭을 찾습니다. (역방향 Greedy 검색 포함)
    /// - Parameters:
    ///   - buffer: 현재 입력 버퍼 (Suffix가 포함되어 있을 수 있음)
    ///   - rule: 적용할 규칙 (Prefix/Suffix)
    /// - Returns: (스니펫, 매칭된 길이) 튜플
    func findBestMatch(in buffer: String, rule: RuleManager.CollectionRule) -> (
        snippet: SnippetEntry, matchedLength: Int
    )? {

        // 1. Suffix 처리 (Effective Suffix 계산)
        // Issue 478: PSKeyManager를 사용하여 유효 키 해결 (중앙 집중식 로직)
        let rawSuffix = rule.suffix
        let effectiveSuffix = PSKeyManager.shared.resolveEffectiveKey(rawSuffix)

        // Suffix가 있는 경우 버퍼에서 제거하고 검색 범위 설정
        // Issue 475: effectiveSuffix count 사용
        // 참고: 여기서 전달된 buffer는 Suffix에 의해 트리거된 경우 Suffix를 포함할 수 있음.
        // 호출자가 Suffix 존재 여부를 확인하거나 버퍼를 그대로 전달한다고 가정함.
        // 규칙에 Suffix가 있고, 그것에 의해 트리거되었다면 버퍼는 Suffix로 끝남.

        let bufferWithoutSuffix: String
        if !effectiveSuffix.isEmpty && buffer.hasSuffix(effectiveSuffix) {
            bufferWithoutSuffix = String(buffer.dropLast(effectiveSuffix.count))
        } else {
            bufferWithoutSuffix = buffer
            // Suffix가 필수인데 없는 경우 실패해야 하는가?
            // "Suffix 트리거에 의한 검색"인지 단순히 "역방향 검색"인지에 따라 다름.
            // 규칙이 Suffix를 암시하는데 누락되었다면 매칭하지 말아야 할까?
            // 하지만 `handleSuffixBasedExpansion`의 기존 로직은 맹목적으로 `bufferWithoutSuffix`를 계산했나?
            // 아니오, count를 사용하여 `dropLast` 했습니다. 따라서 Suffix가 끝에 있다고 가정했습니다.
        }

        // Issue 502 (Symbol/Spacing Failure)를 위해 Guard 로직 수정됨
        // effectiveSuffix가 존재하지만 버퍼가 그것으로 끝나지 않는 경우,
        // Suffix 자체가 약어의 일부인 경우(예: `,,`가 `,,` 매칭) 여전히 매칭을 시도하고 싶을 수 있음.
        // 하지만 표준 로직은 Suffix가 제거되기를 기대함.
        // Suffix가 포함되어 있거나 포함되지 않은 경우를 처리하기 위해 아래의 역방향 Greedy 검색에 의존합시다.

        let bufferToSearch = bufferWithoutSuffix.isEmpty ? buffer : bufferWithoutSuffix
        guard !bufferToSearch.isEmpty else { return nil }

        // 2. 역방향 Greedy 검색
        let chars = Array(bufferToSearch)
        let atomicRanges = getAtomicRanges(in: chars)

        for i in (1...bufferToSearch.count).reversed() {
            // 이 하위 문자열이 원자적 토큰의 중간에서 시작하는지 확인
            let startIndex = bufferToSearch.count - i
            if isInsideAtomicRange(startIndex, ranges: atomicRanges) {
                logV(
                    "🧩 [findBestMatch] Skipping atomic fragment at index \(startIndex) (Length: \(i))"
                )
                continue
            }

            let substring = String(bufferToSearch.suffix(i))
            logV("🧩 [findBestMatch] Testing substring: '\(substring)' (Rule: '\(rule.name)')")

            // 3. Prefix 검사
            var keyword = substring
            var matchedPrefix = rule.prefix  // 기본값

            if !rule.prefix.isEmpty {
                // Issue2: 접두사 매칭 시 대소문자 무시 (예: Docker -> D, d 모두 허용)
                if substring.lowercased().hasPrefix(rule.prefix.lowercased()) {
                    // Typed case 유지: 버퍼에서 실제 입력된 접두사 부분을 추출 (Issue 530)
                    matchedPrefix = String(substring.prefix(rule.prefix.count))
                    keyword = String(substring.dropFirst(rule.prefix.count))
                } else if i > 0 {
                    // prefix가 필요한데 없으면 이 길이는 스킵 (더 짧은 매칭 시도)
                    continue
                }
            }

            // 4. 검색 시도 (2단계: Suffix 포함 vs Suffix 제외)

            logV(
                "🧩 [findBestMatch] Searching... Prefix='\(rule.prefix)', Keyword='\(keyword)', Suffix='\(rule.suffix)' (HasSuffix: \(buffer.hasSuffix(effectiveSuffix)))"
            )

            // 4-1) Suffix 포함한 전체 Key로 검색 (예: "h{end}" or "h,,")
            // 참고: snippetMap은 Suffix가 포함된 키를 저장함 (예: "h{end}").
            let testAbbreviationWithSuffix = "\(matchedPrefix)\(keyword)\(rule.suffix)"

            let matchesWithSuffix = findSnippetsByAbbreviation(testAbbreviationWithSuffix)
            if let match = matchesWithSuffix.first(where: {
                $0.folderName.caseInsensitiveCompare(rule.name) == .orderedSame
            }) {
                logV(
                    "🧩 [AbbreviationMatcher] Match Found (With Suffix): '\(testAbbreviationWithSuffix)'"
                )
                // 매칭 길이 = (Prefix+Keyword) Length + EffectiveSuffix Length
                // (시각적 길이 계산은 별도이며, 여기서는 버퍼 내의 일반적인 매칭 길이를 반환)
                let totalLen =
                    substring.count
                    + (buffer.hasSuffix(effectiveSuffix) ? effectiveSuffix.count : 0)
                return (match, totalLen)
            }

            // 4-2) Suffix 제거한 Key로 검색 (예: "h")
            // 일부 스니펫은 Suffix 없이 저장될 수 있음? (예: _symbol_space)
            let testAbbreviationWithoutSuffix = "\(matchedPrefix)\(keyword)"

            let matchesWithoutSuffix = findSnippetsByAbbreviation(testAbbreviationWithoutSuffix)
            if let match = matchesWithoutSuffix.first(where: {
                $0.folderName.caseInsensitiveCompare(rule.name) == .orderedSame
            }) {
                logD(
                    "🧩 [AbbreviationMatcher] Match Found (Without Suffix): '\(testAbbreviationWithoutSuffix)'"
                )
                let totalLen =
                    substring.count
                    + (buffer.hasSuffix(effectiveSuffix) ? effectiveSuffix.count : 0)
                return (match, totalLen)
            }
        }

        return nil
    }

    // MARK: - Shortcut & Rule Matching (Moved from KeyEventMonitor)

    /// Issue 322: Prefix Shortcut을 이용한 Greedy Expansion
    func findPrefixShortcutMatch(buffer: String, rule: RuleManager.CollectionRule)
        -> MatchCandidate?
    {
        logD("🧩 [PrefixShortcut] Expansion attempt: buffer='\(buffer)', folder='\(rule.name)'")

        guard !buffer.isEmpty else { return nil }

        // 통합 접미사 로직 (Legacy suffixShortcut이 suffix로 병합됨)
        let rawSuffix = rule.suffix
        let textSuffix = PSKeyManager.shared.sanitizeSuffix(rawSuffix)

        // Greedy Search (Reverse)
        for i in (1...buffer.count).reversed() {
            let candidate = String(buffer.suffix(i))
            let lookupKey = rule.prefix + candidate + textSuffix

            if let path = snippetFileManager.findSnippetPath(in: rule.name, abbreviation: lookupKey)
            {
                logI(
                    "🧩 [PrefixShortcut] Match found! '\(lookupKey)' -> '\((path as NSString).lastPathComponent)'"
                )

                let snippet = createSnippetEntry(from: lookupKey, path: path)
                let settings = SettingsManager.shared.load()
                let userBias = (rule.triggerBias ?? settings.triggerBias)
                let auxBias = AppSettingManager.shared.tuning.triggerBiasAux
                let triggerBias = userBias

                logD(
                    "🧩 🔹 [Deletion Formula] (PrefixShortcut) = max(0, (Base:\(candidate.count)) + (Visual:0) + (User Bias:\(userBias)) + (Aux Bias:\(auxBias)))"
                )
                // ✅ Issue 503 refactor: Use DeleteLengthManager for SSOT
                let calcResult = DeleteLengthManager.shared.calculate(
                    snippet: snippet,
                    matchedLength: candidate.count,
                    triggeredByKey: true,  // It is triggered by a key (Prefix Shortcut)
                    rule: rule,
                    effectiveSuffix: "",
                    triggerBias: triggerBias,
                    auxBias: auxBias,
                    triggerKeyLabel: rule.prefix,  // The trigger is the prefix key
                    hasLongerMatches: false
                )

                let finalDeleteLength = calcResult.deleteLength

                return MatchCandidate(
                    snippet: snippet,
                    deleteLength: finalDeleteLength,
                    triggerMethod: "prefix_shortcut",
                    priority: .prefixShortcut,
                    componentPriority: SingleShortcutMapper.shared.getComponentPriority(
                        for: rule.prefix),  // Priority 2: Component
                    description: "PrefixShortcut: \(candidate)"
                )
            } else {
                // ✅ Prefix Shortcut에 대한 Legacy Fallback 제거됨 (Issue 486)
                // prefixShortcut이 이제 rule.prefix로 병합되었으므로, 위의 기본 검색에서 처리됨.
            }
        }
        logD("🧩 [PrefixShortcut] No match for buffer='\(buffer)' in folder='\(rule.name)'")
        return nil
    }

    /// Issue278: Suffix Shortcut으로 인한 확장 처리 (Refactored to return Candidate)
    func findSuffixShortcutMatch(buffer: String, rule: RuleManager.CollectionRule)
        -> MatchCandidate?
    {
        guard !buffer.isEmpty else { return nil }

        // 역방향 검색 (Greedy)
        for i in (1...buffer.count).reversed() {
            let substring = String(buffer.suffix(i))

            // Prefix 체크
            if !rule.prefix.isEmpty {
                if substring.prefix(rule.prefix.count).localizedCaseInsensitiveCompare(rule.prefix)
                    != .orderedSame
                {
                    continue
                }
            }

            let suffixToAdd = (rule.suffix == " ") ? "" : rule.suffix
            let abbreviation = substring + suffixToAdd

            if let path = snippetFileManager.findSnippetPath(
                in: rule.name, abbreviation: abbreviation)
            {
                let snippet = createSnippetEntry(from: abbreviation, path: path)

                let settings = SettingsManager.shared.load()
                let userBias = (rule.triggerBias ?? settings.triggerBias)
                let auxBias = AppSettingManager.shared.tuning.triggerBiasAux
                let triggerBias = userBias
                // ✅ Issue 503 refactor: Use DeleteLengthManager for SSOT
                let calcResult = DeleteLengthManager.shared.calculate(
                    snippet: snippet,
                    matchedLength: abbreviation.count,
                    triggeredByKey: true,
                    rule: rule,
                    effectiveSuffix: suffixToAdd,
                    triggerBias: triggerBias,
                    auxBias: auxBias,
                    triggerKeyLabel: suffixToAdd,  // Pass suffix as trigger label
                    hasLongerMatches: false
                )
                let finalDeleteLength = calcResult.deleteLength

                logD("🧩 🔹 [Deletion Formula] (SuffixShortcut) = Delegating to DeleteLengthManager")

                return MatchCandidate(
                    snippet: snippet,
                    deleteLength: max(0, finalDeleteLength),
                    triggerMethod: "suffix_shortcut",
                    priority: .suffixShortcut,
                    componentPriority: SingleShortcutMapper.shared.getComponentPriority(
                        for: suffixToAdd),  // Priority 2
                    description: "SuffixShortcut: \(substring)"
                )
            }
        }
        return nil
    }

    // MARK: - 원자적 토큰 헬퍼 (Issue 521)

    /// 원자적 토큰 범위 식별 (예: {keypad_comma})
    private func getAtomicRanges(in chars: [Character]) -> [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        var start: Int? = nil

        for (index, char) in chars.enumerated() {
            if char == "{" {
                start = index  // 항상 최신 '{'를 취함
            } else if char == "}" {
                if let s = start {
                    ranges.append(s...index)
                    start = nil
                }
            }
        }
        return ranges
    }

    /// 인덱스가 원자적 범위 내에 있는지 확인 (시작점 제외)
    private func isInsideAtomicRange(_ index: Int, ranges: [ClosedRange<Int>]) -> Bool {
        for range in ranges {
            // 인덱스가 엄격하게 내부에 있으면 건너뜀 (start + 1 ... end)
            // 시작 인덱스는 유효함 (토큰의 시작)
            if index > range.lowerBound && index <= range.upperBound {
                return true
            }
        }
        return false
    }

}
