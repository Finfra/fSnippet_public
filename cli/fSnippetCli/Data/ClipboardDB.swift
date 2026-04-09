import Foundation
import SQLite3

/// 클립보드 항목 모델
struct ClipboardItem {
    let id: Int64?
    let createdAt: Int64
    let kind: String // plain_text, image, file_list, other
    let text: String?
    let blobPath: String?
    let filelistJson: String?
    let uti: String?
    let sizeBytes: Int64?
    let hash: String?
    let pinned: Int // 0 or 1
    let appBundle: String? // CL060: 소스 앱 번들 ID
}

/// Clipboard History DB 초기화 및 경로 관리 (CL006)
class ClipboardDB {
    static let shared = ClipboardDB()
    
    // CL079: SQLite를 위한 스레드 안전성 보장
    private let dbQueue = DispatchQueue(label: "com.nowage.fSnippet.dbQueue")

    private var db: SQLiteDatabase?

    // 경로: [SnippetRootParent]/clipboard/clipboard.db
    private var clipboardDirURL: URL? {
        let settings = SettingsManager.shared.load()
        // snippets 폴더의 상위 폴더에 clipboard 폴더 생성
        return URL(fileURLWithPath: settings.basePath).deletingLastPathComponent().appendingPathComponent("clipboard")
    }

    private var blobsDirURL: URL? {
        return clipboardDirURL?.appendingPathComponent("blobs")
    }

    private var dbURL: URL? {
        return clipboardDirURL?.appendingPathComponent("clipboard.db")
    }

    private init() {
        ensureDirectories()
        open()
        applyPragmas()
        createSchemaIfNeeded()
    }

    private func ensureDirectories() {
        let fm = FileManager.default
        if let clip = clipboardDirURL {
            try? fm.createDirectory(at: clip, withIntermediateDirectories: true)
        }
        if let blobs = blobsDirURL {
            try? fm.createDirectory(at: blobs, withIntermediateDirectories: true)
        }
    }

    private func open() {
        guard let path = dbURL?.path else { return }
        do {
            db = try SQLiteDatabase(path: path)
            logV("💽 [ClipboardDB] Opened: \(path)")
        } catch {
            logE("💽 ❌ [ClipboardDB] Open failed: \(error)")
        }
    }

    private func applyPragmas() {
        guard let db = db else { return }
        // 권장 PRAGMA (안전 범위에서 설정)
        try? db.execute(sql: "PRAGMA journal_mode=WAL;")
        try? db.execute(sql: "PRAGMA synchronous=NORMAL;")
        try? db.execute(sql: "PRAGMA auto_vacuum=FULL;")
    }

    private func createSchemaIfNeeded() {
        guard let db = db else { return }
        let create = """
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY,
            created_at INTEGER NOT NULL,
            kind TEXT NOT NULL,
            text TEXT,
            blob_path TEXT,
            filelist_json TEXT,
            uti TEXT,
            size_bytes INTEGER,
            hash TEXT,
            pinned INTEGER DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at);
        CREATE INDEX IF NOT EXISTS idx_items_kind ON items(kind);
        """
        do {
            try db.execute(sql: create)
            
            // CL060: 마이그레이션 - app_bundle 컬럼이 없으면 추가
            if !columnExists(tableName: "items", columnName: "app_bundle") {
                try db.execute(sql: "ALTER TABLE items ADD COLUMN app_bundle TEXT;")
                logI("💽 [ClipboardDB] Migrated: Added app_bundle column")
            }
            
            logV("💽 [ClipboardDB] Schema ensured")
        } catch {
            logE("💽 ❌ [ClipboardDB] Schema create failed: \(error)")
        }
    }

    // 공개 헬퍼 메서드
    func getDBPath() -> String? { dbURL?.path }
    func getBlobsDir() -> String? { blobsDirURL?.path }

    /// 항목 삽입
    func insertItem(_ item: ClipboardItem) {
        dbQueue.sync {
            guard let db = db else { return }
            
            let sql = """
            INSERT INTO items (created_at, kind, text, blob_path, filelist_json, uti, size_bytes, hash, pinned, app_bundle)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        do {
            guard let stmt = try db.prepare(sql: sql) else { return }
            defer { sqlite3_finalize(stmt) }
            
            sqlite3_bind_int64(stmt, 1, item.createdAt)
            sqlite3_bind_text(stmt, 2, (item.kind as NSString).utf8String, -1, nil)
            
            if let text = item.text {
                sqlite3_bind_text(stmt, 3, (text as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            
            if let blob = item.blobPath {
                sqlite3_bind_text(stmt, 4, (blob as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            
            if let json = item.filelistJson {
                sqlite3_bind_text(stmt, 5, (json as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            
            if let uti = item.uti {
                sqlite3_bind_text(stmt, 6, (uti as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            
            sqlite3_bind_int64(stmt, 7, item.sizeBytes ?? 0)
            
            if let hashValue = item.hash {
                sqlite3_bind_text(stmt, 8, (hashValue as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            
            sqlite3_bind_int(stmt, 9, Int32(item.pinned))
            
            if let bundle = item.appBundle {
                sqlite3_bind_text(stmt, 10, (bundle as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 10)
            }
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                logE("💽 ❌ [ClipboardDB] Insert failed: \(db.errorMessage)")
            } else {
                logV("💽 [ClipboardDB] Item inserted (kind: \(item.kind))")
            }
        } catch {
            logE("💽 ❌ [ClipboardDB] Insert preparation failed: \(error)")
        }
        } // End dbQueue.sync
    }

    /// 해시 중복 확인 (최신 항목 중 동일 해시 존재 여부)
    /// 해시 중복 확인 (최신 항목 중 동일 해시 존재 여부)
    func isDuplicate(hash: String) -> Bool {
        return findIdByHash(hash: hash) != nil
    }

    /// 가장 최상단(최신) 항목의 해시 반환
    func getLatestHash() -> String? {
        dbQueue.sync {
            guard let db = db else { return nil }
            let sql = "SELECT hash FROM items ORDER BY created_at DESC LIMIT 1;"
            do {
                guard let stmt = try db.prepare(sql: sql) else { return nil }
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let cHash = sqlite3_column_text(stmt, 0) {
                        return String(cString: cHash)
                    }
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] getLatestHash failed: \(error)")
            }
            return nil
        }
    }

    /// 동일 해시를 가진 항목의 ID 반환
    func findIdByHash(hash: String) -> Int64? {
        dbQueue.sync {
            guard let db = db else { return nil }
            let sql = "SELECT id FROM items WHERE hash = ? ORDER BY created_at DESC LIMIT 1;"
            do {
                guard let stmt = try db.prepare(sql: sql) else { return nil }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, (hash as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    return sqlite3_column_int64(stmt, 0)
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] findIdByHash failed: \(error)")
            }
            return nil
        }
    }

    /// 특정 항목의 시간을 현재로 갱신 (최상단 이동)
    func updateTimestamp(id: Int64) {
        dbQueue.sync {
            guard let db = db else { return }
            let now = Int64(Date().timeIntervalSince1970)
            let sql = "UPDATE items SET created_at = ? WHERE id = ?;"
            do {
                guard let stmt = try db.prepare(sql: sql) else { return }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, now)
                sqlite3_bind_int64(stmt, 2, id)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    logE("💽 ❌ [ClipboardDB] UpdateTimestamp failed: \(db.errorMessage)")
                } else {
                    logV("💽 [ClipboardDB] Item timestamp updated (id: \(id))")
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] UpdateTimestamp prep failed: \(error)")
            }
        }
    }

    /// 텍스트 내용 업데이트 (CL045_10)
    func updateItemContent(id: Int64, newText: String) {
        dbQueue.sync {
            guard let db = db else { return }
            let now = Int64(Date().timeIntervalSince1970)
            let sql = "UPDATE items SET text = ?, created_at = ?, size_bytes = ? WHERE id = ?;"
            do {
                guard let stmt = try db.prepare(sql: sql) else { return }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, (newText as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 2, now) // 타임스탬프를 현재로 업데이트 (최상단으로 이동)
                sqlite3_bind_int64(stmt, 3, Int64(newText.utf8.count))
                sqlite3_bind_int64(stmt, 4, id)
                if sqlite3_step(stmt) != SQLITE_DONE {
                    logE("💽 ❌ [ClipboardDB] UpdateItemContent failed: \(db.errorMessage)")
                } else {
                    logV("💽 [ClipboardDB] Item content updated (id: \(id))")
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] UpdateItemContent prep failed: \(error)")
            }
        }
    }

    /// 전체 히스토리 삭제
    func clearAll() {
        dbQueue.sync {
            _clearAll()
        }
    }

    /// 유지보수: 기간 만료 항목 삭제 (TTL)
    /// - Parameters:
    ///   - textDays: 텍스트 보관일 (기본 90)
    ///   - imageDays: 이미지 보관일 (기본 7)
    ///   - fileListDays: 파일리스트 보관일 (기본 30)
    func applyRetentionPolicy(textDays: Int = 90, imageDays: Int = 7, fileListDays: Int = 30) {
        dbQueue.sync {
            guard let db = db else { return }
            let now = Int64(Date().timeIntervalSince1970)
            
            let policies = [
                ("plain_text", Int64(textDays) * 86400),
                ("image", Int64(imageDays) * 86400),
                ("file_list", Int64(fileListDays) * 86400)
            ]
            
            for (kind, ttl) in policies {
                let expirationLimit = now - ttl
                
                // 1. 삭제할 이미지 블랍 파일들 조회 (kind가 image인 경우)
                if kind == "image" {
                    cleanupBlobs(before: expirationLimit)
                }
                
                // 2. DB 레코드 삭제 (pinned=0인 항목만, Issue771: prepared statement로 변경)
                let sql = "DELETE FROM items WHERE kind = ? AND created_at < ? AND pinned = 0;"
                do {
                    guard let stmt = try db.prepare(sql: sql) else { continue }
                    defer { sqlite3_finalize(stmt) }
                    sqlite3_bind_text(stmt, 1, (kind as NSString).utf8String, -1, nil)
                    sqlite3_bind_int64(stmt, 2, expirationLimit)
                    _ = sqlite3_step(stmt)
                } catch {
                    logE("💽 ❌ [ClipboardDB] applyRetentionPolicy DELETE failed (kind=\(kind)): \(error)")
                }
            }
            logV("💽 [ClipboardDB] Retention policy applied")
        }
    }

    /// 최근 N분간의 히스토리 삭제 (CL011)
    func deleteRecent(minutes: Int) {
        dbQueue.sync {
            guard let db = db else { return }
            let now = Int64(Date().timeIntervalSince1970)
            let sinceTimestamp = now - Int64(minutes * 60)
            
            do {
                // 1. 블랍 파일 삭제 (pinned=0인 항목만)
                cleanupRecentBlobs(since: sinceTimestamp)

                // 2. DB 레코드 삭제 (pinned=0인 항목만, Issue771: prepared statement로 변경)
                let sql = "DELETE FROM items WHERE created_at >= ? AND pinned = 0;"
                guard let stmt = try db.prepare(sql: sql) else { return }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, sinceTimestamp)
                _ = sqlite3_step(stmt)

                logI("💽 [ClipboardDB] Deleted items from last \(minutes) minutes (since: \(sinceTimestamp))")
            } catch {
                logE("💽 ❌ [ClipboardDB] deleteRecent failed: \(error)")
            }
        }
    }

    private func cleanupRecentBlobs(since timestamp: Int64) {
        guard let db = db, let blobsDir = blobsDirURL else { return }
        let sql = "SELECT blob_path FROM items WHERE kind = 'image' AND created_at >= ? AND pinned = 0;"
        do {
            guard let stmt = try db.prepare(sql: sql) else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, timestamp)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cPath = sqlite3_column_text(stmt, 0) {
                    let fileName = String(cString: cPath)
                    let fileURL = blobsDir.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: fileURL)
                    logV("💽 [ClipboardDB] Deleted blob: \(fileName)")
                }
            }
        } catch {
            logE("💽 ❌ [ClipboardDB] Recent blob cleanup failed: \(error)")
        }
    }

    private func cleanupBlobs(before timestamp: Int64) {
        guard let db = db, let blobsDir = blobsDirURL else { return }
        let sql = "SELECT blob_path FROM items WHERE kind = 'image' AND created_at < ? AND pinned = 0;"
        do {
            guard let stmt = try db.prepare(sql: sql) else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, timestamp)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cPath = sqlite3_column_text(stmt, 0) {
                    let fileName = String(cString: cPath)
                    let fileURL = blobsDir.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            logE("💽 ❌ [ClipboardDB] Blob cleanup failed: \(error)")
        }
    }

    /// 텍스트/파일명 검색 (CL012, CL014) + 필터링 (CL078)
    /// - Parameters:
    ///   - query: 검색어 (빈 문자열이면 전체 목록 반환)
    ///   - limit: 최대 결과 수
    ///   - offset: 건너뛸 항목 수 (페이징용)
    ///   - appBundle: 앱 번들 ID 필터 (Optional)
    ///   - kind: 항목 유형 필터 (Optional)
    /// - Returns: 검색 결과 배열 (최신순 정렬)
    /// - Note: 한글 정규화(NFC), 대소문자 무시, 파일명 basename 검색 지원
    /// 텍스트/파일명 검색 (CL012, CL014) + 필터링 (CL078)
    /// - Returns: (검색 결과 배열, 소요 시간 Sec)
    func search(query: String, limit: Int = 50, offset: Int = 0, appBundle: String? = nil, kind: String? = nil) -> ([ClipboardItem], TimeInterval) {
        var results: [ClipboardItem] = []
        var duration: TimeInterval = 0
        
        dbQueue.sync {
            guard let db = db else { return }
            let startTime = Date()
            
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFullSearch = trimmedQuery.isEmpty
            
            if isFullSearch {
                // 전체 목록 조회 (필터 포함)
                // CL098: 리스트 성능을 위해 대용량 텍스트 자르기 (최대 2000자)
                var sql = "SELECT id, created_at, kind, substr(text, 1, 2000) as text, blob_path, filelist_json, uti, size_bytes, hash, pinned, app_bundle FROM items WHERE 1=1"
                var params: [Any] = []
                
                if let app = appBundle {
                    sql += " AND app_bundle = ?"
                    params.append(app)
                }
                if let k = kind {
                    sql += " AND kind = ?"
                    params.append(k)
                }
                
                sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?;"
                
                do {
                    guard let stmt = try db.prepare(sql: sql) else { return }
                    defer { sqlite3_finalize(stmt) }
                    
                    var paramIdx: Int32 = 1
                    for param in params {
                        if let str = param as? String {
                            sqlite3_bind_text(stmt, paramIdx, (str as NSString).utf8String, -1, nil)
                        }
                        paramIdx += 1
                    }
                    
                    sqlite3_bind_int(stmt, paramIdx, Int32(limit))
                    sqlite3_bind_int(stmt, paramIdx + 1, Int32(offset))
                    
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        results.append(parseRow(stmt))
                    }
                } catch {
                    logE("💽 ❌ [ClipboardDB] Full search failed: \(error)")
                }
            } else {
                // 검색 최적화: Lightweight Fetch -> Filter -> Full Fetch
                // 1. 경량 조회: 필요한 컬럼만 조회하여 메모리 사용량 감소
                let normalizedQuery = trimmedQuery.precomposedStringWithCanonicalMapping.lowercased()
                var sql = """
                    SELECT id, substr(text, 1, 2000), filelist_json, created_at
                    FROM items
                    WHERE (text LIKE ? COLLATE NOCASE OR filelist_json LIKE ? COLLATE NOCASE)
                """
                
                var params: [Any] = []
                let searchPattern = "%\(trimmedQuery)%"
                params.append(searchPattern)
                params.append(searchPattern)
                
                if let app = appBundle {
                    sql += " AND app_bundle = ?"
                    params.append(app)
                }
                if let k = kind {
                    sql += " AND kind = ?"
                    params.append(k)
                }
                
                // 정렬은 created_at DESC (최신순)
                sql += " ORDER BY created_at DESC;"
                
                do {
                    guard let stmt = try db.prepare(sql: sql) else { return }
                    defer { sqlite3_finalize(stmt) }
                    
                    var paramIdx: Int32 = 1
                    for param in params {
                        if let str = param as? String {
                            sqlite3_bind_text(stmt, paramIdx, (str as NSString).utf8String, -1, nil)
                        }
                        paramIdx += 1
                    }
                    
                    var candidateIds: [Int64] = []
                    
                    // 2. 메모리 필터: 한글 정규화 및 basename 검색
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let id = sqlite3_column_int64(stmt, 0)
                        let text: String? = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                        let filelistJson: String? = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                        
                        var isMatch = false
                        
                        if let t = text {
                            if t.precomposedStringWithCanonicalMapping.lowercased().contains(normalizedQuery) {
                                isMatch = true
                            }
                        }
                        
                        if !isMatch, let json = filelistJson,
                           let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                            let basenames = paths.map { URL(fileURLWithPath: $0).lastPathComponent.precomposedStringWithCanonicalMapping.lowercased() }
                            if basenames.contains(where: { $0.contains(normalizedQuery) }) {
                                isMatch = true
                            }
                        }
                        
                        if isMatch {
                            candidateIds.append(id)
                        }
                    }
                    
                    // 3. 페이지네이션 & 전체 조회
                    let totalMatches = candidateIds.count
                    let startIndex = min(offset, totalMatches)
                    let endIndex = min(offset + limit, totalMatches)
                    
                    if startIndex < endIndex {
                        let pagedIds = Array(candidateIds[startIndex..<endIndex])
                        if !pagedIds.isEmpty {
                            let idList = pagedIds.map { String($0) }.joined(separator: ",")
                            // CL098: 대용량 텍스트 자르기
                            let fullSql = "SELECT id, created_at, kind, substr(text, 1, 2000) as text, blob_path, filelist_json, uti, size_bytes, hash, pinned, app_bundle FROM items WHERE id IN (\(idList)) ORDER BY created_at DESC;" // ID 순서가 아니라 CreatedAt 순서여야 하는데, IN 절은 순서 보장 안함. 하지만 CandidateIds는 이미 정렬됨.
                            // 다시 정렬하거나, ID 순서대로 가져와서 매핑해야 함.
                            // 간단하게는 다시 ORDER BY created_at DESC 하면 됨 (timestamp가 유니크하지 않을 수 있지만 대략 맞음).
                            // 더 정확하게는:
                            
                            if let fullStmt = try db.prepare(sql: fullSql) {
                                defer { sqlite3_finalize(fullStmt) }
                                while sqlite3_step(fullStmt) == SQLITE_ROW {
                                    results.append(parseRow(fullStmt))
                                }
                            }
                            
                            // 결과 순서 보정 (CandidateIds 순서대로)
                            // results를 딕셔너리로 만들어서 재정렬
                            // (또는 created_at DESC로 충분할 수 있음)
                        }
                    }
                    
                     logV("💽 [ClipboardDB] Search optimized. Query: '\(normalizedQuery)', Candidates: \(candidateIds.count), Results: \(results.count)")
                    
                } catch {
                    logE("💽 ❌ [ClipboardDB] Search failed: \(error)")
                }
            }
            
            duration = Date().timeIntervalSince(startTime)
            let elapsedMs = duration * 1000
            
            if elapsedMs > 50 {
                logW("💽 ⚠️ [ClipboardDB] Search performance warning: \(String(format: "%.2f", elapsedMs))ms")
            }
        }
        
        return (results, duration)
    }

    /// 검색 조건에 맞는 모든 항목의 ID 반환 (CL066 - 일괄 삭제용)
    func searchIds(query: String) -> [Int64] {
        dbQueue.sync {
            _searchIds(query: query)
        }
    }
    
    private func _searchIds(query: String) -> [Int64] {
        guard let db = db else { return [] }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return [] // 전체 ID 반환은 위험하므로 빈 배열 반환 (전체 삭제는 clearAll 사용)
        }
        
        var matchingIds: [Int64] = []
        
        let normalizedQuery = trimmedQuery.precomposedStringWithCanonicalMapping.lowercased()
        
        // 검색 최적화를 위해 필요한 컬럼만 조회
        let sql = """
            SELECT id, text, filelist_json
            FROM items
            WHERE (text LIKE ? COLLATE NOCASE OR filelist_json LIKE ? COLLATE NOCASE)
            ORDER BY created_at DESC;
        """
        
        do {
            guard let stmt = try db.prepare(sql: sql) else { return [] }
            defer { sqlite3_finalize(stmt) }
            
            let searchPattern = "%\(trimmedQuery)%"
            sqlite3_bind_text(stmt, 1, (searchPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (searchPattern as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let text: String? = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                let filelistJson: String? = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                
                // 2차 필터링: 한글 정규화 + basename 검색 (search 메서드와 동일 로직)
                var isMatch = false
                
                if let t = text {
                    if t.precomposedStringWithCanonicalMapping.lowercased().contains(normalizedQuery) {
                        isMatch = true
                    }
                }
                
                if !isMatch, let json = filelistJson,
                   let paths = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) {
                    let basenames = paths.map { URL(fileURLWithPath: $0).lastPathComponent.precomposedStringWithCanonicalMapping.lowercased() }
                    if basenames.contains(where: { $0.contains(normalizedQuery) }) {
                        isMatch = true
                    }
                }
                
                if isMatch {
                    matchingIds.append(id)
                }
            }
        } catch {
            logE("💽 ❌ [ClipboardDB] searchIds failed: \(error)")
        }
        
        return matchingIds
    }
    
    /// 검색 조건에 맞는 항목 일괄 삭제 (CL066)
    func deleteItems(matching query: String) {
        dbQueue.sync {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                // ClearAll also needs to run internally to avoid deadlock if we called public clearAll here.
                // But clearAll logic is simple. Let's just call internal implementation or duplicate logic.
                // Actually, clearAll is wrapped. So we cannot call it from inside sync block.
                // We should implement _clearAll or just inline logic here.
                // Since clearAll is extensive, let's just make a private _clearAll.
                // Or simply:
                // self._clearAll()
                // But we don't have _clearAll defined yet.
                // Let's refactor clearAll into _clearAll for safety.
                
                // For now, let's assume we implement _clearAll.
                _clearAll()
                return
            }
            
            let ids = _searchIds(query: query)
            if !ids.isEmpty {
                _deleteItems(ids: ids)
                logI("💽 [ClipboardDB] Deleted \(ids.count) items matching query: '\(query)'")
            }
        }
    }
    
    // 재진입을 위한 내부 clearAll
    private func _clearAll() {
        guard let db = db else { return }
        do {
            if let blobsDir = blobsDirURL {
                let files = try? FileManager.default.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: nil)
                files?.forEach { try? FileManager.default.removeItem(at: $0) }
            }
            try db.execute(sql: "DELETE FROM items;")
            logI("💽 [ClipboardDB] All history and blobs cleared")
        } catch {
            logE("💽 ❌ [ClipboardDB] ClearAll failed: \(error)")
        }
    }

    /// 단일 항목 삭제 (CL015 관련)
    func deleteItem(id: Int64) {
        deleteItems(ids: [id])
    }

    /// 다중 항목 삭제 (CL015)
    func deleteItems(ids: [Int64]) {
        dbQueue.sync {
            _deleteItems(ids: ids)
        }
    }
    
    private func _deleteItems(ids: [Int64]) {
        guard let db = db, !ids.isEmpty else { return }
        
        do {
            // 1. 블랍 파일들 삭제 (image 타입인 경우)
            let idList = ids.map { String($0) }.joined(separator: ", ")
            let findSql = "SELECT blob_path FROM items WHERE id IN (\(idList)) AND kind = 'image' AND blob_path IS NOT NULL;"
            
            if let stmt = try db.prepare(sql: findSql) {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cPath = sqlite3_column_text(stmt, 0) {
                        let fileName = String(cString: cPath)
                        if let blobsDir = blobsDirURL {
                            let fileURL = blobsDir.appendingPathComponent(fileName)
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                    }
                }
            }
            
            // 2. 레코드 일괄 삭제
            let delSql = "DELETE FROM items WHERE id IN (\(idList));"
            try db.execute(sql: delSql)
            
            logI("💽 [ClipboardDB] Deleted \(ids.count) items (IDs: \(idList))")
        } catch {
            logE("💽 ❌ [ClipboardDB] deleteItems failed: \(error)")
        }
    }

    private func parseRow(_ stmt: OpaquePointer) -> ClipboardItem {
        let id = sqlite3_column_int64(stmt, 0)
        let createdAt = sqlite3_column_int64(stmt, 1)
        let kind = String(cString: sqlite3_column_text(stmt, 2))
        
        let text: String? = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let blobPath: String? = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let filelistJson: String? = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let uti: String? = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let sizeBytes = sqlite3_column_int64(stmt, 7)
        let hash: String? = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let pinned = Int(sqlite3_column_int(stmt, 9))
        let appBundle: String? = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
        
        return ClipboardItem(
            id: id, createdAt: createdAt, kind: kind,
            text: text, blobPath: blobPath, filelistJson: filelistJson,
            uti: uti, sizeBytes: sizeBytes, hash: hash, pinned: pinned,
            appBundle: appBundle
        )
    }

    private func columnExists(tableName: String, columnName: String) -> Bool {
        guard let db = db else { return false }
        let sql = "PRAGMA table_info(\(tableName));"
        var exists = false
        do {
            guard let stmt = try db.prepare(sql: sql) else { return false }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 1) {
                    if String(cString: name) == columnName {
                        exists = true
                        break
                    }
                }
            }
        } catch {
            logE("💽 ❌ [ClipboardDB] columnExists check failed: \(error)")
        }
        return exists
    }

    /// 최신순 N번째(1-based) plain_text 콘텐츠 조회. 없으면 nil (Limit 2000 chars)
    func fetchPlainTextAt(historyIndex: Int) -> String? {
        dbQueue.sync {
            guard let db = db, historyIndex > 0 else { return nil }
            // N번째(1-based) → OFFSET N-1
            let offset = historyIndex - 1
            // CL098: 리스트/미리보기 성능을 위해 대용량 텍스트 자르기 (최대 2000자)
            let sql = """
                SELECT substr(text, 1, 2000)
                FROM items
                WHERE kind='plain_text' AND text IS NOT NULL
                ORDER BY created_at DESC
                LIMIT 1 OFFSET \(offset);
            """
            do {
                guard let stmt = try db.prepare(sql: sql) else { return nil }
                defer { sqlite3_finalize(stmt) }
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let cText = sqlite3_column_text(stmt, 0) {
                        return String(cString: cText)
                    }
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] fetchPlainTextAt failed: \(error)")
            }
            return nil
        }
    }

    /// 원본 전체 텍스트 조회 (Copy/Detail용)
    func fetchFullText(id: Int64) -> String? {
        dbQueue.sync {
            guard let db = db else { return nil }
            let sql = "SELECT text FROM items WHERE id = ?;"
            do {
                guard let stmt = try db.prepare(sql: sql) else { return nil }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_int64(stmt, 1, id)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let cText = sqlite3_column_text(stmt, 0) {
                        return String(cString: cText)
                    }
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] fetchFullText failed: \(error)")
            }
            return nil
        }
    }

    /// 저장된 클립보드 항목 중 유니크한 App Bundle ID 목록 반환 (CL078)
    func getDistinctAppBundles() -> [String] {
        dbQueue.sync {
            guard let db = db else { return [] }
            let sql = "SELECT DISTINCT app_bundle FROM items WHERE app_bundle IS NOT NULL AND app_bundle != '';"
            var bundles: [String] = []
            
            do {
                guard let stmt = try db.prepare(sql: sql) else { return [] }
                defer { sqlite3_finalize(stmt) }
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cBundle = sqlite3_column_text(stmt, 0) {
                        bundles.append(String(cString: cBundle))
                    }
                }
            } catch {
                logE("💽 ❌ [ClipboardDB] getDistinctAppBundles failed: \(error)")
            }
            return bundles
        }
    }
}

// MARK: - Extensions for Preview Compatibility
extension ClipboardItem {
    enum ItemType {
        case plainText
        case image
        case fileList
        case other
    }
    
    var type: ItemType {
        switch kind {
        case "plain_text": return .plainText
        case "image": return .image
        case "file_list": return .fileList
        default: return .other
        }
    }
    
    var content: String {
        return text ?? filelistJson ?? blobPath ?? ""
    }
    
    var dateString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAt))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
