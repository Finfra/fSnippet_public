import Foundation
import SQLite3

/// 스니펫 사용 로그 모델 (SQLite 호환)
struct SnippetUsageLog {
    let id: Int64
    let abbreviation: String
    let snippetPath: String
    let usedAt: Date
}

/// 스니펫 사용 내역 관리 및 통계 생성 매니저 (SQLite 기반)
class SnippetUsageManager {
    static let shared = SnippetUsageManager()
    
    private let queue = DispatchQueue(label: "com.nowage.fSnippet.usageManager", qos: .utility)
    private var db: SQLiteDatabase?
    
    // DB 경로 관리
    private var statsDirectory: URL? {
        let settings = SettingsManager.shared.load()
        return URL(fileURLWithPath: settings.basePath)
    }
    
    private var dbURL: URL? {
        // Issue: DB를 _stats 폴더가 아닌 스니펫 루트(상위)에 바로 생성 (요청사항)
        return statsDirectory?.appendingPathComponent("stats.db")
    }
    
    private init() {
        // createStatsDirectoryIfNeeded() -> 루트는 이미 존재하므로 불필요
        openDatabase()
        createTables()
    }
    
    // private func createStatsDirectoryIfNeeded() { ... } // 제거됨
    
    private func openDatabase() {
        guard let dbPath = dbURL?.path else { return }
        do {
            db = try SQLiteDatabase(path: dbPath)
            logV("📊 [UsageManager] Stats DB opened at: \(dbPath)")
        } catch {
            logE("📊 ❌ [UsageManager] Failed to open Stats DB: \(error)")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        // 1. 새로운 히스토리 테이블 (snippet_history)
        // Issue 235: usage_history를 snippet_history로 이름 변경, folder_name/snippet_name 사용
        // Issue 235 Round 2: trigger_by 컬럼 추가
        let createHistoryTable = """
            CREATE TABLE IF NOT EXISTS snippet_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                folder_name TEXT NOT NULL,
                snippet_name TEXT NOT NULL,
                used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                trigger_by TEXT DEFAULT 'unknown'
            );
            CREATE INDEX IF NOT EXISTS idx_hist_name ON snippet_history(snippet_name);
            CREATE INDEX IF NOT EXISTS idx_hist_date ON snippet_history(used_at);
        """
        
        // 2. 영구 상위 10개 테이블 (snippet_top)
        // 앱 시작/종료 시 업데이트됨
        let createTopTable = """
            CREATE TABLE IF NOT EXISTS snippet_top (
                folder_name TEXT NOT NULL,
                snippet_name TEXT NOT NULL,
                usage_count INTEGER DEFAULT 0,
                last_used DATETIME NOT NULL,
                PRIMARY KEY (folder_name, snippet_name)
            );
        """
        
        do {
            try db.execute(sql: createHistoryTable)
            try db.execute(sql: createTopTable)
        } catch {
            logE("📊 ❌ [UsageManager] Failed to create tables: \(error)")
        }
    }
    
    // MARK: - Usage Logging
    
    // Issue 235: triggerMethod 추가 (popup, key, suffix)
    func logUsage(snippet: SnippetEntry, triggerMethod: String = "unknown") {
        queue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            // 파싱 로직
            let rawFileName = snippet.fileName
            let nameWithoutExt = (rawFileName as NSString).deletingPathExtension
            let snippetName = nameWithoutExt.components(separatedBy: "===").first ?? nameWithoutExt
            
            let sql = "INSERT INTO snippet_history (folder_name, snippet_name, trigger_by) VALUES ('\(self.sanitize(snippet.folderName))', '\(self.sanitize(snippetName))', '\(self.sanitize(triggerMethod))');"
            
            do {
                try db.execute(sql: sql)
                logV("📊 [UsageManager] Logged usage: [\(snippet.folderName)] \(snippetName) (via \(triggerMethod))")
            } catch {
                // 테이블에 컬럼이 없는 경우 (프로덕션에서는 마이그레이션이 필요하지만, 여기서는 DB가 있으면 에러 발생 가능)
                // 개발/디버깅용: 사용자가 stats.db를 삭제하거나 ALTER TABLE 로직을 추가할 수 있음.
                // 개발 환경 가정 > "ALTER TABLE snippet_history ADD COLUMN trigger_by TEXT DEFAULT 'unknown';" 폴백?
                // 이 작업의 단순화를 위해 DB 재생성 또는 새로운 시작이 괜찮다고 가정하거나 에러를 잡음.
                logE("📊 ❌ [UsageManager] Failed to log usage: \(error)")
                
                // 에러에 "no such column"이 포함된 경우 간단한 마이그레이션 시도
                if "\(error)".contains("no such column") {
                    try? db.execute(sql: "ALTER TABLE snippet_history ADD COLUMN trigger_by TEXT DEFAULT 'unknown';")
                    try? db.execute(sql: sql) // Retry
                }
            }
        }
    }
    
    // MARK: - Retrieval (Top 10)
    
    private var cachedTop10: [SnippetEntry]?
    
    func getTop10Snippets() -> [SnippetEntry] {
        if let cache = cachedTop10 {
            return cache
        }
        
        var results: [SnippetEntry] = []
        
        queue.sync {
            guard let db = self.db else { return }
            
            // Issue 235: snippet_top 테이블에서 조회 (영구 통계)
            let query = """
                SELECT folder_name, snippet_name, usage_count
                FROM snippet_top
                ORDER BY usage_count DESC, last_used DESC
                LIMIT 10;
            """
            
            do {
                guard let stmt = try db.prepare(sql: query) else { return }
                
                let allEntries = SnippetIndexManager.shared.entries
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let folderC = sqlite3_column_text(stmt, 0),
                       let nameC = sqlite3_column_text(stmt, 1) {
                        
                        let folderName = String(cString: folderC)
                        let snippetName = String(cString: nameC)
                        
                        // IndexManager에서 일치하는 항목 찾기
                        // "folder" + "name (before ===)"만 확인했으므로 엄격하게 일치시켜야 함.
                        // SnippetEntry에는 "nameBeforeTripleEquals" 필드가 없음.
                        // 반복하거나 필터링해야 함.
                        // 최적화: 폴더로 먼저 필터링.
                        
                        if let match = allEntries.first(where: {
                            if $0.folderName != folderName { return false }
                            let fName = ($0.fileName as NSString).deletingPathExtension
                            let parsedName = fName.components(separatedBy: "===").first ?? fName
                            return parsedName == snippetName
                        }) {
                            results.append(match)
                        }
                    }
                }
                sqlite3_finalize(stmt)
                
            } catch {
                logE("📊 ❌ [UsageManager] Fetch Top 10 failed: \(error)")
            }
        }
        
        self.cachedTop10 = results
        return results
    }
    
    /// 앱 종료/시작 시 호출 - 통계 집계 (snippet_history -> snippet_top)
    func aggregateTop10() {
         queue.async { [weak self] in
             guard let self = self, let db = self.db else { return }
             logV("📊 [UsageManager] Aggregating Top 10 stats...")
             
             // 1. Clear existing Top 10
             try? db.execute(sql: "DELETE FROM snippet_top;")
             
             // 2. Aggregate from history and insert
             // 상위 10개만 추출하여 저장
             let aggregationSQL = """
                 INSERT INTO snippet_top (folder_name, snippet_name, usage_count, last_used)
                 SELECT folder_name, snippet_name, COUNT(*) as cnt, MAX(used_at) as last
                 FROM snippet_history
                 GROUP BY folder_name, snippet_name
                 ORDER BY cnt DESC, last DESC
                 LIMIT 10;
             """
             
             do {
                 try db.execute(sql: aggregationSQL)
                 logV("📊 [UsageManager] Top 10 aggregation complete.")
                 
                // 3. 오래된 히스토리 정리 (유지보수)
                 let settings = SettingsManager.shared.load()
                 self.applyRetentionPolicy(usageDays: settings.statsRetentionUsageDays)
                 
                 // 4. Invalidate cache so next get retrieves fresh data
                 self.cachedTop10 = nil
                 
             } catch {
                 logE("📊 ❌ [UsageManager] Aggregation failed: \(error)")
             }
         }
    }
    
    /// 전체 통계 내역 삭제 (Issue 238)
    func deleteAllHistory() {
        queue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                try db.execute(sql: "DELETE FROM snippet_history;")
                try db.execute(sql: "DELETE FROM snippet_top;")
                self.cachedTop10 = nil
                logI("📊 [UsageManager] All statistics history deleted.")
            } catch {
                logE("📊 ❌ [UsageManager] Failed to delete statistics: \(error)")
            }
        }
    }
    
    private func applyRetentionPolicy(usageDays: Int) {
        guard let db = db else { return }
        
        // 1. 사용일 기반 삭제 (Issue 376)
        // usageDays일 동안의 데이터만 유지. 즉, 최근 usageDays개의 ' Distinct Date' 만 남김
        if usageDays > 0 {
            // Cutoff Date 구하기: 최근 N번째 사용일
            // "SELECT DISTINCT date(used_at) as d FROM snippet_history ORDER BY d DESC LIMIT 1 OFFSET (usageDays - 1)"
            
            // 더 안전한 쿼리: 상위 N개 날짜 중 가장 작은 날짜 (LIMIT N)
            let findCutoffSQL = """
                SELECT MIN(usage_day) FROM (
                    SELECT DISTINCT date(used_at) as usage_day 
                    FROM snippet_history 
                    ORDER BY usage_day DESC 
                    LIMIT \(usageDays)
                );
            """
            
            do {
                var cutoffDateString: String? = nil
                guard let stmt = try db.prepare(sql: findCutoffSQL) else { return }
                
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let text = sqlite3_column_text(stmt, 0) {
                        cutoffDateString = String(cString: text)
                    }
                }
                sqlite3_finalize(stmt)
                
                if let cutoff = cutoffDateString {
                    // cutoff 날짜보다 이전(작은) 날짜의 데이터 삭제
                    // date(used_at) < cutoff
                    let deleteSQL = "DELETE FROM snippet_history WHERE date(used_at) < '\(cutoff)';"
                    try db.execute(sql: deleteSQL)
                    logV("📊 [UsageManager] Retention applied: Kept last \(usageDays) usage days (Cutoff: \(cutoff))")
                } else {
                    // 데이터가 N일치도 안됨 -> 삭제 안함
                    logV("📊 [UsageManager] Retention skipped: Not enough usage days yet.")
                }
                
            } catch {
                logE("📊 ❌ [UsageManager] Failed to apply retention policy: \(error)")
            }
        }
        
        // 2. 최대 개수 기반 삭제 (기존 유지, 과도한 데이터 방지)
        let cleanup = """
            DELETE FROM snippet_history 
            WHERE id NOT IN (
                SELECT id FROM snippet_history 
                ORDER BY used_at DESC 
                LIMIT 20000
            );
        """
        try? db.execute(sql: cleanup)
    }
    
    // MARK: - API 조회

    /// 상위 N개 사용 통계 조회 (API용)
    func getTopStats(limit: Int = 10) -> [(folderName: String, snippetName: String, usageCount: Int, lastUsed: String)] {
        var results: [(String, String, Int, String)] = []
        queue.sync {
            guard let db = self.db else { return }
            let query = """
                SELECT folder_name, snippet_name, usage_count, last_used
                FROM snippet_top
                ORDER BY usage_count DESC, last_used DESC
                LIMIT \(limit);
            """
            do {
                guard let stmt = try db.prepare(sql: query) else { return }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let folder = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                    let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                    let count = Int(sqlite3_column_int(stmt, 2))
                    let lastUsed = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                    results.append((folder, name, count, lastUsed))
                }
                sqlite3_finalize(stmt)
            } catch {
                logE("📊 ❌ [UsageManager] getTopStats failed: \(error)")
            }
        }
        return results
    }

    /// 사용 이력 조회 (API용)
    func getHistory(limit: Int = 100, offset: Int = 0, from: String? = nil, to: String? = nil) -> (items: [(id: Int64, folderName: String, snippetName: String, usedAt: String, triggerBy: String)], total: Int) {
        var results: [(Int64, String, String, String, String)] = []
        var total = 0
        queue.sync {
            guard let db = self.db else { return }

            // total count
            var countSQL = "SELECT COUNT(*) FROM snippet_history"
            var conditions: [String] = []
            if let from = from { conditions.append("used_at >= '\(self.sanitize(from))'") }
            if let to = to { conditions.append("used_at <= '\(self.sanitize(to))'") }
            if !conditions.isEmpty { countSQL += " WHERE " + conditions.joined(separator: " AND ") }

            if let stmt = try? db.prepare(sql: countSQL) {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    total = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }

            // data query
            var query = "SELECT id, folder_name, snippet_name, used_at, trigger_by FROM snippet_history"
            if !conditions.isEmpty { query += " WHERE " + conditions.joined(separator: " AND ") }
            query += " ORDER BY used_at DESC LIMIT \(limit) OFFSET \(offset)"

            do {
                guard let stmt = try db.prepare(sql: query) else { return }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    let folder = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                    let name = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                    let usedAt = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                    let triggerBy = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "unknown"
                    results.append((id, folder, name, usedAt, triggerBy))
                }
                sqlite3_finalize(stmt)
            } catch {
                logE("📊 ❌ [UsageManager] getHistory failed: \(error)")
            }
        }
        return (results, total)
    }

    private func sanitize(_ string: String) -> String {
        return string.replacingOccurrences(of: "'", with: "''")
    }
}
