import Foundation

/// Suffix 부분 일치 로직을 담당하는 매처
/// KeyEventMonitor에서 RuleManager에 대한 직접 의존성을 제거하고,
/// "Buffer Clear Key"가 Suffix의 일부일 때 버퍼 초기화를 방지하는 "Guard" 역할을 수행함.
class SuffixMatcher {
    static let shared = SuffixMatcher()
    
    private init() {}
    
    /// 입력된 키가 특정 룰의 Suffix 시작 부분과 일치하는지 확인 (Suffix Guard)
    /// - Parameters:
    ///   - key: 입력된 키 문자 (예: "," or "Tab")
    ///   - buffer: 현재 텍스트 버퍼
    /// - Returns: True면 Suffix의 일부일 가능성이 있으므로 Buffer Clear를 방지해야 함
    func isPartialSuffixMatch(key: String, buffer: String) -> Bool {
        // Issue 480: PSKeyManager를 사용하여 접미사(Trigger Keys 포함)에 O(1)로 접근
        let suffixes = PSKeyManager.shared.getSuffixes()
        
        for suffix in suffixes {
            // if suffix.isEmpty { continue } // PSKeyManager에서 이미 빈 값 필터링됨
            
            // 1. Suffix가 입력된 키로 시작하는지 확인 (가장 단순한 케이스)
            // 예: Suffix가 ",,"이고 입력키가 ","인 경우
            // Issue 440: 중괄호로 감싸진 접미사 처리 (예: {keypad_comma})
            // 접미사가 {}로 감싸져 있는 경우, 일반적으로 원시 문자 입력(예: ,)이 아니라
            // Trigger Key의 표시 이름(예: keypad_comma)과 비교합니다.
            // 하지만 여기서 전달된 'key'는 보통 displayCharacter입니다.
            // displayCharacter가 "keypad_comma"이고 접미사가 "{keypad_comma}"인 경우, hasPrefix는 실패합니다.
            
            var effectiveSuffix = suffix
            if effectiveSuffix.hasPrefix("{") && effectiveSuffix.hasSuffix("}") {
                effectiveSuffix = String(effectiveSuffix.dropFirst().dropLast())
            }

            if suffix.hasPrefix(key) || effectiveSuffix == key {
                // 추가 검증: 버퍼 상황 고려
                // 이미 버퍼에 ","가 있고 Suffix가 ",,"라면, 두 번째 "," 입력 시에는
                // 이것이 Suffix 완성을 위한 입력인지 확인해야 함.
                // 하지만 여기서는 "Buffer Clear 방지"가 목적이므로,
                // Suffix의 첫 글자와 일치하기만 해도 일단 True를 반환하여 보수적으로 처리.
                return true
            }
            
            // 2. 버퍼의 뒷부분 + 입력키가 Suffix의 앞부분과 일치하는지 확인 (고급)
            // 예: Suffix가 "abcd"이고 버퍼가 "..ab", 입력키가 "c"인 경우 -> "abc"는 "abcd"의 prefix
            let potentialSuffix = buffer + key
            // 버퍼가 너무 길 수 있으므로 Suffix 길이만큼만 뒤에서 자름
            let suffixLength = suffix.count
            if potentialSuffix.count > suffixLength {
                 // 최적화: 전체 버퍼를 다 볼 필요 없이 뒷부분만 확인
                 // (정확한 로직은 복잡할 수 있으니 1번 단순 케이스로 충분한지 고민)
            }
        }
        
        return false
    }
}
