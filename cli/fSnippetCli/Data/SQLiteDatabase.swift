import Foundation
import SQLite3

/// SQLite 에러 타입
enum SQLiteError: Error {
    case openDatabase(message: String)
    case prepare(message: String)
    case step(message: String)
    case bind(message: String)
}

/// SQLite 데이터베이스 작업을 캡슐화한 헬퍼 클래스
class SQLiteDatabase {
    private var dbPointer: OpaquePointer?
    private let dbPath: String

    init(path: String) throws {
        self.dbPath = path
        try open()
    }
    
    deinit {
        close()
    }

    private func open() throws {
        var db: OpaquePointer?
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            self.dbPointer = db
            // WAL 모드 활성화 (동시성 향상)
            // execute(sql: "PRAGMA journal_mode=WAL;") 
            // -> 필요시 활성화. 현재는 기본 모드 사용.
        } else {
            defer {
                if db != nil {
                    sqlite3_close(db)
                }
            }
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                throw SQLiteError.openDatabase(message: message)
            } else {
                throw SQLiteError.openDatabase(message: "Unknown error")
            }
        }
    }
    
    func close() {
        if dbPointer != nil {
            sqlite3_close(dbPointer)
            dbPointer = nil
        }
    }
    
    /// SQL 실행 (결과 없음 - CREATE, INSERT, UPDATE, DELETE)
    func execute(sql: String) throws {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
             throw SQLiteError.prepare(message: errorMessage)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteError.step(message: errorMessage)
        }
    }
    
    /// 에러 메시지 반환
    var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            return String(cString: errorPointer)
        } else {
            return "Unknown error"
        }
    }
    
    // MARK: - 저수준 접근
    
    /// Prepared Statement 생성 (Caller가 finalize 해야 함)
    func prepare(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
            guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: errorMessage)
        }
        return statement
    }
    
    /// 마지막 삽입된 Row ID
    var lastInsertRowId: Int64 {
        return sqlite3_last_insert_rowid(dbPointer)
    }
}
