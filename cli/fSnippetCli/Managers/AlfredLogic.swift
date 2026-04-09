import Foundation

// MARK: - 스니펫 데이터 모델
struct AlfredSnippet {  // 통합된 모델 이름
    let uid: String
    let name: String
    let keyword: String
    let snippet: String
    let collection: String?
    let autoexpand: Bool
    let triggerKeyword: String?
}

// MARK: - 가져오기 구성 모델
struct ImportConfig {
    struct CollectionConfig {
        let name: String
        let prefix: String?
        let suffix: String?
        let triggerBias: Int?
        let folder: String?  // 선택적 폴더 재정의
        let ignore: Bool
    }

    var collections: [String: CollectionConfig] = [:]
    var triggerRemapping: [String: String] = [:]
    var rawHeader: String = ""
}

/// Alfred 로직 포팅 (from import_snippets.swift)
/// 터미널 스크립트의 로직을 앱 내부에서 그대로 사용하기 위함
class AlfredLogic {
    static let shared = AlfredLogic()
    private init() {}

    var importConfig: ImportConfig?

    // MARK: - 구성 로딩

    func loadImportConfig(path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            logW("🎩 ⚠️ [AlfredLogic] Import Config not found at \(path). Using defaults.")
            return
        }
        self.importConfig = parseImportConfig(content)
        logI(
            "🎩 [AlfredLogic] Import Config loaded: \(importConfig?.collections.count ?? 0) collections defined."
        )
    }

    func parseImportConfig(_ content: String) -> ImportConfig {
        var config = ImportConfig()
        let lines = content.components(separatedBy: .newlines)

        var currentCollection: [String: String] = [:]
        var isInCollections = false
        var isInTriggerRemapping = false
        var isInKarabinerMappings = false
        var headerLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed == "collections:" {
                isInCollections = true
                isInTriggerRemapping = false
                isInKarabinerMappings = false
                continue
            }

            if trimmed == "trigger_remapping:" || trimmed == "trigger_repapping:" {
                isInTriggerRemapping = true
                isInCollections = false
                isInKarabinerMappings = false
                continue
            }

            if trimmed == "karabiner_mappings:" {
                isInKarabinerMappings = true
                isInCollections = false
                isInTriggerRemapping = false
                continue
            }

            if !isInCollections && !isInTriggerRemapping && !isInKarabinerMappings {
                headerLines.append(line)
                continue
            }

            if isInKarabinerMappings {
                continue
            }

            if isInTriggerRemapping {
                if trimmed.hasPrefix("-") {
                    let mappingPart = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    let components = mappingPart.components(separatedBy: ":").map {
                        $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(
                            in: CharacterSet(charactersIn: "\"'"))
                    }
                    if components.count == 2 {
                        config.triggerRemapping[components[0]] = components[1]
                    }
                }
                continue
            }

            if isInCollections {
                if trimmed.hasPrefix("- name:") {
                    if let name = currentCollection["name"] {
                        if let collectionConfig = createCollectionConfig(from: currentCollection) {
                            config.collections[name] = collectionConfig
                        }
                    }
                    currentCollection = [:]
                    let value = extractValue(from: trimmed, key: "- name:")
                    currentCollection["name"] = value
                } else if trimmed.hasPrefix("prefix:") {
                    currentCollection["prefix"] = extractValue(from: trimmed, key: "prefix:")
                } else if trimmed.hasPrefix("suffix:") {
                    currentCollection["suffix"] = extractValue(from: trimmed, key: "suffix:")
                } else if trimmed.hasPrefix("trigger_bias:") {
                    currentCollection["trigger_bias"] = extractValue(
                        from: trimmed, key: "trigger_bias:")
                } else if trimmed.hasPrefix("ignore:") {
                    currentCollection["ignore"] = extractValue(from: trimmed, key: "ignore:")
                }
            }
        }

        config.rawHeader = headerLines.joined(separator: "\n").trimmingCharacters(
            in: .whitespacesAndNewlines)

        // 마지막 항목 저장
        if let name = currentCollection["name"] {
            if let collectionConfig = createCollectionConfig(from: currentCollection) {
                config.collections[name] = collectionConfig
            }
        }

        return config
    }

    private func extractValue(from line: String, key: String) -> String {
        guard let keyRange = line.range(of: key) else { return "" }
        let valuePart = String(line[keyRange.upperBound...])
        // 주석 제거
        let noComment = valuePart.components(separatedBy: "#")[0]

        var val = noComment.trimmingCharacters(in: .whitespaces)
        if (val.hasPrefix("\"") && val.hasSuffix("\""))
            || (val.hasPrefix("'") && val.hasSuffix("'"))
        {
            val = String(val.dropFirst().dropLast())
        }

        return val
    }

    private func createCollectionConfig(from dict: [String: String]) -> ImportConfig
        .CollectionConfig?
    {
        guard let name = dict["name"] else { return nil }
        let prefix = dict["prefix"]
        let suffix = dict["suffix"]
        let triggerBias = Int(dict["trigger_bias"] ?? "")
        let ignore = (dict["ignore"] == "true")

        return ImportConfig.CollectionConfig(
            name: name, prefix: prefix, suffix: suffix, triggerBias: triggerBias, folder: nil,
            ignore: ignore)
    }

    // MARK: - 유틸리티

    /// Issue77: 동적 플레이스홀더 변환 (single brace → double brace)
    func convertDynamicPlaceholders(_ content: String) -> String {
        var result = content
        let patterns = [
            "{clipboard}",
            "{clipboard:1}", "{clipboard:2}", "{clipboard:3}", "{clipboard:4}", "{clipboard:5}",
            "{clipboard:6}", "{clipboard:7}", "{clipboard:8}", "{clipboard:9}",
            "{clipboard:trim}", "{clipboard:uppercase}", "{clipboard:lowercase}",
            "{clipboard:capitals}",
            "{date}", "{time}", "{date:short}",
            "{cursor}", "{random:UUID}",
        ]

        for pattern in patterns {
            let doubled = pattern.replacingOccurrences(of: "{", with: "{{").replacingOccurrences(
                of: "}", with: "}}")
            result = result.replacingOccurrences(of: pattern, with: doubled)
        }

        // 정규식 패턴
        result = result.replacingOccurrences(
            of: #"\{isodate:([^}]+)\}"#, with: "{{isodate:$1}}", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\{snippet:([^}]+)\}"#, with: "{{snippet:$1}}", options: .regularExpression)

        return result
    }

    /// 파일명 안전화
    func sanitizeFilename(_ filename: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/:*?\"<>|\\")
        return
            filename
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ",", with: "{comma}")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 키워드 부분만 특수문자 변환
    private let SPECIAL_CHAR_MAPPINGS: [(String, String)] = [
        (".", "{period}"), (",", "{comma}"), (":", "{colon}"), (";", "{semicolon}"),
        ("[", "{lbracket}"), ("]", "{rbracket}"), ("(", "{lparen}"), (")", "{rparen}"),
        ("!", "{exclamation}"), ("?", "{question}"), ("*", "{asterisk}"), ("\"", "{quote}"),
        ("'", "{apostrophe}"), ("`", "{backtick}"), ("~", "{tilde}"), ("@", "{at}"),
        ("#", "{hash}"), ("$", "{dollar}"), ("%", "{percent}"), ("^", "{caret}"),
        ("&", "{ampersand}"), ("+", "{plus}"), ("=", "{equals}"), ("|", "{pipe}"),
        ("\\", "{backslash}"), ("<", "{lt}"), (">", "{gt}"), (" ", "{space}"),
        ("_", "{underbar}"), ("/", "{slash}"),
    ]

    func sanitizeKeywordOnly(_ keyword: String) -> String {
        // 🎯 키워드 부분만 특수문자를 읽을 수 있는 텍스트로 변환
        var result = keyword

        // 특수문자 변환 매핑 (중괄호 중첩 방지를 위한 단계별 처리)
        // 1단계: 중괄호를 임시 표시로 변환
        result = result.replacingOccurrences(of: "{", with: "【LCURLY】")
        result = result.replacingOccurrences(of: "}", with: "【RCURLY】")

        // 2단계: 다른 특수문자들 변환
        let specialCharMappings: [(String, String)] = [
            (".", "{period}"),
            (",", "{comma}"),
            (":", "{colon}"),
            (";", "{semicolon}"),
            ("[", "{lbracket}"),
            ("]", "{rbracket}"),
            ("(", "{lparen}"),
            (")", "{rparen}"),
            ("!", "{exclamation}"),
            ("?", "{question}"),
            ("*", "{asterisk}"),
            ("\"", "{quote}"),
            ("'", "{apostrophe}"),
            ("`", "{backtick}"),
            ("~", "{tilde}"),
            ("@", "{at}"),
            ("#", "{hash}"),
            ("$", "{dollar}"),
            ("%", "{percent}"),
            ("^", "{caret}"),
            ("&", "{ampersand}"),
            ("+", "{plus}"),
            ("=", "{equals}"),
            ("|", "{pipe}"),
            ("\\", "{backslash}"),
            ("<", "{lt}"),
            (">", "{gt}"),
            (" ", "{space}"),
            ("_", "{underbar}"),  // 언더바 추가
        ]

        // 특수문자 변환 적용
        for (char, replacement) in specialCharMappings {
            result = result.replacingOccurrences(of: char, with: replacement)
        }

        // 3단계: 임시로 변환한 중괄호를 최종 형태로 변환
        result = result.replacingOccurrences(of: "【LCURLY】", with: "{lcurly}")
        result = result.replacingOccurrences(of: "【RCURLY】", with: "{rcurly}")

        return result
    }

    // MARK: - 파일명 생성

    /// Issue64: 최적화된 파일명 생성
    func generateOptimizedFileName(name: String, keyword: String, collection: String) -> String? {
        // Issue701/Issue717: 특수문자 변환을 최우선으로 수행 (prefix 제거 전)
        // 1. suffix 제거 (원본 키워드에서)
        let cleanKeyword = extractCleanKeyword(from: keyword, collection: collection)
        // 2. 특수문자 변환 먼저 수행 (`,` → `{comma}`)
        let sanitized = sanitizeKeywordOnly(cleanKeyword)
        // 3. prefix 제거는 변환된 형태에서 수행 (`{comma}` != `,` prefix)
        let originalKeyword = removePrefixDuplication(keyword: sanitized, collection: collection)

        let nameIsEmpty = name.isEmpty
        let nameEndsWithSpace =
            name.hasSuffix(" ") && !name.trimmingCharacters(in: .whitespaces).isEmpty
        let originalWithPrefix = cleanKeyword
        let keywordEndsWithSpace =
            originalWithPrefix.hasSuffix(" ")
            && !originalWithPrefix.trimmingCharacters(in: .whitespaces).isEmpty

        var safeName = sanitizeFilename(name)
        var safeKeyword =
            (originalKeyword == "{space}") ? "{space}" : originalKeyword

        // 키워드가 비어있는 경우
        if safeKeyword.isEmpty {
            if keyword.contains(" ") || originalWithPrefix.hasSuffix(" ") {
                let folderAbbreviation = collection.compactMap {
                    $0.isUppercase ? String($0).lowercased() : nil
                }.joined()
                let capitalizedAbbrev =
                    folderAbbreviation.prefix(1).uppercased()
                    + folderAbbreviation.dropFirst().lowercased()
                return "===\(capitalizedAbbrev)_.txt"
            }
            if !name.isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty {
                return "===\(sanitizeFilename(name)).txt"
            }
            return "=.txt"
        }

        // Name 처리
        if nameIsEmpty {
            safeName = safeKeyword.lowercased()
        } else if nameEndsWithSpace || keywordEndsWithSpace {
            if safeKeyword == "{space}" {
                let folderAbbreviation = collection.compactMap {
                    $0.isUppercase ? String($0).lowercased() : nil
                }.joined()
                let capitalizedAbbrev =
                    folderAbbreviation.prefix(1).uppercased()
                    + folderAbbreviation.dropFirst().lowercased()
                safeName = capitalizedAbbrev + "_"
                return "===\(safeName).txt"
            }
            let cleanedKeyword = safeKeyword.replacingOccurrences(of: "{space}", with: "")
            safeKeyword =
                cleanedKeyword.prefix(1).uppercased() + cleanedKeyword.dropFirst().lowercased()
            safeName = safeKeyword + "_"
        }

        // 다중 대문자 확인
        let upperCount = collection.filter { $0.isUppercase }.count
        if upperCount > 1 {
            let folderAbbreviation = collection.compactMap {
                $0.isUppercase ? String($0).lowercased() : nil
            }.joined()
            if safeKeyword.lowercased() == folderAbbreviation {
                let cleanName = safeName.replacingOccurrences(of: "{space}", with: "")
                if keywordEndsWithSpace || nameEndsWithSpace {
                    return "===\(cleanName).txt"
                } else {
                    return "===\(cleanName.lowercased()).txt"
                }
            }
        }

        let needsUnderscore = !originalKeyword.isEmpty && originalKeyword.first!.isUppercase
        let underscoreSuffix = needsUnderscore ? "_" : ""

        if safeKeyword.lowercased() == safeName.lowercased() {
            return "\(safeKeyword)\(underscoreSuffix).txt"
        } else {
            return "\(safeKeyword)===\(safeName)\(underscoreSuffix).txt"
        }
    }

    // MARK: - 헬퍼 함수

    /// 예약어(예: {keypad_comma}, {comma})에 대응하는 원본 리터럴 문자 후보군을 반환합니다.
    private func getLiteralCandidates(for placeholder: String) -> [String] {
        var candidates: [String] = [placeholder]

        guard let config = importConfig else { return candidates }

        // 1. triggerRemapping 역추적 (예: {keypad_comma} -> ◊, ,)
        for (original, mapping) in config.triggerRemapping {
            if mapping == placeholder {
                if !candidates.contains(original) { candidates.append(original) }
            }
        }

        // 2. specialCharMappings 역추적 (예: {comma} -> ,)
        for (char, mapping) in SPECIAL_CHAR_MAPPINGS {
            if mapping == placeholder {
                if !candidates.contains(char) { candidates.append(char) }
            }
        }

        // 3. 지능적 연결: 만약 placeholder가 {keypad_comma} 인데 ,(comma)를 포함한다면
        // {comma} 에 대응하는 리터럴 [,] 도 후보에 포함시킴
        if placeholder.contains("comma") {
            if !candidates.contains(",") { candidates.append(",") }
        }
        if placeholder.contains("period") {
            if !candidates.contains(".") { candidates.append(".") }
        }

        return candidates
    }

    func extractCleanKeyword(from keyword: String, collection: String) -> String {
        // 🎯 Issue65/75: 공백은 보존해야 하므로 trimming 제거
        let rawKeyword = keyword

        // _rule_for_import.yml에서 로드한 Config 사용 (필수)
        guard let config = importConfig else { return rawKeyword }

        var suffixes: [String] = []

        // Issue701: triggerRemapping originals는 suffix에 추가 (◊ 등 Alfred 트리거 제거용)
        for (original, _) in config.triggerRemapping {
            if !suffixes.contains(original) { suffixes.append(original) }
        }

        // Config의 컬렉션에서 suffix 추출
        // Issue702: {keypad_comma} 같은 Alias 예약어가 오면, 이 예약어가 의미하는 원본 문자들(예: `,` 및 `{comma}`)까지 모두 suffix 목록에 등록합니다.
        for (_, rule) in config.collections {
            if let suffix = rule.suffix, !suffix.isEmpty {
                if !suffixes.contains(suffix) {
                    suffixes.append(suffix)
                }

                // 역추적: suffix 자체가 예약어일 수 있으므로 후보군을 추출 (예: {keypad_comma} -> ,)
                let cands = getLiteralCandidates(for: suffix)
                for c in cands {
                    if !suffixes.contains(c) {
                        suffixes.append(c)
                    }
                    // 역추적된 문자(예: `,`)의 SPECIAL_CHAR_MAPPING 값(예: `{comma}`)도 포함
                    for (char, mapping) in SPECIAL_CHAR_MAPPINGS {
                        if char == c && !suffixes.contains(mapping) {
                            suffixes.append(mapping)
                        }
                    }
                }
            }
        }

        // 가장 긴 것이 먼저 일치하도록 길이 내림차순 정렬
        // 🎯 Issue717: prefix 끝 문자 + suffix 조합을 복합 suffix로 추가
        // 예: _emoji prefix=",,", suffix={keypad_comma}→"◊" → compound ",◊" 추가
        // Alfred keyword "clap,◊"에서 ",◊"가 1회 매칭으로 제거되어 "clap"이 됨
        for (_, rule) in config.collections {
            if let prefix = rule.prefix, !prefix.isEmpty,
                let suffix = rule.suffix, !suffix.isEmpty
            {
                // suffix의 literal candidates 추출
                let suffixCands = getLiteralCandidates(for: suffix)
                // prefix 끝 문자의 literal candidates 추출
                let lastPrefixChar = String(prefix.last!)
                let prefixCands = getLiteralCandidates(for: lastPrefixChar)

                for pc in prefixCands {
                    for sc in suffixCands {
                        let compound = pc + sc
                        if compound.count > 1 && !suffixes.contains(compound) {
                            suffixes.append(compound)
                        }
                    }
                }
            }
        }

        suffixes.sort { $0.count > $1.count }

        // 단일 패스만 수행 (import_snippets.swift와 동일하게 적용하여 과도한 suffix 제거 방지)
        for suffix in suffixes {
            if rawKeyword.hasSuffix(suffix) {
                let withoutSuffix = String(rawKeyword.dropLast(suffix.count))

                // 🎯 Issue114: 결과값이 공백뿐인 경우(예: "c ◊" -> "c ")도 보존
                if !withoutSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || withoutSuffix == " "
                {
                    return withoutSuffix
                }
            }
        }
        return rawKeyword
    }

    func removePrefixDuplication(keyword: String, collection: String) -> String {
        let trimmedKeyword = keyword
        let ruleBasedPrefix = getRuleBasedPrefix(for: collection)

        // 접두사가 정확히 일치하는 경우
        if trimmedKeyword.lowercased() == ruleBasedPrefix.lowercased() { return "" }

        // 접두사로 시작하는 경우
        var resultKeyword = trimmedKeyword
        if !ruleBasedPrefix.isEmpty {
            var candidates: [String] = [ruleBasedPrefix]

            // Issue702: getLiteralCandidates를 통해 예약어를 역추적 (예: {keypad_comma} -> ,)
            let rawCands = getLiteralCandidates(for: ruleBasedPrefix)
            for c in rawCands {
                if !candidates.contains(c) {
                    candidates.append(c)
                }
                // 역추적된 문자의 SPECIAL_CHAR_MAPPING 도 함께 등록
                for (char, mapping) in SPECIAL_CHAR_MAPPINGS {
                    if char == c && !candidates.contains(mapping) {
                        candidates.append(mapping)
                    }
                }
            }

            // Issue: triggerRemapping 역매핑 추가 (Alfred 트리거 키 제거용)
            if let config = importConfig {
                for (original, mapping) in config.triggerRemapping {
                    if mapping == ruleBasedPrefix && !candidates.contains(original) {
                        candidates.append(original)
                    }
                }
            }

            let sortedCandidates = candidates.sorted { $0.count > $1.count }

            var didModify = true
            while didModify {
                didModify = false
                for cand in sortedCandidates {
                    if resultKeyword.lowercased().hasPrefix(cand.lowercased()) {
                        resultKeyword = String(resultKeyword.dropFirst(cand.count))
                        didModify = true
                        break
                    }
                }
            }
        }

        // 반복 제거 후 결과가 빈 문자열이면 원본을 반환 (과도한 삭제 방지)
        let finalKeyword = resultKeyword.isEmpty ? trimmedKeyword : resultKeyword

        // 특수 컬렉션의 경우, 명시적 규칙이 없으면 자동 추론을 피하기 위해 그대로 반환
        if collection.hasPrefix("_") && ruleBasedPrefix.isEmpty {
            return finalKeyword
        }

        if !collection.hasPrefix("_") {
            let keywordEndsWithSpace = finalKeyword.hasSuffix(" ")
            let trimmedKeywordLower = finalKeyword.trimmingCharacters(in: .whitespaces)
                .lowercased()
            let upperCount = collection.filter { $0.isUppercase }.count
            let collectionName = collection.lowercased()

            if upperCount > 1 && trimmedKeywordLower.hasPrefix(collectionName) {
                let remaining = String(finalKeyword.dropFirst(collectionName.count))
                if remaining.trimmingCharacters(in: .whitespaces).isEmpty { return "" }
                return remaining
            }

            if upperCount == 1 {
                if collection == "Claude_code" {
                    let firstChar = String(collection.prefix(1)).lowercased()
                    let keywordToCheck = finalKeyword.trimmingCharacters(in: .whitespaces)
                        .lowercased()
                    if keywordToCheck == firstChar {
                        return ""
                    } else if keywordToCheck.hasPrefix(firstChar) {
                        return String(finalKeyword.dropFirst(1))
                    }
                } else {
                    let firstLetter = String(collection.prefix(1)).lowercased()
                    if keywordEndsWithSpace && trimmedKeywordLower == firstLetter {
                        return "{space}"
                    }
                    if trimmedKeywordLower == firstLetter { return "" }
                    if trimmedKeywordLower.hasPrefix(firstLetter) && finalKeyword.count > 1 {
                        // 원본 공간 보존: 실제 비교 대상 접두사 길이만큼 제거
                        return String(finalKeyword.dropFirst(1))
                    }
                }
            }

            if upperCount > 1 {
                let folderAbbrev = collection.compactMap {
                    $0.isUppercase ? String($0).lowercased() : nil
                }.joined()
                if keywordEndsWithSpace && trimmedKeywordLower == folderAbbrev { return "{space}" }
                if trimmedKeywordLower.hasPrefix(folderAbbrev) {
                    let remaining = String(finalKeyword.dropFirst(folderAbbrev.count))
                    if remaining.isEmpty { return "" }
                    return remaining
                }
            }
        }
        return finalKeyword
    }

    func getRuleBasedPrefix(for collection: String) -> String {
        guard let config = importConfig else { return "" }
        if let rule = config.collections[collection] {
            if let prefix = rule.prefix {
                return prefix
            }
            // 규칙에는 있지만 Prefix 필드 자체가 없는 경우 (이런 케이스는 드물지만)
            return ""
        }

        // Issue689_9 재발생 대응 하드코딩된 fallback(특수 컬렉션인데 규칙에 등록되지 않은 경우):
        // _rule_for_import.yml에 등록되지 않은 경우에만 앱의 Default Trigger 적용.
        if collection.hasPrefix("_") {
            return config.triggerRemapping.values.first ?? "{keypad_comma}"
        }

        return ""
    }

    /// 특수 리터럴 컬렉션 여부 판별
    func isSpecialLiteralCollection(_ collectionName: String) -> Bool {
        let normalizedName = collectionName.precomposedStringWithCanonicalMapping
        return normalizedName == "_emoji" || normalizedName == "_Bullets"
            || normalizedName == "_한글속기".precomposedStringWithCanonicalMapping
            || normalizedName == "_한글 속기".precomposedStringWithCanonicalMapping
    }

    // MARK: - 규칙 생성 (Issue 149 로직)

    /// Prefix를 기록해야 하는지 판단
    /// - prefix가 없거나 비어있으면 생략
    /// - 폴더 대문자 약어와 일치하면 생략 (일반 폴더만)
    /// - 특수 폴더(_로 시작)는 항상 기록
    private func shouldWritePrefix(collectionName: String, prefix: String?) -> Bool {
        guard let prefix = prefix, !prefix.isEmpty else {
            return false
        }

        // 특수 폴더(_로 시작)는 항상 기록
        if collectionName.hasPrefix("_") {
            return true
        }

        // 일반 폴더: 대문자 약어와 비교
        let capitalAbbr = FileUtilities.extractCapitalLetters(from: collectionName)

        // Affix가 대문자 약어와 일치하면 생략
        if prefix.lowercased() == capitalAbbr.lowercased() {
            return false
        }

        return true
    }

    /// Suffix를 기록해야 하는지 판단
    /// - suffix가 없거나 비어있으면 생략
    /// - 가장 비중이 높은 suffix와 일치하면 생략
    private func shouldWriteSuffix(suffix: String?, mostCommonSuffix: String) -> Bool {
        guard let suffix = suffix, !suffix.isEmpty else {
            return false
        }

        // Alfred DB에서 가장 비중이 높은 suffix와 일치하면 생략
        if suffix == mostCommonSuffix {
            return false
        }

        return true
    }

    /// 컬렉션 섹션을 작성해야 하는지 판단
    /// - prefix, suffix, trigger_bias 중 하나라도 기록 필요하면 true
    /// - 모두 생략 가능하면 섹션 자체를 생략
    private func shouldWriteCollection(
        collectionName: String,
        prefix: String?,
        suffix: String?,
        triggerBias: Int?,
        mostCommonSuffix: String
    ) -> Bool {
        // prefix나 suffix 중 하나라도 기록 필요하면 작성
        if shouldWritePrefix(collectionName: collectionName, prefix: prefix) {
            return true
        }
        if shouldWriteSuffix(suffix: suffix, mostCommonSuffix: mostCommonSuffix) {
            return true
        }

        // trigger_bias가 있으면 작성
        if triggerBias != nil {
            return true
        }

        // 모두 생략 가능하면 섹션 자체를 생략
        return false
    }

    /// Alfred DB에서 가장 비중이 높은 suffix를 찾기
    /// - 모든 스니펫의 키워드에서 suffix를 추출하고 빈도를 분석
    /// - 가장 많이 사용되는 suffix를 반환 (기본값)
    private func findMostCommonSuffix(in collectionGroups: [String: [AlfredSnippet]]) -> String {
        var suffixCounts: [String: Int] = [:]

        // _rule_for_import.yml에서 로드한 Config 사용 (필수)
        guard let config = importConfig else { return "=" }

        // Config에서 알려진 suffix 목록 수집
        var knownSuffixes: [String] = []

        for (_, rule) in config.collections {
            if let suffix = rule.suffix, !suffix.isEmpty {
                if !knownSuffixes.contains(suffix) {
                    knownSuffixes.append(suffix)
                }
            }
        }

        // suffix가 없으면 기본값 "=" 반환
        guard !knownSuffixes.isEmpty else {
            return "="
        }

        // 가장 긴 것이 먼저 일치하도록 길이 내림차순 정렬
        knownSuffixes.sort { $0.count > $1.count }

        // 모든 스니펫의 키워드에서 suffix 추출
        for snippets in collectionGroups.values {
            for snippet in snippets {
                for suffix in knownSuffixes {
                    if snippet.keyword.hasSuffix(suffix) {
                        suffixCounts[suffix, default: 0] += 1
                        break  // 가장 긴 suffix만 카운트하기 위해 break
                    }
                }
            }
        }

        // suffix 카운트가 없으면 기본값 "=" 반환
        guard let mostCommon = suffixCounts.max(by: { $0.value < $1.value }) else {
            return "="
        }

        logD("🎩 Alfred Import 가장 비중 높은 suffix: '\(mostCommon.key)' (\(mostCommon.value)개)")
        return mostCommon.key
    }

    func createUnifiedRuleYAML(collectionGroups: [String: [AlfredSnippet]]) -> String {
        // Alfred DB에서 가장 비중이 높은 suffix를 계산 (기본값으로 사용)
        let mostCommonSuffix = findMostCommonSuffix(in: collectionGroups)

        let sortedCollections = collectionGroups.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        var yamlContent = ""
        if let bundleURL = Bundle.main.url(forResource: "_rule", withExtension: "yml"),
            let content = try? String(contentsOf: bundleURL, encoding: .utf8)
        {
            yamlContent = content
            if !yamlContent.hasSuffix("\n") {
                yamlContent += "\n"
            }
        } else {
            logW("🎩 ⚠️ [AlfredLogic] 번들 내 _rule.yml을 찾을 수 없습니다. 기본 내용으로 대체합니다.")

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            let currentDate = dateFormatter.string(from: Date())
            let totalCount = importConfig?.collections.count ?? 0

            yamlContent = """
                # fSnippet Rule File (Auto-generated from Alfred Import & Settings)
                # Generated: \(currentDate)
                # Collections: \(totalCount)

                global:
                  generator: "fSnippet Settings"

                collections:

                """
        }

        // _rule_for_import.yml에서 로드한 Config 사용 (필수)
        guard let config = importConfig else { return yamlContent }  // 빈 collections 섹션만 반환

        var definedInYaml = Set<String>()

        // 1. 구성된 컬렉션 작성 (_rule_for_import.yml 기반)
        let configCollections = config.collections.keys.sorted()

        // _ 접두사 순서 정렬 (특수 폴더 우선, 그 다음 알파벳순)
        let sortedConfigKeys = configCollections.sorted {
            let aUnderscore = $0.hasPrefix("_")
            let bUnderscore = $1.hasPrefix("_")
            if aUnderscore && !bUnderscore { return true }
            if !aUnderscore && bUnderscore { return false }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        for name in sortedConfigKeys {
            if let rule = config.collections[name] {
                // _rule_for_import.yml의 규칙은 강제 규칙이므로 항상 기록
                yamlContent += "\n  - name: \"\(name)\""

                // prefix는 항상 기록
                if let prefix = rule.prefix, !prefix.isEmpty {
                    yamlContent += "\n    prefix: \"\(prefix)\""
                }

                // suffix는 항상 기록
                if let suffix = rule.suffix, !suffix.isEmpty {
                    yamlContent += "\n    suffix: \"\(suffix)\""
                }

                // trigger_bias 기록
                if let bias = rule.triggerBias {
                    yamlContent += "\n    trigger_bias: \(bias)"
                }

                yamlContent += "\n    description: \"\(name)\""

                definedInYaml.insert(name)
            }
        }

        // 2. 감지된/동적 컬렉션 작성
        for rawName in sortedCollections {
            let name = rawName.precomposedStringWithCanonicalMapping
            if !definedInYaml.contains(name) {
                // 규칙 결정
                let snippets = collectionGroups[rawName] ?? []
                let keywords = snippets.map { $0.keyword }

                if let autoPrefix = determineCollectionPrefix(
                    collectionName: name, keywords: keywords, globalPrefix: mostCommonSuffix)
                {
                    // 기본값인 경우 패스 (앱 기본 동작에 위임)
                    if autoPrefix == mostCommonSuffix { continue }

                    // 섹션 작성 필요 여부 확인 (Issue689_1 최적화)
                    if !shouldWriteCollection(
                        collectionName: name,
                        prefix: autoPrefix,
                        suffix: mostCommonSuffix,
                        triggerBias: nil,
                        mostCommonSuffix: mostCommonSuffix
                    ) {
                        continue
                    }

                    // 특수한 Prefix가 감지된 경우 YAML에 명시
                    yamlContent += "\n  - name: \"\(name)\""

                    // prefix 조건부 기록
                    if shouldWritePrefix(collectionName: name, prefix: autoPrefix) {
                        yamlContent += "\n    prefix: \"\(autoPrefix)\""
                    }

                    // suffix는 가장 비중이 높은 suffix이므로 생략

                    yamlContent += "\n    description: \"\(name)\""
                }
            }
        }

        return yamlContent
    }

    func determineCollectionPrefix(collectionName: String, keywords: [String], globalPrefix: String)
        -> String?
    {
        // _rule_for_import.yml에서 로드한 Config 사용 (필수)
        guard let config = importConfig else { return globalPrefix }

        // Config에 정의된 규칙이 있으면 사용
        if let rule = config.collections[collectionName], let prefix = rule.prefix {
            return prefix
        }

        // 특수 폴더는 기본값으로 대체
        if collectionName.hasPrefix("_") {
            return globalPrefix
        }

        // 일반 폴더: 키워드에서 prefix 추출
        let extractedPrefixes = keywords.compactMap { extractPrefixPartFromKeyword($0) }
        let prefixCount = Dictionary(grouping: extractedPrefixes, by: { $0 }).mapValues { $0.count }
        return prefixCount.max(by: { $0.value < $1.value })?.key ?? globalPrefix
    }

    func extractPrefixPartFromKeyword(_ keyword: String) -> String? {
        // _rule_for_import.yml에서 로드한 Config 사용 (필수)
        guard let config = importConfig else { return nil }

        // Config에서 suffix 목록 수집
        var suffixes: [String] = []
        for (_, rule) in config.collections {
            if let s = rule.suffix, !s.isEmpty {
                if !suffixes.contains(s) {
                    suffixes.append(s)
                }
            }
        }

        // suffix가 없으면 nil 반환
        guard !suffixes.isEmpty else { return nil }

        suffixes.sort { $0.count > $1.count }

        for suffix in suffixes {
            if keyword.hasSuffix(suffix) {
                let prefixPart = String(keyword.dropLast(suffix.count))
                return prefixPart.isEmpty ? nil : prefixPart
            }
        }
        return nil
    }

    // MARK: - 중복 제거 로직 (스크립트에서 포팅됨)

    func removeDuplicateSnippets(_ snippets: [AlfredSnippet]) -> [AlfredSnippet] {
        var snippetGroups: [String: [AlfredSnippet]] = [:]

        // 내용별 그룹화 (공백 정규화 후 비교 + 키워드 포함)
        for snippet in snippets {
            let normalizedSnippet = snippet.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            // 🎯 Issue: 키워드가 다르지만 내용이 같은 경우(예: '☐'를 '6'과 '`'로 각각 매핑)를
            // 보존하기 위해 uniqueKey 생성 시 keyword를 포함시킴
            let uniqueKey = "\(snippet.collection ?? "")_\(snippet.keyword)_\(normalizedSnippet)"

            if snippetGroups[uniqueKey] == nil {
                snippetGroups[uniqueKey] = []
            }
            snippetGroups[uniqueKey]!.append(snippet)
        }

        var uniqueSnippets: [AlfredSnippet] = []

        for (_, group) in snippetGroups {
            if group.count == 1 {
                uniqueSnippets.append(group[0])
            } else {
                let bestSnippet = selectBestKeyword(from: group)
                uniqueSnippets.append(bestSnippet)
            }
        }

        return uniqueSnippets
    }

    func selectBestKeyword(from snippets: [AlfredSnippet]) -> AlfredSnippet {
        let scored = snippets.map { snippet -> (AlfredSnippet, Int) in
            let keyword = snippet.keyword
            let alphanumericCount = keyword.filter { $0.isLetter || $0.isNumber }.count
            let specialCharCount = keyword.count - alphanumericCount
            let score = alphanumericCount * 10 - specialCharCount * 5 + keyword.count
            return (snippet, score)
        }

        let sorted = scored.sorted { (first, second) in
            if first.1 == second.1 {
                return first.0.keyword < second.0.keyword
            }
            return first.1 > second.1
        }

        return sorted[0].0
    }
}
