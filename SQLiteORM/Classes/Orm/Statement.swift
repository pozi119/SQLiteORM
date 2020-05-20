//
//  Statement.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Foundation

#if SQLITE_HAS_CODEC
    import SQLCipher
#elseif os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQL statement.
public final class Statement {
    /// statement
    fileprivate var handle: OpaquePointer?

    /// 数据库
    fileprivate let db: Database

    /// sql 语句
    fileprivate let sql: String

    /// 初始化
    ///
    /// - Parameters:
    ///   - db: 数据
    ///   - SQL: sql语句
    /// - Throws: 初始化过程中的错误
    init(_ db: Database, _ SQL: String) throws {
        self.db = db
        sql = SQL
        try db.check(sqlite3_prepare_v2(db.handle, SQL, -1, &handle, nil))
    }

    deinit {
        sqlite3_finalize(handle)
        handle = nil
    }

    // FIXME: columnCount is 0 and columnNames is [] when sql is `INSERT INTO table (col1,col2,col3) VALUES (?,?,?)`
    /// 字段数量
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.handle))

    /// 字段名数组
    public lazy var columnNames: [String] = (0 ..< Int32(self.columnCount)).map {
        String(cString: sqlite3_column_name(self.handle, $0))
    }

    /// 查询游标
    fileprivate lazy var cursor: Cursor = Cursor(self)

    /// 绑定数据,防SQL注入
    ///
    /// - Parameter values: [数据]数组,和sql语句对应
    /// - Returns: 绑定后的statement
    public func bind(_ values: [Binding]) -> Statement {
        if values.isEmpty { return self }
        reset()
        let count = values.count
        for idx in 0 ..< count { cursor[idx] = values[idx] }
        return self
    }

    /// 查询数据
    ///
    /// - Returns: 查询结果
    /// - Throws: 查询过程中的错误
    public func query() throws -> [[String: Binding]] {
        guard columnCount > 0 else {
            return []
        }

        if let results = db.cache.object(forKey: sql) {
            return results
        }

        var ret = true
        var array = [[String: Binding]]()
        repeat {
            ret = try step()
            if ret {
                var dic = [String: Binding]()
                for i in 0 ..< columnCount {
                    dic[columnNames[i]] = cursor[i]
                }
                array.append(dic)
            }
        } while ret

        db.cache.setObject(array, forKey: sql)
        return array
    }

    /// 执行sql语句
    ///
    /// - Returns: 执行sql语句后的statment
    /// - Throws: 执行过程中的错误
    public func run() throws {
        reset(clear: false)
        try db.sync { repeat {} while try step() }
    }

    /// 执行sql语句
    ///
    /// - Parameter bindings: [数据]数组,和sql语句对应
    /// - Throws: 执行过程中的错误
    public func run(_ bindings: [Binding]) throws {
        return try bind(bindings).run()
    }

    public func scalar() throws -> Binding? {
        reset(clear: false)
        _ = try step()
        return cursor[0]
    }

    public func scalar(_ bindings: [Binding]) throws -> Binding? {
        return try bind(bindings).scalar()
    }

    public func step() throws -> Bool {
        return try db.check(sqlite3_step(handle)) == SQLITE_ROW
    }

    /// 重置statement
    ///
    /// - Parameter shouldClear: 是否清除绑定数据
    public func reset(clear shouldClear: Bool = true) {
        sqlite3_reset(handle)
        if shouldClear { sqlite3_clear_bindings(handle) }
    }
}

extension Statement: CustomStringConvertible {
    public var description: String {
        return String(cString: sqlite3_sql(handle))
    }
}

/// 查询/绑定数据的游标
fileprivate struct Cursor {
    /// SQL statement
    fileprivate let handle: OpaquePointer

    /// statment字段数量
    fileprivate let columnCount: Int

    /// 初始化
    ///
    /// - Parameter statement: SQL statement
    fileprivate init(_ statement: Statement) {
        handle = statement.handle!
        columnCount = statement.columnCount
    }
}

/// Cursors provide direct access to a statement’s current row.
extension Cursor: Sequence {
    /// 数字下标访问,数组
    ///
    /// - Parameter idx: 下标
    subscript(idx: Int) -> Binding? {
        get {
            switch sqlite3_column_type(handle, Int32(idx)) {
            case SQLITE_BLOB:
                if let pointer = sqlite3_column_blob(handle, Int32(idx)) {
                    let length = Int(sqlite3_column_bytes(handle, Int32(idx)))
                    return Data(bytes: pointer, count: length)
                } else {
                    return Data()
                }

            case SQLITE_FLOAT:
                return sqlite3_column_double(handle, Int32(idx)) as Double
            case SQLITE_INTEGER:
                return sqlite3_column_int64(handle, Int32(idx)) as Int64
            case SQLITE_NULL:
                return nil
            case SQLITE_TEXT:
                return String(cString: UnsafePointer(sqlite3_column_text(handle, Int32(idx))))
            case let type:
                assert(false, "unsupported column type: \(type)")
                return nil
            }
        }
        set(newValue) {
            let index = Int32(idx + 1)
            switch newValue {
            case let newValue where newValue == nil:
                sqlite3_bind_null(handle, Int32(idx))
            case let newValue as Data:
                let bytes = [UInt8](newValue)
                if bytes.count > INT_MAX {
                    sqlite3_bind_blob64(handle, index, bytes, sqlite3_uint64(bytes.count), SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_blob(handle, index, bytes, Int32(bytes.count), SQLITE_TRANSIENT)
                }
            case let newValue as Int:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as Int8:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as Int16:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as Int32:
                sqlite3_bind_int(handle, index, newValue)
            case let newValue as Int64:
                sqlite3_bind_int64(handle, index, newValue)
            case let newValue as UInt:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as UInt8:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as UInt16:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as UInt32:
                sqlite3_bind_int(handle, index, Int32(newValue))
            case let newValue as UInt64:
                sqlite3_bind_int64(handle, index, Int64(newValue))
            case let newValue as Float:
                sqlite3_bind_double(handle, index, Double(newValue))
            case let newValue as Double:
                sqlite3_bind_double(handle, index, newValue)
            case let newValue as Bool:
                sqlite3_bind_int(handle, index, newValue ? 1 : 0)
            case let newValue as String:
                sqlite3_bind_text(handle, index, newValue, -1, SQLITE_TRANSIENT)
            default:
                assert(false, "tried to bind unexpected value \(newValue ?? "")")
            }
        }
    }

    /// 字符串下标访问,字典
    ///
    /// - Parameter field: 下标
    subscript(field: String) -> Binding? {
        get {
            let idx = Int(sqlite3_bind_parameter_index(handle, field))
            return self[idx]
        }
        set(newValue) {
            let idx = Int(sqlite3_bind_parameter_index(handle, field))
            self[idx] = newValue
        }
    }

    public func makeIterator() -> AnyIterator<Binding?> {
        var idx = 0
        return AnyIterator {
            if idx >= self.columnCount {
                return Optional<Binding?>.none
            } else {
                idx += 1
                return self[idx - 1]
            }
        }
    }
}
