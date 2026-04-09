import AppKit
import Foundation

/// Alfred 스니펫 규칙 관리 클래스
/// _rule.yml 파일을 읽어서 prefix/suffix 규칙을 관리
class RuleManager: RuleManagerProtocol {
    static let shared = RuleManager()

    private var cachedRules: [String: CollectionRule] = [:]
    private let ruleQueue = DispatchQueue(
        label: "com.nowage.fSnippet.RuleManager", attributes: .concurrent)
    private var globalSettings: GlobalSettings?
    private var karabinerMappings: [UInt16: String] = [:]
    private var enhancedKeyMappings: [String: EnhancedKeyMapping] = [:]
    private let fileManager = FileManager.default
    private var isLoadedSuccessfully = false  // Issue137: 로드 성공 여부 플래그
    private var lastRuleFileModificationDate: Date?  // Issue172: 파일 변경 시간 추적
    private var currentRuleFilePath: String?  // 현재 로드된 규칙 파일 경로
    private var cachedEffectiveRules: [CollectionRule]?  // Issue332: Effective Rules Cache

    private init() {
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Issue583_9: Cache Invalidation Observers
    private func setupObservers() {
        // Snippet folders change (new folder, rename) -> Invalidate
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRuleInvalidation), name: .snippetFoldersDidChange,
            object: nil)

        // Preferences update (batch update) -> Invalidate
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRuleInvalidation), name: .preferencesDidUpdate,
            object: nil)

        // Config loaded -> Invalidate (to be safe)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRuleInvalidation), name: .preferencesDidLoadConfig,
            object: nil)

        // Legacy: External settings change might post this?
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRuleInvalidation), name: .settingsDidChange, object: nil
        )
    }

    @objc private func handleRuleInvalidation() {
        // 이미 큐 내부에서 비동기로 실행될 수 있으므로,
        // invalidateEffectiveRulesCache() 호출로 충분함 (내부에서 barrier async 사용)
        invalidateEffectiveRulesCache()
        logV("📐    [RuleManager] Cache Invalidated due to notification")
    }

    /// 전역 설정 구조체
    struct GlobalSettings {
        let importedDate: String
    }

    /// 컬렉션별 규칙 구조체
    struct CollectionRule: Equatable {
        let name: String
        var suffix: String
        var prefix: String
        var description: String?  // description 필드 추가 (Issue111)
        var triggerBias: Int?  // trigger_bias 필드 추가 (nil이면 기본 설정 사용)

        // Issue317: Comments preservation
        var prefixComment: String?
        var suffixComment: String?
        var triggerBiasComment: String?
        var descriptionComment: String?

        static func == (lhs: CollectionRule, rhs: CollectionRule) -> Bool {
            return lhs.name == rhs.name && lhs.suffix == rhs.suffix && lhs.prefix == rhs.prefix
                && lhs.description == rhs.description && lhs.triggerBias == rhs.triggerBias
                && lhs.prefixComment == rhs.prefixComment && lhs.suffixComment == rhs.suffixComment
                && lhs.triggerBiasComment == rhs.triggerBiasComment
                && lhs.descriptionComment == rhs.descriptionComment
        }
    }

    /// 향상된 키 매핑 정보 구조체 (KeyLogger 결과 기반)
    struct EnhancedKeyMapping {
        let keyCode: String
        let usagePage: String
        let usage: String
        let misc: String
        let character: String
        let collections: [String]
        let triggerType: String
    }

    /// 규칙 파일 전체 구조체
    struct RuleFile {
        let global: GlobalSettings?
        let collections: [CollectionRule]
        let karabinerMappings: [UInt16: String]
        let enhancedKeyMappings: [String: EnhancedKeyMapping]
    }

    /// 규칙 파일을 읽고 파싱
    func loadRules(from filePath: String) -> Bool {
        // [Issue199] Tilde(~) 수동 확장 (Sandbox 우회)
        var expandedPath = filePath
        if expandedPath.hasPrefix("~") {
            // Issue654: /Users/(userName) 하드코딩 제거 → FileManager API 사용 (path-rules.md 준수)
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expandedPath = expandedPath.replacingOccurrences(of: "~", with: homeDir)
        } else {
            // ~로 시작하지 않는 경우 일반 확장으로 폴백 (드묾)
            expandedPath = (expandedPath as NSString).expandingTildeInPath
        }

        let url = URL(fileURLWithPath: expandedPath)

        // 파일 존재 확인
        guard fileManager.fileExists(atPath: url.path) else {
            logW("📐    규칙 파일이 존재하지 않음: \(expandedPath)")
            return false
        }

        // Issue172: 파일 변경 시간 확인 (불필요한 재파싱 방지)
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
            let modificationDate = attributes[.modificationDate] as? Date
        {

            if let lastModified = lastRuleFileModificationDate, lastModified == modificationDate,
                currentRuleFilePath == filePath
            {
                // 변경사항 없음 - 재파싱 건너뜀
                // logV("📐    규칙 파일 변경 없음 - 재파싱 생략") // 너무 빈번하므로 주석 처리
                return isLoadedSuccessfully
            }

            // 변경됨 - 업데이트
            lastRuleFileModificationDate = modificationDate
            currentRuleFilePath = filePath
            logV("📐    규칙 파일 변경 감지 - 재로드 시작 (수정시간: \(modificationDate))")
        }

        // 파일 읽기
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logW("📐    규칙 파일을 읽을 수 없음: \(filePath)")
            return false
        }

        return loadRules(content: content)
    }

    /// Issue278: 정의된 Suffix 단축키를 ShortcutMgr에 등록
    func registerRulesToShortcutMgr() {
        // Issue316: ShortcutMgr의 중앙 로직 사용 (중복 제거 & Prefix 지원)
        ShortcutMgr.shared.registerFolderShortcuts()
    }

    /// 규칙 파일을 읽고 파싱 (내부용)
    private func loadRules(content: String) -> Bool {
        // YAML 파일 로드됨 (내용은 VERBOSE 레벨에서 출력)
        logV("📐    YAML 파일 내용:\n\(content)")

        // YAML 파싱
        guard let ruleFile = parseYAML(content: content) else {
            logW("📐    규칙 파일 파싱 실패: \(currentRuleFilePath ?? "Unknown")")
            return false
        }

        // 캐시에 저장 - 스레드 안전하게 쓰기
        ruleQueue.async(flags: .barrier) {
            self.globalSettings = ruleFile.global
            self.cachedRules.removeAll()
            for rule in ruleFile.collections {
                self.cachedRules[rule.name] = rule
            }
            self.karabinerMappings = ruleFile.karabinerMappings
            self.enhancedKeyMappings = ruleFile.enhancedKeyMappings

            self.isLoadedSuccessfully = true  // Issue137: 로드 성공 마킹

            // Issue278: Suffix 단축키 등록 (Main Thread)
            DispatchQueue.main.async {
                self.registerRulesToShortcutMgr()

                // Issue480: PSKeyManager 채우기
                // 접두사와 접미사로 PSKeyManager 채우기
                var prefixes: [String] = []
                var suffixes: [String] = []

                for rule in ruleFile.collections {
                    if !rule.prefix.isEmpty { prefixes.append(rule.prefix) }
                    // if let ps = rule.prefixShortcut, !ps.isEmpty { prefixes.append(ps) } // Removed

                    if !rule.suffix.isEmpty { suffixes.append(rule.suffix) }
                    // if let ss = rule.suffixShortcut, !ss.isEmpty { suffixes.append(ss) } // Removed
                }

                PSKeyManager.shared.clear()  // 다시 로드할 때 새로 시작
                PSKeyManager.shared.addPrefix(prefixes)
                PSKeyManager.shared.addSuffix(suffixes)

                // Issue480: 초기화 후 트리거 키 동기화
                TriggerKeyManager.shared.syncToPSKeyManager()
            }
        }

        logV("📐    규칙 파일 로드 성공: \(ruleFile.collections.count)개 컬렉션")
        return true
    }

    /// 간단한 YAML 파서 (Foundation 기반)
    private func parseYAML(content: String) -> RuleFile? {
        let lines = content.components(separatedBy: .newlines)
        var globalSettings: GlobalSettings?
        var collections: [CollectionRule] = []
        var karabinerMappings: [UInt16: String] = [:]
        var enhancedKeyMappings: [String: EnhancedKeyMapping] = [:]

        var currentCollection: [String: String] = [:]
        var currentEnhancedKey: [String: Any] = [:]
        var currentEnhancedKeyName: String = ""
        var isInCollections = false
        var isInGlobal = false
        var isInKarabinerMappings = false
        var isInEnhancedKeyMappings = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 빈 줄이나 주석 건너뛰기
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }

            // 섹션 식별
            if trimmedLine == "global:" {
                isInGlobal = true
                isInCollections = false
                isInKarabinerMappings = false
                isInEnhancedKeyMappings = false
                logV("📐    [SECTION] global 섹션 진입")
                continue
            } else if trimmedLine == "karabiner_mappings:" {
                isInKarabinerMappings = true
                isInGlobal = false
                isInCollections = false
                isInEnhancedKeyMappings = false
                logV("📐    [SECTION] karabiner_mappings 섹션 진입")
                continue
            } else if trimmedLine == "enhanced_key_mappings:" {
                isInEnhancedKeyMappings = true
                isInGlobal = false
                isInCollections = false
                isInKarabinerMappings = false
                logV("📐    [SECTION] enhanced_key_mappings 섹션 진입")
                continue
            } else if trimmedLine == "collections:" {
                isInCollections = true
                isInGlobal = false
                isInKarabinerMappings = false
                isInEnhancedKeyMappings = false
                logV("📐    [SECTION] collections 섹션 진입")
                continue
            }

            // 글로벌 설정 파싱
            if isInGlobal {
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(
                        in: .whitespaces)
                    let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                    if key == "imported_date" {
                        globalSettings = GlobalSettings(importedDate: value)
                    }
                }
            }

            // Karabiner 매핑 파싱 (새로운 형식: "문자": KeyLogger데이터)
            if isInKarabinerMappings {
                logTrace("📐 📜 [KARABINER_PARSE] 파싱 중인 줄: '\(trimmedLine)'")
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let keyString = String(trimmedLine[..<colonIndex])
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))  // 따옴표 제거
                    let valueString = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: "#")[0]  // 주석 제거
                        .trimmingCharacters(in: .whitespaces)

                    logTrace(
                        "📐 📜 [KARABINER_PARSE] keyString: '\(keyString)', valueString: '\(valueString)'"
                    )

                    // 새로운 형식: "=": {"key_code":"24", "usagePage":"7 (0x0007)", ...}
                    if valueString.hasPrefix("{") && valueString.hasSuffix("}") {
                        logTrace("📐 📜 [KARABINER_PARSE] JSON 형식 감지: \(valueString)")
                        // JSON에서 key_code 추출 (key_code와 keyCode 모두 지원)
                        var keyCodeString: String?
                        if let keyCodeRange = valueString.range(of: "\"key_code\":\""),
                            let endRange = valueString.range(
                                of: "\"", range: keyCodeRange.upperBound..<valueString.endIndex)
                        {
                            keyCodeString = String(
                                valueString[keyCodeRange.upperBound..<endRange.lowerBound])
                        } else if let keyCodeRange = valueString.range(of: "\"keyCode\":\""),
                            let endRange = valueString.range(
                                of: "\"", range: keyCodeRange.upperBound..<valueString.endIndex)
                        {
                            keyCodeString = String(
                                valueString[keyCodeRange.upperBound..<endRange.lowerBound])
                        }

                        if let keyCodeStr = keyCodeString {
                            let keyCode: UInt16?
                            if keyCodeStr.hasPrefix("unknown_") {
                                // "unknown_95" → 95 변환
                                let numberStr = String(keyCodeStr.dropFirst(8))  // "unknown_" 제거
                                keyCode = UInt16(numberStr)
                                logV(
                                    "📐    [KARABINER_PARSE] unknown_키 감지: '\(keyCodeStr)' → \(numberStr)"
                                )
                            } else {
                                keyCode = UInt16(keyCodeStr)
                            }

                            if let finalKeyCode = keyCode {
                                karabinerMappings[finalKeyCode] = keyString  // 문자를 값으로 저장
                                logV(
                                    "📐    [KARABINER_LOAD] 새 형식 매핑 로드: '\(keyString)' (keyCode: \(finalKeyCode))"
                                )
                            } else {
                                logV(
                                    "📐    [KARABINER_LOAD] keyCode 파싱 실패: keyCodeString='\(keyCodeStr)'"
                                )
                            }
                        } else {
                            logV("📐    [KARABINER_LOAD] keyCode 문자열 추출 실패")
                        }
                    }
                    // 기존 형식 호환성: keyCode: "문자"
                    else if let keyCode = UInt16(keyString) {
                        karabinerMappings[keyCode] = valueString.trimmingCharacters(
                            in: CharacterSet(charactersIn: "\""))
                        logV(
                            "📐    [KARABINER_LOAD] 기존 형식 매핑 로드: keyCode \(keyCode) → '\(valueString)'"
                        )
                    } else {
                        logV("📐    [KARABINER_LOAD] 인식되지 않는 형식: '\(keyString)': '\(valueString)'")
                    }
                } else {
                    logTrace("📐 📜 [KARABINER_PARSE] 콜론이 없는 줄: '\(trimmedLine)'")
                }
            }

            // Enhanced Key Mappings 파싱
            if isInEnhancedKeyMappings {
                logTrace("📐 📜 [ENHANCED_PARSE] 파싱 중인 줄: '\(trimmedLine)'")

                if trimmedLine.hasSuffix(":") && !trimmedLine.contains(" ") {
                    // 새로운 키 정의 시작 (예: equal_key:)

                    // 이전 키 저장
                    if !currentEnhancedKeyName.isEmpty && !currentEnhancedKey.isEmpty {
                        if let enhancedMapping = createEnhancedKeyMapping(from: currentEnhancedKey)
                        {
                            enhancedKeyMappings[currentEnhancedKeyName] = enhancedMapping
                            logV(
                                "📐    [ENHANCED_LOAD] Enhanced 매핑 로드 성공: \(currentEnhancedKeyName)")
                        }
                    }

                    // 새 키 시작
                    currentEnhancedKeyName = String(trimmedLine.dropLast())  // ':' 제거
                    currentEnhancedKey.removeAll()
                    logTrace("📐 📜 [ENHANCED_PARSE] 새로운 키 시작: '\(currentEnhancedKeyName)'")

                } else if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    // 키의 속성 파싱 (예: key_code: "unknown_95")
                    let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(
                        in: .whitespaces)
                    let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                    logTrace("📐 📜 [ENHANCED_PARSE] 속성: '\(key)' = '\(value)'")

                    // 배열 파싱 (collections)
                    if value.hasPrefix("[") && value.hasSuffix("]") {
                        let arrayContent = String(value.dropFirst().dropLast())
                        let items = arrayContent.components(separatedBy: ",")
                            .map {
                                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(
                                    in: CharacterSet(charactersIn: "\""))
                            }
                        currentEnhancedKey[key] = items
                    } else {
                        currentEnhancedKey[key] = value
                    }
                }
            }

            // 컬렉션 파싱
            if isInCollections {
                logV("📐    [COLLECTION_PARSE] 파싱 중: '\(trimmedLine)'")
                if trimmedLine.hasPrefix("- name:") {
                    // 이전 컬렉션 저장
                    if !currentCollection.isEmpty {
                        if let rule = createCollectionRule(from: currentCollection) {
                            collections.append(rule)
                            logV("📐    [COLLECTION_PARSE] 컬렉션 추가: \(rule.name)")
                        }
                        currentCollection.removeAll()
                    }

                    // 새 컬렉션 시작
                    let value = extractValue(from: trimmedLine, key: "- name:")
                    currentCollection["name"] = value
                    logV("📐    [COLLECTION_PARSE] 새 컬렉션 시작: '\(value)'")
                } else if trimmedLine.range(of: "suffix:") != nil {
                    let (value, comment) = extractValueAndComment(from: trimmedLine, key: "suffix:")
                    currentCollection["suffix"] = value
                    if let c = comment { currentCollection["suffix_comment"] = c }
                } else if trimmedLine.range(of: "prefix:") != nil {
                    let (value, comment) = extractValueAndComment(from: trimmedLine, key: "prefix:")
                    currentCollection["prefix"] = value
                    if let c = comment { currentCollection["prefix_comment"] = c }
                } else if trimmedLine.range(of: "trigger_bias:") != nil {
                    let (value, comment) = extractValueAndComment(
                        from: trimmedLine, key: "trigger_bias:")
                    currentCollection["trigger_bias"] = value
                    if let c = comment { currentCollection["trigger_bias_comment"] = c }
                } else if trimmedLine.range(of: "description:") != nil {
                    let (value, comment) = extractValueAndComment(
                        from: trimmedLine, key: "description:")
                    currentCollection["description"] = value
                    if let c = comment { currentCollection["description_comment"] = c }
                }
            }
        }

        // 마지막 컬렉션 저장
        if !currentCollection.isEmpty {
            if let rule = createCollectionRule(from: currentCollection) {
                collections.append(rule)
            }
        }

        // 마지막 Enhanced Key 저장
        if !currentEnhancedKeyName.isEmpty && !currentEnhancedKey.isEmpty {
            if let enhancedMapping = createEnhancedKeyMapping(from: currentEnhancedKey) {
                enhancedKeyMappings[currentEnhancedKeyName] = enhancedMapping
                logV("📐    [ENHANCED_LOAD] 마지막 Enhanced 매핑 로드 성공: \(currentEnhancedKeyName)")
            }
        }

        return RuleFile(
            global: globalSettings, collections: collections, karabinerMappings: karabinerMappings,
            enhancedKeyMappings: enhancedKeyMappings)
    }

    /// 값 추출 헬퍼 함수 (값, 주석) 반환
    private func extractValueAndComment(from line: String, key: String) -> (String, String?) {
        guard let keyRange = line.range(of: key) else { return ("", nil) }

        let valuePart = String(line[keyRange.upperBound...])

        if let hashIndex = valuePart.firstIndex(of: "#") {
            let value = String(valuePart[..<hashIndex])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let comment = String(valuePart[valuePart.index(after: hashIndex)...])
            // .trimmingCharacters(in: .whitespaces) // Keep original spacing for comments? Or trim? Let's trim start.
            return (value, comment)
        } else {
            let value =
                valuePart
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return (value, nil)
        }
    }

    /// 값 추출 헬퍼 함수 (Legacy wrapper)
    private func extractValue(from line: String, key: String) -> String {
        return extractValueAndComment(from: line, key: key).0
    }

    /// 딕셔너리에서 CollectionRule 생성
    private func createCollectionRule(from dict: [String: String]) -> CollectionRule? {
        // Issue317_1: saveRules 최적화로 인해 prefix/suffix가 생략될 수 있음.
        // 따라서 name만 필수, 나머지는 옵셔널로 처리 후 기본값 할당.
        guard let name = dict["name"] else {
            return nil
        }

        var prefix = dict["prefix"]
        var suffix = dict["suffix"]

        // 1. Prefix Handling
        // 값이 없거나 비어있는 경우
        if prefix == nil {
            // Check prefixShortcut presence
            if let shortcut = dict["prefixShortcut"], !shortcut.isEmpty {
                // Do nothing, let parsing block below handle it
            } else {
                // Issue 509_1: 특수 폴더에 대한 암시적 추론 중지
                if name.hasPrefix("_") {
                    logV(
                        "📐    [RuleManager] Skipping prefix inference for special folder '\(name)'")
                } else {
                    // 생략된 경우 기본값(대문자 이니셜)로 추론하지 않음 (UI에 자동 노출 및 하드코딩 방지)
                    prefix = ""
                    logV("📐    [RuleManager] '\(name)'에 대한 묵시적 접두사 필드는 UI 상 빈 값(\"\")으로 유지됨")
                }
            }
        }

        // 기존 로직: 빈 문자열이고 _가 없으면 추론 (이건 사용자가 명시적으로 ""를 줬을때? 아니면 이전 로직 잔재?)
        // dict["prefix"]가 있다면 있는 그대로 사용. (빈 문자열이면 빈 문자열)
        // 위에서 nil일때만 추론했으므로, ""로 저장된 경우는 "" 유지.

        // 추가 보정: 만약 extractCapitalLetters가 빈 문자열을 반환하면? (예: "abc") -> ""

        // 2. 접미사 처리
        if suffix == nil {
            // 레거시 suffixShortcut가 존재하는지 확인 (나중에 suffix에 병합되지만 추론 로직을 위해 여기서 확인?)
            // 사실 suffixShortcut가 존재하면 suffix는 그것으로 설정될 것임.
            // 하지만 여기서 'suffix' 변수는 nil임.

            if let shortcut = dict["suffixShortcut"], !shortcut.isEmpty {
                // 아무것도 하지 않음, 아래 파싱 블록에서 처리하도록 함
            } else {
                // Issue 452: 기본 트리거 키로 폴백하지 않음. 빈 문자열로 기본값 설정.
                suffix = ""
                logV("📐    [RuleManager] Inferred empty suffix for '\(name)' (Issue 452)")
            }
        }

        // trigger_bias 파싱 (옵셔널)
        let triggerBias: Int?
        if let triggerBiasStr = dict["trigger_bias"], let bias = Int(triggerBiasStr) {
            triggerBias = bias
            logV("📐    [TRIGGER_BIAS] '\(name)' 컬렉션의 trigger_bias: \(bias)")
        } else {
            // Issue 336: 생략 시 0을 기본값으로 사용 (사용자 요청)
            // Issue 454: Issue 336 되돌리기. 0을 기본값으로 사용하지 않음.
            // 0을 기본값으로 하면 설정하지 않아도 UI에서 "트리거 바이어스 사용"이 체크됨.
            // nil은 "전역 상속" 또는 "바이어스 없음"을 의미하며, 체크해제된 UI 상태에 올바르게 매핑됨.
            triggerBias = nil
        }

        let description = dict["description"]

        // Issue317: 딕셔너리에서 주석 추출 ("prefix_comment"와 같은 키로 저장됨)
        let prefixComment = dict["prefix_comment"]
        let suffixComment = dict["suffix_comment"]
        let triggerBiasComment = dict["trigger_bias_comment"]
        let descriptionComment = dict["description_comment"]

        // prefix/suffix 명확하게 언래핑 (nil 케이스를 처리했으므로 안전함)
        // Issue: {keypad_comma} 같은 특수문자 토큰을 먼저 실제 기호로 변환 후 정규화
        var finalPrefix = normalizeKeySpec(convertSpecialCharTokens(prefix ?? ""))
        let finalSuffix = normalizeKeySpec(convertSpecialCharTokens(suffix ?? ""))

        // 버퍼 클리어 문자가 포함된 Prefix 등록 방지 (Issue: Prefix Buffer Clear)
        finalPrefix = filterPrefixForBufferClearKeys(finalPrefix, folderName: name)

        // Issue 460: 단축키를 정규화하지 않음. (로직 통합으로 레거시 주석 제거)
        // Issue 478: 그러나 키패드 키의 경우 KeyEventMonitor는 감싸진 토큰을 생성함 (예: "{keypad_comma}").
        // 필요한 경우 위 파서나 여기서 감싸기를 보장함.
        // 유효한 토큰인 경우 정규화에 의해 이미 처리됨?
        // normalizeKeySpec 감싸기 로직: "keypad_num_lock" -> "{keypad_num_lock}".
        // 따라서 finalPrefix/finalSuffix는 정확해야 함.

        // Issue451: 잘못된 규칙에 대한 유효성 검사 (크래시 방지)
        // 명시적 구성이 필요한 "특수 폴더"(_로 시작)에 대한 엄격한 검사.
        // 특수 폴더에 명시적 접두사와 접미사가 모두 없는 경우 유효하지 않은 것으로 처리됨.
        // 원시 입력 존재 여부를 위해 dict 키를 확인.
        if name.hasPrefix("_") {
            let hasExplicitPrefix = dict["prefix"] != nil || dict["prefixShortcut"] != nil
            let hasExplicitSuffix = dict["suffix"] != nil || dict["suffixShortcut"] != nil

            if !hasExplicitPrefix && !hasExplicitSuffix {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = String(
                        localized: "alert_critical_config_error_title",
                        defaultValue: "Critical Configuration Error")

                    let messageFormat = String(
                        localized: "alert_invalid_rule_message",
                        defaultValue:
                            "The rule for folder '%@' is invalid.\nIt must have at least one of prefix or suffix defined in _rule.yml.\n\nThe application will now quit."
                    )
                    alert.informativeText = String(format: messageFormat, name)

                    alert.alertStyle = .critical
                    alert.addButton(withTitle: String(localized: "btn_quit", defaultValue: "Quit"))
                    alert.runModal()
                    NSApp.terminate(nil)
                }
                return nil
            }
        }

        // 안전을 위한 일반 검사 (특수 폴더가 아닌 경우 어찌저찌 비어있다면 폴백)
        let hasContent = !finalPrefix.isEmpty || !finalSuffix.isEmpty

        if !hasContent {
            // 기본 접미사 때문에 자주 발생하지 않겠지만 백업으로 좋음
            logW("📐    ⚠️ [RuleManager] '\(name)'에 대한 빈 규칙 감지됨. 무시함.")
            return nil
        }

        return CollectionRule(
            name: name, suffix: finalSuffix, prefix: finalPrefix, description: description,
            triggerBias: triggerBias,
            prefixComment: prefixComment, suffixComment: suffixComment,
            triggerBiasComment: triggerBiasComment, descriptionComment: descriptionComment)
    }

    // MARK: - 레거시 메서드 (더 이상 사용 안 함/제거됨)

    // Issue 524: 명시적 구성을 강제하기 위해 autoWrapSingleShortcut 제거됨.

    /// Issue: {comma} 같은 일반 특수문자 토큰만 실제 기호로 변환
    /// {keypad_comma} 같은 키패드 토큰은 그대로 유지 (코드에서 이미 {keypad_comma}로 표현됨)
    private func convertSpecialCharTokens(_ spec: String) -> String {
        guard spec.hasPrefix("{") && spec.hasSuffix("}") else {
            return spec  // 토큰 형식이 아니면 그대로 반환
        }

        let tokenName = String(spec.dropFirst().dropLast())  // "{comma}" -> "comma"

        // keypad_* 토큰은 그대로 유지 (코드에서 이미 {keypad_comma} 형태로 표현됨)
        if tokenName.hasPrefix("keypad_") {
            logV("📐    [RuleManager] 키패드 토큰 유지: '\(spec)'")
            return spec
        }

        // 특수문자 토큰만 매핑 (일반 문자 기호)
        let tokenMap: [String: String] = [
            "comma": ",",
            "period": ".",
            "colon": ":",
            "semicolon": ";",
            "question": "?",
            "exclamation": "!",
            "space": " ",
            "lcurly": "{",
            "rcurly": "}",
            "lbracket": "[",
            "rbracket": "]",
            "lt": "<",
            "gt": ">",
            "pipe": "|",
            "equal": "=",
            "hash": "#",
            "apostrophe": "'",
            "backtick": "`",
            "tilde": "~",
            "caret": "^",
            "underbar": "_"
        ]

        if let converted = tokenMap[tokenName] {
            logV("📐    [RuleManager] 특수문자 토큰 변환: '\(spec)' -> '\(converted)'")
            return converted
        }

        // 매핑되지 않은 토큰은 그대로 반환
        logD("📐    [RuleManager] 알려지지 않은 특수문자 토큰: '\(spec)' (그대로 유지)")
        return spec
    }

    /// Issue 459: 키 사양을 내부 형식 "{key_name}"으로 정규화
    /// 예: "keypad_num_lock" -> "{keypad_num_lock}"
    private func normalizeKeySpec(_ spec: String) -> String {
        // Issue 524: 자동 감싸기 휴리스틱 없이 중앙 집중식 감싸기 로직 직접 사용
        return EnhancedTriggerKey.wrapInBraces(spec)
    }

    // MARK: - Prefix Validation
    enum PrefixValidationError: Error, LocalizedError {
        case containsBufferClearKey(Character)

        var errorDescription: String? {
            switch self {
            case .containsBufferClearKey(let char):
                let charStr =
                    char == " "
                    ? "스페이스(공백)" : (char == "\n" ? "엔터(줄바꿈)" : (char == "\t" ? "탭" : String(char)))
                return "Prefix에 버퍼 클리어 문자('\(charStr)')가 포함될 수 없습니다."
            }
        }
    }

    /// Prefix 등록 전 버퍼 클리어 키가 포함되어 있는지 검증합니다
    func validatePrefix(_ prefix: String) -> Result<Void, PrefixValidationError> {
        let clearKeys = AppSettingManager.shared.bufferClearKeys
        for char in prefix {
            if clearKeys.contains(char) {
                return .failure(.containsBufferClearKey(char))
            }
        }
        return .success(())
    }

    /// 버퍼 클리어 문자가 포함된 Prefix 필터링
    private func filterPrefixForBufferClearKeys(_ prefix: String, folderName: String) -> String {
        if prefix.isEmpty { return prefix }
        let clearKeys = AppSettingManager.shared.bufferClearKeys
        if prefix.contains(where: { clearKeys.contains($0) }) {
            logW(
                "📐    🚨 [RuleManager] '\(folderName)' 폴더의 prefix('\(prefix)')에 버퍼 클리어 문자가 포함되어 무시됩니다."
            )
            return ""
        }
        return prefix
    }

    /// 딕셔너리에서 EnhancedKeyMapping 생성
    private func createEnhancedKeyMapping(from dict: [String: Any]) -> EnhancedKeyMapping? {
        guard let keyCode = dict["key_code"] as? String,
            let usagePage = dict["usage_page"] as? String,
            let usage = dict["usage"] as? String,
            let misc = dict["misc"] as? String,
            let character = dict["character"] as? String,
            let collections = dict["collections"] as? [String],
            let triggerType = dict["trigger_type"] as? String
        else {
            logW("📐    ❌ [ENHANCED_CREATE] Enhanced 키 매핑 생성 실패: 필수 필드 누락")
            return nil
        }

        return EnhancedKeyMapping(
            keyCode: keyCode,
            usagePage: usagePage,
            usage: usage,
            misc: misc,
            character: character,
            collections: collections,
            triggerType: triggerType
        )
    }

    /// 컬렉션 이름으로 규칙 조회
    func getRule(for collectionName: String) -> CollectionRule? {
        let normalizedName = collectionName.precomposedStringWithCanonicalMapping
        return ruleQueue.sync {
            return cachedRules[normalizedName]
        }
    }

    /// 모든 캐시된 규칙 조회 (Dictionary 형태)
    func getAllRulesDict() -> [String: CollectionRule] {
        return ruleQueue.sync {
            return cachedRules
        }
    }

    /// 모든 캐시된 규칙 조회 (Array 형태, Issue33용)
    /// 배열 복사본을 반환하므로 스레드 안전함
    func getAllRules() -> [CollectionRule] {
        return ruleQueue.sync {
            return Array(cachedRules.values)
        }
    }

    /// 전역 설정 조회
    func getGlobalSettings() -> GlobalSettings? {
        return globalSettings
    }

    /// Issue332: RuleManager 규칙과 SettingsManager(General Settings) 규칙 통합
    func getEffectiveRules() -> [CollectionRule] {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Thread-safe read for cache
        var cached: [CollectionRule]?
        ruleQueue.sync {
            cached = cachedEffectiveRules
        }
        if let cached = cached {
            // logV("📐    [RuleManager] Cache Hit") // Optional: Log hit
            return cached
        }

        logV("📐    [RuleManager] Cache Miss - Recalculating Effective Rules")

        // 1. 명시적 규칙으로 시작
        var rules = getAllRules()
        let existingRulesDict = getAllRulesDict()

        // 2. 일반 설정에서 암시적 규칙 추가
        let settings = SettingsManager.shared.load()
        let folderSymbols = settings.folderSymbols

        let snippetFolders = SnippetFileManager.shared.getSnippetFolders()

        for folderURL in snippetFolders {
            let folderName = folderURL.lastPathComponent

            if let existingRule = existingRulesDict[folderName] {
                var enriched = false
                var newSuffix = existingRule.suffix
                var newPrefix = existingRule.prefix

                if !folderName.hasPrefix("_") {
                    let autoPrefix = FileUtilities.extractCapitalLetters(from: folderName)
                        .lowercased()
                    if !newPrefix.contains(autoPrefix) {
                        newPrefix = newPrefix + autoPrefix
                        enriched = true
                    }
                }

                if let rawSymbol = folderSymbols[folderName.lowercased()], !rawSymbol.isEmpty {
                    if rawSymbol != newSuffix {
                        newSuffix = rawSymbol
                        enriched = true
                    }
                }

                if newPrefix.isEmpty {
                    if let settingsShortcut = settings.folderPrefixShortcuts[
                        folderName.lowercased()], !settingsShortcut.isEmpty
                    {
                        newPrefix = "{\(settingsShortcut)}"
                        enriched = true
                    }
                }

                if newSuffix.isEmpty {
                    if let settingsSymbol = folderSymbols[folderName.lowercased()],
                        !settingsSymbol.isEmpty
                    {
                        newSuffix = settingsSymbol
                        enriched = true
                    }
                }

                if enriched {
                    if let index = rules.firstIndex(where: { $0.name == folderName }) {
                        rules.remove(at: index)
                    }

                    newPrefix = filterPrefixForBufferClearKeys(
                        newPrefix, folderName: existingRule.name)

                    let finalRule = CollectionRule(
                        name: existingRule.name,
                        suffix: newSuffix,
                        prefix: newPrefix,
                        description: existingRule.description,
                        triggerBias: existingRule.triggerBias,
                        prefixComment: existingRule.prefixComment,
                        suffixComment: existingRule.suffixComment,
                        triggerBiasComment: existingRule.triggerBiasComment,
                        descriptionComment: existingRule.descriptionComment
                    )
                    rules.append(finalRule)
                }
                continue
            }

            var effectiveSuffix: String? = nil
            var effectivePrefix: String = ""

            if let customSymbol = folderSymbols[folderName.lowercased()], !customSymbol.isEmpty {
                effectiveSuffix = customSymbol
            } else if !folderName.hasPrefix("_") {
                var defSymbol = settings.defaultSymbol
                if defSymbol.isEmpty {
                    defSymbol = ","
                }
                effectiveSuffix = defSymbol
            }

            // Issue: Global folder should not have an inferred prefix (G).
            if folderName.caseInsensitiveCompare("Global") == .orderedSame {
                effectivePrefix = ""
            } else if !folderName.hasPrefix("_") {
                effectivePrefix = FileUtilities.extractCapitalLetters(from: folderName).lowercased()
            }

            // Always create a rule even if suffix is nil (though suffix usually has default)
            // If suffix is nil here (e.g. underscore folder without config), we might default to empty or skip?
            // User request: Ensure Global is included.

            let finalSuffix = effectiveSuffix ?? ""

            effectivePrefix = filterPrefixForBufferClearKeys(
                effectivePrefix, folderName: folderName)

            let rule = CollectionRule(
                name: folderName,
                suffix: finalSuffix,
                prefix: effectivePrefix,
                description: nil,
                triggerBias: nil,
                prefixComment: nil, suffixComment: nil,
                triggerBiasComment: nil, descriptionComment: nil
            )
            rules.append(rule)
        }

        // Thread-safe write to cache
        ruleQueue.async(flags: .barrier) {
            self.cachedEffectiveRules = rules
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        logV("📐    [RuleManager] Recalculation took: \(String(format: "%.4f", duration))s")

        return rules
    }

    /// 캐시 무효화 (외부 설정 변경 시 호출)
    func invalidateEffectiveRulesCache() {
        ruleQueue.async(flags: .barrier) {
            self.cachedEffectiveRules = nil
        }
    }

    /// 캐시 초기화
    func clearCache() {
        ruleQueue.async(flags: .barrier) {
            self.cachedRules.removeAll()
            self.globalSettings = nil
            self.karabinerMappings.removeAll()
            self.enhancedKeyMappings.removeAll()
            self.cachedEffectiveRules = nil  // 캐시 초기화
            self.lastRuleFileModificationDate = nil  // Issue172: 캐시 초기화 시 날짜도 리셋
        }
    }

    /// ✅ Issue34: 모든 규칙 클리어 (일반 폴더 모드용)
    func clearRules() {
        clearCache()
        currentRuleFilePath = nil
        logD("📐    Issue34: 모든 규칙 클리어됨 (일반 폴더 모드)")
    }

    /// ✅ Issue34: 특정 경로의 규칙 파일 로드
    func loadRuleFile(at folderPath: String) -> Bool {
        // [Issue210] _rule.md 레거시 지원 제거 (로그 경고 방지)
        let ymlPath = folderPath + "/_rule.yml"

        if loadRules(from: ymlPath) {
            logV("📐    [RuleManager] _rule.yml 로드 성공")
            return true
        }

        logI("📐    ℹ️ [RuleManager] 규칙 파일 없음 (기본값 사용)")
        return false
    }

    /// 기본 규칙 반환 (규칙이 없는 경우)
    func getDefaultRule() -> CollectionRule {
        return CollectionRule(
            name: "default", suffix: "", prefix: "", description: nil, triggerBias: nil,
            prefixComment: nil, suffixComment: nil, triggerBiasComment: nil, descriptionComment: nil
        )
    }

    /// Karabiner 키 매핑 조회
    func getKarabinerMapping(for keyCode: UInt16) -> String? {
        return karabinerMappings[keyCode]
    }

    /// 모든 Karabiner 매핑 조회
    func getAllKarabinerMappings() -> [UInt16: String] {
        return karabinerMappings
    }

    /// Enhanced Key Mapping 조회 (키 이름으로)
    func getEnhancedKeyMapping(for keyName: String) -> EnhancedKeyMapping? {
        return enhancedKeyMappings[keyName]
    }

    /// 문자로 Enhanced Key Mapping 조회
    func getEnhancedKeyMapping(forCharacter character: String) -> EnhancedKeyMapping? {
        return enhancedKeyMappings.values.first { $0.character == character }
    }

    /// 모든 Enhanced Key Mapping 조회
    func getAllEnhancedKeyMappings() -> [String: EnhancedKeyMapping] {
        return enhancedKeyMappings
    }

    /// 키 조합(keyCode + modifiers)을 suffix 문자로 매핑
    func getSuffixCharacter(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
        // Issue 524: SharedKeyMap의 중앙 집중식 매핑 사용
        if let char = SharedKeyMap.getOptionKeyCharacter(keyCode: keyCode, modifiers: modifiers) {
            logV("📐    [SUFFIX_MAPPING] Option Key Mapped: '\(char)' (Code: \(keyCode))")
            return char
        }

        return nil
    }

    // MARK: - 시퀀스 매칭 (Issue 472: 스마트 버퍼 클리어)

    /// Issue 472: 현재 버퍼 + 키가 정의된 접두사나 접미사의 시작과 일치하는지 확인.
    /// 사용자가 유효한 시퀀스를 입력 중인 경우 클리어를 건너뛰는 "스마트 버퍼 클리어" 구현에 사용됨.
    func isPotentialSequence(currentBuffer: String, nextKeySpec: String) -> Bool {
        // (버퍼의 꼬리 + nextKeySpec)이 규칙 접두사/접미사의 시작과 일치하는지 확인해야 함.

        let candidate = currentBuffer + nextKeySpec

        // Issue 472 최적화: PSKeyManager의 통합 레지스트리 사용 (O(UniqueKeys) vs O(Rules))
        let (prefixes, suffixes) = PSKeyManager.shared.getAll()

        for prefix in prefixes {
            if checkPartialMatch(candidate: candidate, target: prefix) { return true }
        }

        for suffix in suffixes {
            if checkPartialMatch(candidate: candidate, target: suffix) { return true }
        }

        return false
    }

    private func checkPartialMatch(candidate: String, target: String) -> Bool {
        if target.isEmpty { return false }

        // 최적화: 의미 있는 일치 길이는 대상 길이를 초과할 수 없음.
        // 또한 후보보다 긴 길이를 확인할 필요도 없음.
        let maxLen = min(candidate.count, target.count)
        if maxLen == 0 { return false }

        // Check if candidate ends with a string that is a prefix of target.
        // Iterate backwards from maxLen down to 1 (longest match first)
        for len in (1...maxLen).reversed() {
            let suffix = candidate.suffix(len)
            if target.hasPrefix(suffix) {
                return true
            }
        }
        return false
    }

    /// 디버깅용: 로드된 규칙 출력
    func printLoadedRules() {
        ruleQueue.sync {
            logD("📐    === 로드된 규칙 정보 ===")
            if let global = globalSettings {
                logD("📐    Global - imported_date: \(global.importedDate)")
            }

            logD("📐    Collections: \(cachedRules.count)개")
            for (name, rule) in cachedRules {
                let triggerBiasInfo =
                    rule.triggerBias != nil ? ", trigger_bias=\(rule.triggerBias!)" : ""
                logD(
                    "📐    - \(name): prefix='\(rule.prefix)', suffix='\(rule.suffix)'\(triggerBiasInfo)"
                )
            }

            logD("📐    Karabiner Mappings: \(karabinerMappings.count)개")
            for (keyCode, character) in karabinerMappings {
                logD("📐    - keyCode \(keyCode): '\(character)'")
            }

            logD("📐    Enhanced Key Mappings: \(enhancedKeyMappings.count)개")
            for (keyName, mapping) in enhancedKeyMappings {
                logD(
                    "📐    - \(keyName): keyCode='\(mapping.keyCode)', char='\(mapping.character)', usage='\(mapping.usage)', misc='\(mapping.misc)'"
                )
            }
        }
    }

    /// 규칙 파일 저장 (Issue86)
    /// - Parameters:
    ///   - filePath: 저장할 파일 경로
    ///   - newCollections: 업데이트할 컬렉션 규칙 목록 (nil이면 기존 캐시 유지)
    /// - Returns: 저장 성공 여부
    func saveRules(to filePath: String? = nil, newCollections: [CollectionRule]? = nil) -> Bool {
        // Issue137: 로드에 실패한 상태에서는 저장을 차단하여 데이터 유실 방지
        // ruleQueue.sync 안에서 체크해야 안전하지만, atomic bool이나 lock이 필요.
        // 여기서는 전체를 sync barrier로 감쌉니다.

        return ruleQueue.sync(flags: .barrier) {
            guard isLoadedSuccessfully else {
                logE("📐    ❌ [SAVE_RULES] 로드되지 않은 상태에서 저장 시도 차단 (데이터 손실 방지)")
                return false
            }

            // 저장할 경로 결정
            let targetPath: String
            if let path = filePath {
                targetPath = path
            } else if let currentResult = currentRuleFilePath {
                targetPath = currentResult
            } else {
                logE("📐    ❌ [SAVE_RULES] 저장할 경로가 지정되지 않았습니다.")
                return false
            }

            // 컬렉션 업데이트
            if let collections = newCollections {
                // DEBUG: Trace Data Loss (Issue 314)
                if let bullets = collections.first(where: { $0.name == "_Bullets" }) {
                    logD("📐    [RuleManager.saveRules] ENTRY: Received '_Bullets'")
                    logD("📐 📜 - Prefix: '\(bullets.prefix)', Suffix: '\(bullets.suffix)'")
                }

                cachedRules.removeAll()
                for var rule in collections {
                    // Issue 515: Auto-wrap Single Shortcuts (e.g. keypad_comma -> {keypad_comma})
                    rule.prefix = normalizeKeySpec(rule.prefix)
                    rule.suffix = normalizeKeySpec(rule.suffix)

                    cachedRules[rule.name] = rule
                }
                logV("📐    [SAVE_RULES] 캐시 업데이트됨: \(collections.count)개 컬렉션")

                // Issue278: 변경된 규칙을 ShortcutMgr에 즉시 등록
                // (saveRules는 sync 큐 안에서 실행되므로 메인 스레드 비동기 호출 필요 - registerRulesToShortcutMgr 내부 처리됨)
                DispatchQueue.main.async {
                    self.registerRulesToShortcutMgr()
                }
            }

            // YAML 내용 생성
            var content = """
                # fSnippet Rule File (Auto-generated from Alfred Import & Settings)
                # Updated: \(Date().description)
                # Collections: \(cachedRules.count)

                global:
                  imported_date: "\(globalSettings?.importedDate ?? "Unknown")"
                  import_version: "2.1"
                  generator: "fSnippet Settings"

                """

            // Karabiner Mappings
            content += "\n# Karabiner keyboard mappings for special characters\n"
            content += "karabiner_mappings:\n"
            for (keyCode, character) in karabinerMappings {
                // Generating legacy format: keyCode: "char"
                // This ensures it is parsed correctly by the 'else if let keyCode = UInt16(keyString)' block
                content += "  \(keyCode): \"\(character)\"\n"
            }

            // Enhanced Key Mappings
            if !enhancedKeyMappings.isEmpty {
                content += "\nenhanced_key_mappings:\n"
                for (name, mapping) in enhancedKeyMappings {
                    content += "  \(name):\n"
                    content += "    key_code: \"\(mapping.keyCode)\"\n"
                    content += "    usage_page: \"\(mapping.usagePage)\"\n"
                    content += "    usage: \"\(mapping.usage)\"\n"
                    content += "    misc: \"\(mapping.misc)\"\n"
                    content += "    character: \"\(mapping.character)\"\n"
                    content +=
                        "    collections: [\(mapping.collections.map { "\"\($0)\"" }.joined(separator: ", "))]\n"
                    content += "    trigger_type: \"\(mapping.triggerType)\"\n"
                }
            }

            // Collections
            content += "\ncollections:\n"

            // Sort collections:
            // 1. _case1..._case34 numerically
            // 2. Other _ starting names alphabetically
            // 3. Normal names alphabetically
            let sortedCollections = cachedRules.values.sorted {
                let numA = self.extractCaseNumber(from: $0.name)
                let numB = self.extractCaseNumber(from: $1.name)

                // Case 1: Both are _caseN -> numerical sort
                if let nA = numA, let nB = numB {
                    if nA != nB { return nA < nB }
                }

                // Case 2: One is _caseN -> prioritized over ANYTHING else
                if numA != nil && numB == nil { return true }
                if numA == nil && numB != nil { return false }

                // Case 3: Standard special sorting (prefixing with _)
                let isASpecial = $0.name.hasPrefix("_")
                let isBSpecial = $1.name.hasPrefix("_")

                if isASpecial && !isBSpecial { return true }
                if !isASpecial && isBSpecial { return false }

                // Case 4: Alphabetical for the rest
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

            // Issue317: Default values for optimization
            let defaultTriggerKey = PreferencesManager.shared.string(
                forKey: "snippet_trigger_key", defaultValue: "=")

            for rule in sortedCollections {
                // Issue317_2: 불필요한 빈 규칙 저장 방지
                // 조건:
                // 1. 폴더명이 _로 시작하지 않음 (Normal Folder)
                // 2. prefix가 비어있음 ("")
                // 3. suffix가 비어있음 ("") (또는 기본값 이슈가 있을 수 있으나, 일단 비어있는지 확인)
                // 4. description이 없음
                // 5. prefixShortcut, suffixShortcut이 없음
                // 6. 주석이 하나도 없음
                //
                // 이 조건들을 모두 만족하면 의미 없는 데이터이므로 저장을 건너뛰m.

                let isNormalFolder = !rule.name.hasPrefix("_")
                // Issue317_2 Fix: Suffix가 비어있거나, 기본 트리거 키와 같아서 저장 시 생략되는 경우도 '없음'으로 간주
                let hasNoPrefix = rule.prefix.isEmpty
                let hasNoSuffix = rule.suffix.isEmpty || rule.suffix == defaultTriggerKey
                let hasNoDescription = (rule.description == nil || rule.description!.isEmpty)
                // Unified: Shortcuts are part of prefix/suffix. If they are empty, shortcuts are empty.
                let hasNoComments =
                    rule.prefixComment == nil && rule.suffixComment == nil
                    && rule.triggerBiasComment == nil && rule.descriptionComment == nil
                    && rule.triggerBias == nil

                // DEBUG: Trace _Bullets loss
                if rule.name == "_Bullets" || rule.name == "Bullets" {
                    logD("📐    [RuleManager.saveRules] Processing '\(rule.name)'")
                    logD(
                        "📐 📜 - isNormal: \(isNormalFolder), NoPrefix: \(hasNoPrefix), NoSuffix: \(hasNoSuffix)"
                    )
                    logD("📐 📜 - NoDesc: \(hasNoDescription), NoComments: \(hasNoComments)")
                    logD("📐 📜 - Prefix: '\(rule.prefix)', Suffix: '\(rule.suffix)'")
                }

                if isNormalFolder && hasNoPrefix && hasNoSuffix && hasNoDescription && hasNoComments
                {
                    logV("📐   ️ [RuleManager] 빈 규칙(Junk Rule) 저장 생략: '\(rule.name)'")
                    // Issue799: 캐시/파일 일관성 유지 — YAML에 안 쓰는 규칙은 캐시에서도 제거
                    cachedRules.removeValue(forKey: rule.name)
                    continue
                }

                content += "  - name: \"\(rule.name)\"\n"

                // Helper to strip braces for Clean Storage (Issue 459)
                func cleanSpec(_ s: String) -> String {
                    if s.hasPrefix("{") && s.hasSuffix("}") {
                        return String(s.dropFirst().dropLast())
                    }
                    return s
                }

                // Prefix writing
                let isPrefixEmpty = rule.prefix.isEmpty
                let shouldWritePrefix =
                    (!isPrefixEmpty) || (rule.prefixComment != nil)

                if shouldWritePrefix {
                    // If it's a shortcut (braced), we currently write it inside 'prefix' field.
                    // The requirement is "Unified". We store "{shortcut}" or "text".
                    // cleanSpec removes braces?
                    // Wait, if we use cleanSpec on "{shortcut}", we get "shortcut".
                    // If we write 'prefix: "shortcut"', does loadRules interpret it as text "shortcut" or shortcut?
                    // loadRules logic:
                    // if val.hasPrefix("{") -> shortcut.
                    // If we strip braces, we lose the info that it IS a shortcut?
                    // Issue 459 reference says "Clean Storage".
                    // But if we unified, we rely on braces to distinguish.
                    // If we strip string braces, we get "keypad_comma".
                    // Is "keypad_comma" a valid text prefix? Yes.
                    // So we MUST PRESERVE BRACES if we want to load it back as a shortcut.
                    // Unless loadRules has a heuristic (which it does not for generic keys).
                    // However, _rule.yml usually had explicit "prefixShortcut".
                    // Now we only have "prefix".
                    // If we write 'prefix: "{keypad_comma}"', loadRules will see braces and treat as shortcut.
                    // If we write 'prefix: "keypad_comma"', loadRules will treat as text prefix "keypad_comma".
                    // So cleanSpec is DANGEROUS for unified fields.
                    // We should ONLY use cleanSpec if we are writing to a dedicated shortcut field (which we are deleting).
                    // So for 'prefix' field, we write RAW value (with braces).

                    content += "    prefix: \"\(rule.prefix)\""
                    if let comment = rule.prefixComment { content += " #\(comment)" }
                    content += "\n"
                }

                // Suffix writing
                // Issue 452: Logic Update
                let isImplicitDefault = rule.suffix.isEmpty
                let shouldWriteSuffix =
                    (!isImplicitDefault) || (rule.suffixComment != nil)

                if shouldWriteSuffix {
                    content += "    suffix: \"\(rule.suffix)\""
                    if let comment = rule.suffixComment { content += " #\(comment)" }
                    content += "\n"
                }

                // Shortcuts are now integrated into prefix/suffix, so no separate fields.

                if let bias = rule.triggerBias {
                    content += "    trigger_bias: \(bias)"
                    if let comment = rule.triggerBiasComment { content += " #\(comment)" }
                    content += "\n"
                }
                if let desc = rule.description, !desc.isEmpty {
                    content += "    description: \"\(desc)\""
                    if let comment = rule.descriptionComment { content += " #\(comment)" }
                    content += "\n"
                }
            }

            // Issue 342: Prevent unnecessary writes to avoid triggering file watchers (reloading snippets)
            if let existingContent = try? String(contentsOfFile: targetPath, encoding: .utf8),
                existingContent == content
            {
                logD("📐   ️ [SAVE_RULES] 변경 사항 없음 - 파일 저장 건너뜀 (Reload 방지)")
                return true
            }

            // 파일 쓰기 - I/O 이므로 블로킹 시간이 길어질 수 있지만 안전을 위해 sync 블록 안에서 수행
            do {
                try content.write(toFile: targetPath, atomically: true, encoding: .utf8)
                logD("📐    [SAVE_RULES] 규칙 파일 저장 완료: \(targetPath)")

                // 저장 성공 시 현재 경로 업데이트 (새로 지정된 경우)
                if self.currentRuleFilePath != targetPath {
                    self.currentRuleFilePath = targetPath
                }

                return true
            } catch {
                logE("📐    ❌ [SAVE_RULES] 규칙 파일 저장 실패: \(error)")
                return false
            }
        }
    }

    /// 규칙 파일(_rule.yml) 존재 여부를 확인하고 없으면 복사 또는 앱 종료 (Issue211)
    func ensureRuleFile(at folderPath: String) {
        // [Issue199] Tilde(~) 수동 확장
        var expandedPath = folderPath
        if expandedPath.hasPrefix("~") {
            // Issue654: /Users/(userName) 하드코딩 제거 → FileManager API 사용 (path-rules.md 준수)
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expandedPath = expandedPath.replacingOccurrences(of: "~", with: homeDir)
        } else {
            expandedPath = (expandedPath as NSString).expandingTildeInPath
        }

        let ymlPath = expandedPath + "/_rule.yml"

        // 파일이 존재하면 리턴
        if fileManager.fileExists(atPath: ymlPath) {
            return
        }

        logW("📐    ⚠️ [RuleManager] _rule.yml 파일이 없음: \(ymlPath) -> 사용자 확인 요청")

        // UI 작업은 메인 스레드에서 (동기적으로 처리하여 이후 로직이 파일 생성 후 실행되도록 함)
        if Thread.isMainThread {
            self.showMissingRuleAlert(ymlPath: ymlPath)
        } else {
            DispatchQueue.main.sync {
                self.showMissingRuleAlert(ymlPath: ymlPath)
            }
        }
    }

    /// 파일 생성 알림 표시 및 처리
    private func showMissingRuleAlert(ymlPath: String) {
        let alert = NSAlert()
        alert.messageText = "규칙 파일이 없음"
        alert.informativeText =
            "스니펫 폴더에 규칙 파일(_rule.yml)이 존재하지 않습니다.\n필수 파일이므로 기본값으로 생성하시겠습니까?\n\n(아니오를 선택하면 앱이 종료됩니다.)\n\n경로: \(ymlPath)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "생성 (Create)")
        alert.addButton(withTitle: "종료 (Quit)")
        // Issue474_1: Add Select Folder button
        alert.addButton(withTitle: "기존 폴더 선택 (Select Folder)")

        // 앱을 맨 앞으로 (Alert이 가려지지 않도록)
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Yes: 번들에서 복사
            self.copyDefaultRuleFile(to: ymlPath)
        } else if response == .alertSecondButtonReturn {
            // No: 앱 종료
            logE("📐    ❌ [RuleManager] 사용자가 규칙 파일 생성을 거부하여 앱을 종료합니다.")
            NSApp.terminate(nil)
        } else if response == .alertThirdButtonReturn {
            // Select Folder: 기존 폴더 선택 및 경로 업데이트
            self.handleSelectExistingFolder()
        }
    }

    /// Issue474_1: 기존 폴더 선택 및 경로 업데이트 핸들러
    private func handleSelectExistingFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "규칙 파일(_rule.yml)이 포함된 기존 스니펫 폴더를 선택하세요."
        openPanel.prompt = "선택 (Select)"

        // 앱을 맨 앞으로 (OpenPanel이 가려지지 않도록)
        NSApp.activate(ignoringOtherApps: true)

        if openPanel.runModal() == .OK, let url = openPanel.url {
            let selectedPath = url.path
            logI("📐    [RuleManager] 사용자가 새 스니펫 폴더를 선택함: \(selectedPath)")

            // 1. Update config file with a relative path (Issue 669)
            let appRootPath = SettingsManager.shared.load().appRootPath
            let basePathToSave = SettingsManager.shared.makePathRelative(
                path: selectedPath, root: appRootPath)

            PreferencesManager.shared.batchUpdate { config in
                config["snippet_base_path"] = basePathToSave
            }

            // Fallback backward compatibility just in case
            UserDefaults.standard.set(basePathToSave, forKey: "snippet_base_path")
            UserDefaults.standard.synchronize()  // 즉시 저장 보장

            // 2. Alert & Restart
            let restartAlert = NSAlert()
            restartAlert.messageText = "설정 변경됨"
            restartAlert.informativeText =
                "스니펫 폴더 경로가 변경되었습니다:\n\(selectedPath)\n\n변경 사항을 적용하기 위해 앱을 재시작합니다."
            restartAlert.alertStyle = .informational
            restartAlert.addButton(withTitle: "재시작 (Restart)")
            restartAlert.runModal()

            // 3. Relaunch App using Relauncher utility
            Relauncher.relaunchApp()
        } else {
            // 취소 시 앱 종료 (설정이 없으면 진행 불가하므로)
            logW("📐    ⚠️ [RuleManager] 폴더 선택이 취소되었습니다. 앱을 종료합니다.")
            NSApp.terminate(nil)
        }
    }

    /// 번들에서 _rule.yml 복사
    private func copyDefaultRuleFile(to destinationPath: String) {
        guard let bundlePath = Bundle.main.path(forResource: "_rule", ofType: "yml") else {
            logE("📐    ❌ [RuleManager] 앱 번들 내에 _rule.yml 원본이 없습니다. (Issue212 확인 필요)")

            // 번들에도 없다면 비상용 기본 파일 생성
            createFallbackRuleFile(to: destinationPath)
            return
        }

        do {
            try fileManager.copyItem(atPath: bundlePath, toPath: destinationPath)
            logV("📐    [RuleManager] _rule.yml 파일 생성 완료: \(destinationPath)")
        } catch {
            logE("📐    ❌ [RuleManager] _rule.yml 복사 실패: \(error)")
            // 복사 실패 시에도 비상용 파일 시도? 아니면 재시도? 일단 에러 로그만.
        }
    }

    /// 번들 파일 누락 시 비상용 파일 생성
    private func createFallbackRuleFile(to destinationPath: String) {
        let content = """
            # fSnippet Rule File (Fallback)
            # Generated because bundle resource was missing.

            global:
              imported_date: "\(Date().description)"
              
            collections:
              - name: "default"
                prefix: ""
                suffix: ""
            """

        do {
            try content.write(toFile: destinationPath, atomically: true, encoding: .utf8)
            logW("📐    ⚠️ [RuleManager] 번들 리소스 누락으로 Fallback 규칙 파일 생성됨")
        } catch {
            logE("📐    ❌ [RuleManager] Fallback 파일 생성 실패: \(error)")
        }
    }

    /// Issue: _case1..._case34 형식에서 숫자 추출 (정렬용)
    private func extractCaseNumber(from name: String) -> Int? {
        // 인용부호 제거 (YAML 저장 시 " " 가 붙을 수 있음)
        let cleanName = name.replacingOccurrences(of: "\"", with: "")
        guard cleanName.hasPrefix("_case") else { return nil }
        let numberPart = cleanName.dropFirst(5)  // "_case" 는 5자
        if let number = Int(numberPart) {
            return number
        }
        return nil
    }
}
