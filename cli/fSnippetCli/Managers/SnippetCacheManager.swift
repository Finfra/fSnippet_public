import Foundation

/// Snippet 검색 결과 캐시 관리자
class SnippetCacheManager {
    private var searchCache: [String: [SnippetEntry]] = [:]
    private let maxCacheSize: Int
    
    init(maxCacheSize: Int = 100) {
        self.maxCacheSize = maxCacheSize
    }
    
    /// 캐시에서 검색 결과 조회
    func getCachedResult(for term: String) -> [SnippetEntry]? {
        return searchCache[term]
    }
    
    /// 검색 결과를 캐시에 저장
    func cacheResult(_ entries: [SnippetEntry], for term: String) {
        // 캐시 크기 제한
        if searchCache.count >= maxCacheSize {
            clearCache()
        }
        
        searchCache[term] = entries
    }
    
    /// 특정 검색어의 캐시 무효화
    func invalidateCache(for term: String) {
        searchCache.removeValue(forKey: term)
    }
    
    /// 전체 캐시 지우기
    func clearCache() {
        searchCache.removeAll()
    }
    
    /// 캐시 통계 정보
    func getCacheStats() -> (entries: Int, maxSize: Int) {
        return (searchCache.count, maxCacheSize)
    }
    
    /// 캐시된 검색어 목록
    func getCachedTerms() -> [String] {
        return Array(searchCache.keys).sorted()
    }
}
