import Foundation
#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite)
import CSQLite
#else
#error("SQLite3 or CSQLite is required to build SimNavCore")
#endif

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteArgument {
    case text(String)
    case int(Int)
    case double(Double)
    case null
}

enum SQLiteDatabaseError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "无法打开导航数据库：\(message)"
        case .prepareFailed(let message):
            "无法准备 SQLite 查询：\(message)"
        case .bindFailed(let message):
            "无法绑定 SQLite 参数：\(message)"
        case .stepFailed(let message):
            "SQLite 查询执行失败：\(message)"
        }
    }
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: URL) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path.path, &db, flags, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            if let db {
                sqlite3_close(db)
            }
            throw SQLiteDatabaseError.openFailed(message)
        }
        handle = db
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func rows(sql: String, arguments: [SQLiteArgument] = []) throws -> [[String: Any]] {
        guard let handle else {
            throw SQLiteDatabaseError.openFailed("数据库连接不存在")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepareFailed(message)
        }
        defer {
            sqlite3_finalize(statement)
        }

        for (index, argument) in arguments.enumerated() {
            guard bind(argument, to: statement, at: Int32(index + 1)) == SQLITE_OK else {
                throw SQLiteDatabaseError.bindFailed(message)
            }
        }

        var output: [[String: Any]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                break
            }
            guard result == SQLITE_ROW else {
                throw SQLiteDatabaseError.stepFailed(message)
            }
            output.append(row(from: statement))
        }
        return output
    }

    func first(sql: String, arguments: [SQLiteArgument] = []) throws -> [String: Any]? {
        try rows(sql: sql, arguments: arguments).first
    }

    private var message: String {
        guard let handle else { return "数据库连接不存在" }
        return String(cString: sqlite3_errmsg(handle))
    }

    private func bind(_ argument: SQLiteArgument, to statement: OpaquePointer, at index: Int32) -> Int32 {
        switch argument {
        case .text(let value):
            return sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        case .int(let value):
            return sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        case .double(let value):
            return sqlite3_bind_double(statement, index, value)
        case .null:
            return sqlite3_bind_null(statement, index)
        }
    }

    private func row(from statement: OpaquePointer) -> [String: Any] {
        let count = sqlite3_column_count(statement)
        var row: [String: Any] = [:]
        for index in 0..<count {
            let name = sqlite3_column_name(statement, index).map { String(cString: $0) } ?? "column_\(index)"
            switch sqlite3_column_type(statement, index) {
            case SQLITE_INTEGER:
                row[name] = Int(sqlite3_column_int64(statement, index))
            case SQLITE_FLOAT:
                row[name] = sqlite3_column_double(statement, index)
            case SQLITE_TEXT:
                row[name] = sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
            case SQLITE_NULL:
                row[name] = NSNull()
            default:
                row[name] = NSNull()
            }
        }
        return row
    }
}
