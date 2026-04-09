import Foundation

/// 리팩토링된 Snippet 인덱스 관리 시스템 - 코디네이터 역할
class SnippetIndexManager {
    static let shared = SnippetIndexManager()

    // MARK: - 속성

    private(set) var entries: [SnippetEntry] = []
    private(set) var snippetMap: [String: String] = [:]  // 기존 호환성 유지

    // 분리된 컴포넌트들
    private let indexBuilder = SnippetIndexBuilder()
    private let searchEngine = SnippetSearchEngine()
    private let cacheManager = SnippetCacheManager()

    private let indexQueue = DispatchQueue(label: "snippet.index", qos: .utility)

    // MARK: - 공개 메서드

    /// 기존 호환성을 위한 로딩 메서드
    func loadSnippets(basePath: String) {
        indexQueue.async { [weak self] in
            self?._loadSnippets(basePath: basePath)
        }
    }

    /// Snippet 인덱스 전체 재구성
    func rebuildIndex(basePath: String, completion: @escaping (Int) -> Void) {
        indexQueue.async { [weak self] in
            guard let self = self else { return }

            self.clearIndex()
            self._loadSnippets(basePath: basePath)

            DispatchQueue.main.async {
                completion(self.entries.count)
            }
        }
    }

    /// abbreviation 키로 검색 (기존 호환성)
    func lookup(key: String) -> String? {
        return snippetMap[key]
    }

    /// 고급 검색 기능 (캐시 활용)
    func search(term: String, scope: PopupSearchScope = .content, maxResults: Int = 50)
        -> [SnippetEntry]
    {
        // ✅ Issue 243_4 & 243_5: 오래된 결과를 방지하기 위해 캐시 키에 scope 포함
        let cacheKey = "\(term)|\(scope.rawValue)"

        // 캐시 확인
        if let cached = cacheManager.getCachedResult(for: cacheKey) {
            return Array(cached.prefix(maxResults))
        }

        // 새로운 검색 수행
        let results = searchEngine.search(
            term: term, entries: entries, scope: scope, maxResults: maxResults)

        // 결과 캐시
        cacheManager.cacheResult(results, for: cacheKey)

        return results
    }

    /// 접두사로 검색
    func findByPrefix(_ prefix: String) -> [SnippetEntry] {
        return searchEngine.findByPrefix(prefix, entries: entries)
    }

    /// 폴더별 Snippet 검색
    func findByFolder(_ folderName: String) -> [SnippetEntry] {
        return searchEngine.findByFolder(folderName)
    }

    /// 태그별 Snippet 검색
    func findByTag(_ tag: String) -> [SnippetEntry] {
        return searchEngine.findByTag(tag)
    }

    /// 활성 Snippet만 검색
    func findActiveSnippets() -> [SnippetEntry] {
        return searchEngine.findActiveSnippets(from: entries)
    }

    /// 인덱스 통계 정보
    func getIndexStats() -> (total: Int, active: Int, cache: (entries: Int, maxSize: Int)) {
        let activeCount = searchEngine.findActiveSnippets(from: entries).count
        let cacheStats = cacheManager.getCacheStats()
        return (entries.count, activeCount, cacheStats)
    }

    /// 폴더명과 스니펫 이름(Abbreviation)으로 스니펫 검색 (Nested Snippet용)
    func findSnippet(folder: String, name: String) -> SnippetEntry? {
        let targetFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return entries.first { entry in
            // 폴더명 불일치 시 조기 리턴
            guard entry.folderName.lowercased() == targetFolder else { return false }

            // 1. 파일명(확장자 제외) 일치 확인 (가장 일반적인 경우: {{Exam/b}} -> b.txt)
            let fileNameWithoutExt = (entry.fileName as NSString).deletingPathExtension.lowercased()
            if fileNameWithoutExt == targetName { return true }

            // 2. 파일명 전체 일치 확인 (확장자 포함: {{Exam/b.txt}})
            if entry.fileName.lowercased() == targetName { return true }

            // 3. Abbreviation 일치 확인 (기존 호환성)
            if entry.abbreviation.lowercased() == targetName { return true }

            // 4. 스니펫 이름(Description) 일치 확인 (사용자 친화적: {{Folder/Name}})
            if entry.snippetDescription.lowercased() == targetName { return true }

            return false
        }
    }

    // MARK: - 증분 로딩 기능 (Incremental Update)
    
    /// 개별 파일 추가 및 수정 시 호출 (O(N) 리빌드 방지)
    func addOrUpdateEntry(fileURL: URL, folderName: String) {
        indexQueue.async { [weak self] in
            guard let self = self else { return }
            
            var folderDesc: String? = nil
            let folderURL = fileURL.deletingLastPathComponent()
            let readmeURL = folderURL.appendingPathComponent("README.md")
            if FileManager.default.fileExists(atPath: readmeURL.path) {
                folderDesc = self.indexBuilder.extractDescriptionFromReadme(readmeURL)
            }
            
            if let newEntry = self.indexBuilder.createSnippetEntry(fileURL: fileURL, folderName: folderName, folderDescription: folderDesc) {
                if let idx = self.entries.firstIndex(where: { $0.filePath.path == fileURL.path }) {
                    let oldEntry = self.entries[idx]
                    if oldEntry.abbreviation != newEntry.abbreviation {
                        if self.snippetMap[oldEntry.abbreviation] == oldEntry.filePath.path {
                            self.snippetMap.removeValue(forKey: oldEntry.abbreviation)
                        }
                    }
                    self.entries[idx] = newEntry
                } else {
                    self.entries.append(newEntry)
                }
                
                self.snippetMap[newEntry.abbreviation] = newEntry.filePath.path
                self.searchEngine.buildIndices(from: self.entries)
                self.cacheManager.clearCache()
                logV("📌 [SnippetIndexManager] 스니펫 증분 갱신: \(fileURL.lastPathComponent)")
            } else {
                // 파싱에 실패한 경우 기존 인덱스에서 제거 시도 (제외 항목으로 변경된 경우 대응)
                self._removeEntrySync(fileURL: fileURL)
            }
        }
    }
    
    /// 개별 파일 삭제 시 호출
    func removeEntry(fileURL: URL) {
        indexQueue.async { [weak self] in
            self?._removeEntrySync(fileURL: fileURL)
        }
    }
    
    private func _removeEntrySync(fileURL: URL) {
        if let idx = self.entries.firstIndex(where: { $0.filePath.path == fileURL.path }) {
            let oldEntry = self.entries.remove(at: idx)
            if self.snippetMap[oldEntry.abbreviation] == oldEntry.filePath.path {
                self.snippetMap.removeValue(forKey: oldEntry.abbreviation)
            }
            self.searchEngine.buildIndices(from: self.entries)
            self.cacheManager.clearCache()
            logV("📌 [SnippetIndexManager] 스니펫 증분 삭제: \(fileURL.lastPathComponent)")
        }
    }

    // MARK: - 비공개 메서드

    private func _loadSnippets(basePath: String) {
        // 인덱스 빌더를 사용하여 엔트리 생성
        let newEntries = indexBuilder.buildEntries(from: basePath)

        // 결과 적용
        self.entries = newEntries

        // 기존 호환성을 위한 매핑 구축
        buildSnippetMap()

        // 검색 엔진 인덱스 구축
        searchEngine.buildIndices(from: entries)

        // 캐시 초기화
        cacheManager.clearCache()

        logV("📌 스니펫 로딩 완료: \(entries.count)개")
    }

    private func buildSnippetMap() {
        snippetMap.removeAll()
        for entry in entries {
            snippetMap[entry.abbreviation] = entry.filePath.path
        }
    }

    func clearIndex() {
        entries.removeAll()
        snippetMap.removeAll()
        cacheManager.clearCache()
    }
}
