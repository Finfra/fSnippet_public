import Foundation

/// 텍스트 버퍼 관리 클래스 (메모리 최적화 버전)
/// 키 입력을 저장하고 검색어 추출 등을 담당
class TextBuffer {
    
    // MARK: - Properties
    
    private var buffer: [Character] = []  // String 대신 Character 배열 사용
    private let maxLength: Int
    private let queue = DispatchQueue(label: "textbuffer.sync", attributes: .concurrent)
    
    // MARK: - Initialization
    
    init(maxLength: Int = 100) {
        self.maxLength = maxLength
    }
    
    // MARK: - Public Methods
    
    /// 문자를 버퍼에 추가 (스레드 안전)
    /// Issue75: async → sync 변경하여 순서 보장
    func append(_ text: String) {
        queue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }



            // 문자들을 하나씩 추가
            self.buffer.append(contentsOf: text)

            // 버퍼 크기 제한 (더 효율적인 방식)
            if self.buffer.count > self.maxLength {
                let removeCount = self.buffer.count - self.maxLength
                self.buffer.removeFirst(removeCount)
            }

            DispatchQueue.main.async {
            }
        }
    }
    
    /// 마지막 문자 제거 (Backspace) - 스레드 안전
    func removeLast() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self.buffer.isEmpty else { return }
            
            self.buffer.removeLast()
            
            DispatchQueue.main.async {
                logTrace("📝 텍스트 버퍼에서 마지막 문자 제거됨. 현재 버퍼: '\(String(self.buffer))'")
            }
        }
    }
    
    /// 버퍼 완전 초기화 (스레드 안전)
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let previousBuffer = String(self.buffer)
            self.buffer.removeAll(keepingCapacity: true)  // 용량 유지하며 초기화
            
            DispatchQueue.main.async {
                logTrace("📝 텍스트 버퍼 초기화됨 - 이전: '\(previousBuffer)' → 현재: '\(String(self.buffer))'")
            }
        }
    }
    
    /// 버퍼 내용을 새로운 텍스트로 교체 (스레드 안전)
    /// PopupController 등 외부 입력 소스와 동기화할 때 사용
    func replaceBuffer(with text: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.buffer = Array(text)
            
            // 최대 길이 확인
            if self.buffer.count > self.maxLength {
                let removeCount = self.buffer.count - self.maxLength
                self.buffer.removeFirst(removeCount)
            }
            
            DispatchQueue.main.async {
                logTrace("📝 텍스트 버퍼 교체됨: '\(String(self.buffer))'")
            }
        }
    }
    
    /// 현재 버퍼 내용 반환 (스레드 안전)
    func getCurrentText() -> String {
        return queue.sync {
            return String(buffer)
        }
    }
    
    /// 버퍼가 특정 문자열로 끝나는지 확인 (스레드 안전)
    func hasSuffix(_ suffix: String) -> Bool {
        return queue.sync {
            let currentString = String(buffer)
            return currentString.hasSuffix(suffix)
        }
    }
    
    /// 버퍼에서 검색어 추출 (스레드 안전)
    /// BufferClearKeyManager에서 정의된 키 이후의 텍스트만 검색어로 사용
    func extractSearchTerm() -> String {
        return queue.sync {
            // BufferClearKeyManager에서 실제 버퍼 클리어 키 가져오기
            // AppSettingManager로 마이그레이션됨 (Issue 500)
            let clearKeys = AppSettingManager.shared.bufferClearKeys
            let separators = Set(clearKeys)
            
            // 뒤에서부터 분리자를 찾아서 그 이후 텍스트 추출
            var searchStartIndex = 0
            
            for (index, char) in buffer.enumerated().reversed() {
                if separators.contains(char) {
                    searchStartIndex = index + 1
                    break
                }
            }
            
            let searchChars = Array(buffer.suffix(from: searchStartIndex))
            let searchText = String(searchChars)
            let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                logTrace("📝 버퍼에서 검색어 추출: '\(trimmedText)' (전체 버퍼: '\(String(self.buffer))', 사용된 구분자: \(separators))")
            }
            
            return trimmedText
        }
    }
    
    /// abbreviation 후보들을 찾는 함수 (스레드 안전)
    func findAbbreviationCandidates(triggerKey: String) -> [String] {
        return queue.sync {
            var candidates: [String] = []

            let currentString = String(buffer)

            // Issue: 다중 문자 suffix 지원 (예: ",◊", ",,")
            // 모든 규칙의 suffix를 가져와서 가장 긴 매칭을 찾음
            // Issue: 다중 문자 suffix 지원 (예: ",◊", ",,")
            // PSKeyManager를 사용하여 모든 등록된 Suffix 확인 (RuleManager 의존성 제거)
            let allSuffixes = PSKeyManager.shared.getSuffixes()
            var matchedSuffix: String?
            var matchedSuffixLength = 0

            // 가장 긴 suffix를 찾음 (긴 것부터 우선 매칭)
            for suffix in allSuffixes {
                if !suffix.isEmpty && currentString.hasSuffix(suffix) && suffix.count > matchedSuffixLength {
                    matchedSuffix = suffix
                    matchedSuffixLength = suffix.count
                }
            }

            // 매칭된 suffix가 있으면 후보 생성
            if let suffix = matchedSuffix {
                let suffixChars = Array(suffix)
                let withoutSuffixBuffer = Array(buffer.dropLast(suffixChars.count))

                // BufferClearKeyManager에서 실제 버퍼 클리어 키 가져오기 (extractSearchTerm과 일치)
                let clearKeys = AppSettingManager.shared.bufferClearKeys
                let separators = Set(clearKeys)
                var searchStartIndex = 0

                // 뒤에서부터 분리자를 찾아서 그 이후 텍스트 추출
                for (index, char) in withoutSuffixBuffer.enumerated().reversed() {
                    if separators.contains(char) {
                        searchStartIndex = index + 1
                        break
                    }
                }

                let tokenChars = Array(withoutSuffixBuffer.suffix(from: searchStartIndex))
                let lastToken = String(tokenChars).trimmingCharacters(in: .whitespacesAndNewlines)

                if !lastToken.isEmpty {
                    // suffix를 포함한 완전한 abbreviation 후보 생성
                    let candidate = lastToken + suffix
                    candidates.append(candidate)

                    DispatchQueue.main.async {
                        logI("📝 [다중 suffix] 후보 발견: '\(candidate)' (suffix: '\(suffix)', 구분자: \(separators))")
                    }
                }
            }
            // Fallback: 기존 triggerKey 방식 (단일 문자 suffix)
            else if currentString.hasSuffix(triggerKey) {
                let triggerKeyChars = Array(triggerKey)
                let withoutTriggerBuffer = Array(buffer.dropLast(triggerKeyChars.count))

                let clearKeys = AppSettingManager.shared.bufferClearKeys
                let separators = Set(clearKeys)
                var searchStartIndex = 0

                for (index, char) in withoutTriggerBuffer.enumerated().reversed() {
                    if separators.contains(char) {
                        searchStartIndex = index + 1
                        break
                    }
                }

                let tokenChars = Array(withoutTriggerBuffer.suffix(from: searchStartIndex))
                let lastToken = String(tokenChars).trimmingCharacters(in: .whitespacesAndNewlines)

                if !lastToken.isEmpty {
                    // 1. 기본 전체 토큰 후보 (예: "bb/dev")
                    let candidate = lastToken + triggerKey
                    candidates.append(candidate)
                    
                    // 2. 암시적 경계 후보 (Implicit Boundary Candidates) (Issue393)
                    // "bb/dev" -> "/dev" (boundary: 'b' -> '/')
                    // "func(x)" -> "x" (boundary: '(' -> 'x')
                    // "status" -> "us" 방지 (boundary: 't' -> 'u'는 영숫자 -> 영숫자 => 무효)
                    
                    // lastToken의 suffix들을 검사
                    let tokenArray = Array(lastToken)
                    if tokenArray.count > 1 {
                        for i in 1..<tokenArray.count {
                            let boundaryChar = tokenArray[i-1]
                            let suffixStartChar = tokenArray[i]
                            
                            // 경계 확인 (Boundary Check)
                            let isBoundaryAlpha = boundaryChar.isLetter || boundaryChar.isNumber
                            let isSuffixStartAlpha = suffixStartChar.isLetter || suffixStartChar.isNumber
                            
                            // 유효한 경계:
                            // 1. 영숫자 -> 심볼 (예: "b" -> "/") => 접미사 "/dev" 허용
                            // 2. 심볼 -> 영숫자 (예: "(" -> "x") => 접미사 "x" 허용
                            // 3. 심볼 -> 심볼 (예: "/" -> "*") => 접미사 "*" 허용
                            // 무효: 영숫자 -> 영숫자 (예: "t" -> "u") => 건너뜀
                            
                            let isValidBoundary = !(isBoundaryAlpha && isSuffixStartAlpha)
                            
                            if isValidBoundary {
                                let suffix = String(tokenArray[i...])
                                let suffixCandidate = suffix + triggerKey
                                candidates.append(suffixCandidate)
                                
                                DispatchQueue.main.async {
                                    logV("📝 [Implicit Boundary] 후보 추가: '\(suffixCandidate)' (Boundary: '\(boundaryChar)'->'\(suffixStartChar)')")
                                }
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        logV("📝 abbreviation 후보 발견: '\(candidate)' (triggerKey: '\(triggerKey)') + Implicit Candidates")
                    }
                }
            }

            return Array(Set(candidates)).sorted { $0.count > $1.count }
        }
    }
    
    /// 빈 버퍼인지 확인 (스레드 안전)
    var isEmpty: Bool {
        return queue.sync {
            return buffer.isEmpty
        }
    }
    
    /// 버퍼 길이 반환 (스레드 안전)
    var count: Int {
        return queue.sync {
            return buffer.count
        }
    }
}

extension TextBuffer {
    var currentString: String {
        return getCurrentText()
    }
}
