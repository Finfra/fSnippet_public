import Foundation

/// PSKeyManager: 접두사(Prefix) & 접미사(Suffix) 키 관리자 (Issue 480)
/// 접두사, 접미사 및 트리거 키의 통합 레지스트리를 관리합니다.
/// 키가 접두사 또는 접미사/트리거로 작동하는지 확인하기 위한 O(1) 조회를 제공합니다.
class PSKeyManager {
    static let shared = PSKeyManager()

    // 직렬 큐를 사용한 스레드 안전 접근
    private let queue = DispatchQueue(
        label: "com.nowage.fSnippet.PSKeyManager", attributes: .concurrent)

    private var prefixes: Set<String> = []
    private var suffixes: Set<String> = []  // 트리거 키 포함

    // 필요한 경우 원시 vs 토큰화된 뷰를 위한 추가 Set,
    // 하지만 Issue 480은 단순한 isKey/isPrefix/isSuffix를 요청했습니다.
    // 여기에 저장된 키는 "유효 키"(토큰 또는 문자)라고 가정합니다.

    private init() {}

    // MARK: - 수정자 (Modifiers)

    /// 접두사 레지스트리에 키 목록 추가
    func addPrefix(_ keys: [String]) {
        queue.async(flags: .barrier) {
            let validKeys = keys.filter { !$0.isEmpty }
            self.prefixes.formUnion(validKeys)
            if !validKeys.isEmpty {
                logV("⛓️ [PSKeyManager] Added Prefixes: \(validKeys)")
            }
        }
    }

    /// 접미사 레지스트리에 키 목록 추가 (트리거 키 포함)
    func addSuffix(_ keys: [String]) {
        queue.async(flags: .barrier) {
            let validKeys = keys.filter { !$0.isEmpty }
            self.suffixes.formUnion(validKeys)
            if !validKeys.isEmpty {
                logV("⛓️ [PSKeyManager] Added Suffixes: \(validKeys)")
            }
        }
    }

    /// 모든 레지스트리 초기화
    func clear() {
        queue.async(flags: .barrier) {
            self.prefixes.removeAll()
            self.suffixes.removeAll()
            logI("⛓️ [PSKeyManager] Cleared all keys")
        }
    }

    // MARK: - 검사기 (Inspectors)

    /// 키가 접두사 또는 접미사 레지스트리에 존재하는지 확인
    func isKey(_ key: String) -> Bool {
        return queue.sync {
            return prefixes.contains(key) || suffixes.contains(key)
        }
    }

    /// 키가 접두사인지 확인
    func isPrefix(_ key: String) -> Bool {
        return queue.sync {
            return prefixes.contains(key)
        }
    }

    /// 키가 접미사(또는 트리거 키)인지 확인
    func isSuffix(_ key: String) -> Bool {
        return queue.sync {
            return suffixes.contains(key)
        }
    }

    // MARK: - 검색 (Retrieval)

    /// 모든 접두사 가져오기
    func getPrefixes() -> [String] {
        return queue.sync {
            return Array(prefixes).sorted()
        }
    }

    /// 모든 접미사 가져오기
    func getSuffixes() -> [String] {
        return queue.sync {
            return Array(suffixes).sorted()
        }
    }

    func getAll() -> (prefixes: [String], suffixes: [String]) {
        return queue.sync {
            return (Array(prefixes).sorted(), Array(suffixes).sorted())
        }
    }

    // MARK: - Key Resolution (Issue 478)

    /// Resolves a key (possibly containing internal tokens) to its effective string representation.
    /// e.g. "{keypad_comma}" -> ","
    // MARK: - Key Resolution (Issue 478)

    /// Resolves a key (possibly containing internal tokens) to its effective string representation.
    /// e.g. "{keypad_comma}" -> ","
    func resolveEffectiveKey(_ key: String) -> String {
        // 매퍼를 사용하여 중괄호 해제
        let content = SingleShortcutMapper.shared.unwrap(key)

        // 해제되었거나(또는 그냥 키이거나), 명시적 매핑을 확인합니다.
        // 이 로직은 이전 switch case를 모방하여 알려진 토큰에 대한 '유효 문자'를 캡처합니다.
        // ✅ Issue 522 & 513_4 수정: 특수 키 토큰에 대해 원시 토큰 형식을 반환하여 버퍼 매칭 보장
        // keypad_*, f1~f19, right_*, left_*, insert, delete_forward, home, end, pageup, pagedown 등
        let lowerContent = content.lowercased()
        if lowerContent.hasPrefix("keypad_")
            || lowerContent.hasPrefix("f") && lowerContent.count >= 2
            || lowerContent.hasPrefix("right_") || lowerContent.hasPrefix("left_")
            || ["insert", "delete_forward", "home", "end", "pageup", "pagedown", "caps_lock", "fn"]
                .contains(lowerContent)
        {
            return "{\(content)}"
        }

        switch content {
        case "semicolon": return ";"  // 세미콜론은 표준 키
        default: return content  // 일반 문자는 그대로 반환
        }
    }

    /// Issue 322: Suffix Sanitizer (Moved from AbbreviationMatcher)
    func sanitizeSuffix(_ suffix: String) -> String {
        let lowerSymbol = suffix.lowercased()
        if lowerSymbol == "numkey," || lowerSymbol.hasPrefix("numkey")
            || lowerSymbol.hasPrefix("numlock") || lowerSymbol.hasPrefix("numclear")
            || lowerSymbol.hasPrefix("numenter") || lowerSymbol.hasPrefix("right_")
            || lowerSymbol.hasPrefix("left_") || lowerSymbol.hasPrefix("caps")
        {
            return ""
        }
        return suffix
    }

    /// Checks if two keys are equivalent, handling aliases (e.g., "," vs "{keypad_comma}")
    func areKeysEquivalent(_ key1: String, _ key2: String) -> Bool {
        if key1 == key2 { return true }

        // Normalize alias pairs
        let pair = [key1, key2].sorted()
        let first = pair[0]
        let second = pair[1]

        // 🚨 Issue718: Strict matching for keypad_comma
        // Don't treat regular comma and keypad_comma as equivalent.
        // if first == "," && second == "{keypad_comma}" { return true }
        
        if first == "." && second == "{keypad_period}" { return true }
        if first == "\n" && second == "{keypad_enter}" { return true }

        // keypad_num_lock / Clear / 🔢 aliases
        let clearAliases: Set<String> = [
            "keypad_num_lock", "keypad_clear", "numlock", "clear", "🔢",
        ]
        if clearAliases.contains(key1.lowercased()) && clearAliases.contains(key2.lowercased()) {
            return true
        }

        // Check case-insensitive
        if key1.caseInsensitiveCompare(key2) == .orderedSame { return true }

        return false
    }

    /// 등록된 모든 접두사 및 접미사 요약 로그 (초기화 끝에서 한 번 호출)
    func logSummary() {
        queue.async {
            let p = Array(self.prefixes).sorted()
            let s = Array(self.suffixes).sorted()

            if !p.isEmpty {
                logI("⛓️ [PSKeyManager] Registered Prefixes (\(p.count)): \(p)")
            }
            if !s.isEmpty {
                logI("⛓️ [PSKeyManager] Registered Suffixes (\(s.count)): \(s)")
            }
        }
    }
}
