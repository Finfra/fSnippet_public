import Foundation

/// 플레이스홀더 입력값 캐시 (Issue792: UserDefaults 기반)
/// _doc_design/snippet/placeholder-rules.md Phase 3 구현
class PlaceholderCache {
    static let shared = PlaceholderCache()

    private let defaults = UserDefaults.standard
    private let cacheKey = "fSnippet.placeholderCache"

    private init() {}

    // MARK: - Public API

    /// 플레이스홀더 이름에 대한 캐시된 값 조회
    func getValue(for name: String) -> String? {
        let cache = loadCache()
        return cache[name]
    }

    /// 플레이스홀더 입력값 저장
    func setValue(_ value: String, for name: String) {
        var cache = loadCache()
        // 빈 문자열은 저장하지 않음
        guard !value.isEmpty else {
            cache.removeValue(forKey: name)
            saveCache(cache)
            return
        }
        cache[name] = value
        saveCache(cache)
        logV("💾 [PlaceholderCache] 캐시 저장: '\(name)' = '\(value.prefix(30))...'")
    }

    /// 여러 결과를 한번에 캐시
    func saveResults(_ results: [PlaceholderResult]) {
        var cache = loadCache()
        for result in results {
            if !result.value.isEmpty {
                cache[result.name] = result.value
            }
        }
        saveCache(cache)
        logV("💾 [PlaceholderCache] 일괄 캐시 저장: \(results.count)개")
    }

    /// 전체 캐시 삭제
    func clearAll() {
        defaults.removeObject(forKey: cacheKey)
        logI("💾 [PlaceholderCache] 캐시 전체 삭제")
    }

    // MARK: - Private

    private func loadCache() -> [String: String] {
        return defaults.dictionary(forKey: cacheKey) as? [String: String] ?? [:]
    }

    private func saveCache(_ cache: [String: String]) {
        defaults.set(cache, forKey: cacheKey)
    }
}
