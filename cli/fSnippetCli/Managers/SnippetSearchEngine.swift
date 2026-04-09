import Foundation

// MARK: - Trie 구조 구현

/// Trie 노드 클래스 - 빠른 prefix 검색을 위한 트리 구조
private class TrieNode {
    var children: [Character: TrieNode] = [:]
    var entries: [SnippetEntry] = []
    var isEndOfWord: Bool = false

    func insert(_ abbreviation: String, entry: SnippetEntry) {
        var current = self

        for char in abbreviation.lowercased() {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }

        current.isEndOfWord = true
        current.entries.append(entry)
    }

    func search(prefix: String) -> [SnippetEntry] {
        var current = self

        // prefix까지 이동
        for char in prefix.lowercased() {
            guard let nextNode = current.children[char] else {
                return []
            }
            current = nextNode
        }

        // prefix부터 모든 하위 노드의 entries 수집
        return collectAllEntries(from: current)
    }

    private func collectAllEntries(from node: TrieNode) -> [SnippetEntry] {
        var results: [SnippetEntry] = []

        // 현재 노드의 entries 추가
        results.append(contentsOf: node.entries)

        // 자식 노드들 재귀적으로 탐색
        for (_, childNode) in node.children {
            results.append(contentsOf: collectAllEntries(from: childNode))
        }

        return results
    }
}

/// 고성능 Snippet 검색 엔진 클래스 (Trie 구조 사용)
class SnippetSearchEngine {
    // 기존 인덱스들
    private var abbreviationIndex: [String: [SnippetEntry]] = [:]
    private var folderIndex: [String: [SnippetEntry]] = [:]
    private var tagIndex: [String: [SnippetEntry]] = [:]

    // Trie 구조 인덱스 (성능 최적화)
    private var abbreviationTrie: TrieNode = TrieNode()
    private let searchQueue = DispatchQueue(label: "snippet.search", qos: .userInitiated, attributes: .concurrent)

    /// 인덱스 구축 (Trie 구조 포함)
    /// Issue722: 모든 인덱스 초기화와 구축을 barrier 블록 안에서 수행하여 스레드 안전성 보장
    func buildIndices(from entries: [SnippetEntry]) {
        logV("🛁 스니펫 검색 인덱스 구축 시작 - 총 \(entries.count)개 항목")

        // barrier로 모든 읽기/쓰기를 직렬화하여 data race 방지
        searchQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // 기존 인덱스 초기화 (barrier 안에서 안전하게 수행)
            self.abbreviationIndex.removeAll()
            self.folderIndex.removeAll()
            self.tagIndex.removeAll()
            self.abbreviationTrie = TrieNode()

            for entry in entries {
                // abbreviation Trie 인덱스 (O(log n) 검색 지원)
                self.abbreviationTrie.insert(entry.abbreviation, entry: entry)

                // abbreviation 해시 인덱스 (기존 호환성)
                let abbrevKey = entry.abbreviation.lowercased()
                self.abbreviationIndex[abbrevKey, default: []].append(entry)

                // 폴더 인덱스
                let folderKey = entry.folderName.lowercased()
                self.folderIndex[folderKey, default: []].append(entry)

                // 태그 인덱스
                for tag in entry.tags {
                    self.tagIndex[tag, default: []].append(entry)
                }
            }

            DispatchQueue.main.async {
                logV("🛁 스니펫 검색 인덱스 구축 완료 - Trie 구조 포함")
            }
        }
    }

    /// 고급 검색 기능 (Scope 지원)
    func search(term: String, entries: [SnippetEntry], scope: PopupSearchScope = .content, maxResults: Int = 50) -> [SnippetEntry] {
        let results = searchQueue.sync {
            performSearch(term: term, entries: entries, scope: scope)
        }
        let sorted = results.sorted { $0.relevanceScore(for: term) > $1.relevanceScore(for: term) }
        return Array(sorted.prefix(maxResults))
    }

    /// 접두사로 검색 (Trie 구조 사용 - O(log n) 성능)
    func findByPrefix(_ prefix: String, entries: [SnippetEntry]) -> [SnippetEntry] {
        guard !prefix.isEmpty else { return [] }

        // searchQueue.sync로 읽기 보호 (concurrent read 허용, barrier write와 직렬화)
        let trieResults = searchQueue.sync {
            abbreviationTrie.search(prefix: prefix)
        }

        // 중복 제거 및 정렬
        let uniqueResults = removeDuplicates(trieResults)
        // 🎯 길이가 긴 것을 먼저 매칭하도록 수정 (예: kl이 l보다 먼저 매칭)
        return uniqueResults.sorted {
            if $0.abbreviation.count != $1.abbreviation.count {
                return $0.abbreviation.count > $1.abbreviation.count  // 길이가 긴 것 우선
            }
            return $0.abbreviation < $1.abbreviation  // 길이가 같으면 알파벳 순
        }
    }

    /// 고성능 prefix 검색 (비동기)
    func findByPrefixAsync(_ prefix: String, completion: @escaping ([SnippetEntry]) -> Void) {
        guard !prefix.isEmpty else {
            completion([])
            return
        }

        searchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let results = self.abbreviationTrie.search(prefix: prefix)
            let uniqueResults = self.removeDuplicates(results)
            // 🎯 길이가 긴 것을 먼저 매칭하도록 수정 (예: kl이 l보다 먼저 매칭)
            let sortedResults = uniqueResults.sorted {
                if $0.abbreviation.count != $1.abbreviation.count {
                    return $0.abbreviation.count > $1.abbreviation.count  // 길이가 긴 것 우선
                }
                return $0.abbreviation < $1.abbreviation  // 길이가 같으면 알파벳 순
            }

            DispatchQueue.main.async {
                completion(sortedResults)
            }
        }
    }

    /// 폴더별 Snippet 검색
    func findByFolder(_ folderName: String) -> [SnippetEntry] {
        return searchQueue.sync {
            folderIndex[folderName.lowercased()] ?? []
        }
    }

    /// 태그별 Snippet 검색
    func findByTag(_ tag: String) -> [SnippetEntry] {
        return searchQueue.sync {
            tagIndex[tag.lowercased()] ?? []
        }
    }

    /// 활성 Snippet만 검색
    func findActiveSnippets(from entries: [SnippetEntry]) -> [SnippetEntry] {
        return entries.filter { $0.isActive }
    }

    // MARK: - Private Methods

    /// 인덱스 기반 검색 (searchQueue 내에서 호출되어야 함)
    private func performSearch(term: String, entries: [SnippetEntry], scope: PopupSearchScope) -> [SnippetEntry] {
        let lowerTerm = term.lowercased()
        var results: [SnippetEntry] = []

        // 1. Keyword (Abbreviation) 검색 - 모든 모드 공통
        for (key, indexEntries) in abbreviationIndex {
            if key.contains(lowerTerm) {
                results.append(contentsOf: indexEntries)
            }
        }

        // Abbreviation only 모드면 여기서 반환 (이 함수가 호출될 일은 드물지만 처리)
        if scope == .abbreviation {
            return removeDuplicates(results)
        }

        // 2. Name Scope (Keyword + Name + Folder + Tag + Desc)
        // 태그 검색
        for (tag, indexEntries) in tagIndex {
            if tag.contains(lowerTerm) {
                results.append(contentsOf: indexEntries)
            }
        }

        // 폴더 검색
        for (folder, indexEntries) in folderIndex {
            if folder.contains(lowerTerm) {
                results.append(contentsOf: indexEntries)
            }
        }

        // 설명 및 파일명 검색
        for entry in entries {
            let lowerDesc = entry.description?.lowercased() ?? ""
            let lowerSnippetDesc = entry.snippetDescription.lowercased()

            if lowerDesc.contains(lowerTerm) || lowerSnippetDesc.contains(lowerTerm) {
                results.append(entry)
            }

            // 3. Content Scope 추가 검색
            if scope == .content {
                let lowerContent = entry.content.lowercased()
                if lowerContent.contains(lowerTerm) {
                    results.append(entry)
                }
            }
        }

        return removeDuplicates(results)
    }

    /// 중복 제거 최적화 메서드
    private func removeDuplicates(_ entries: [SnippetEntry]) -> [SnippetEntry] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard !seen.contains(entry.id) else { return nil }
            seen.insert(entry.id)
            return entry
        }
    }
}
