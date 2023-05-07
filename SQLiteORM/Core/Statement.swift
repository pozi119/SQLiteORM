//
//  Statement.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import AnyCoder
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

    /// database
    fileprivate let db: Database

    /// native sql clause
    fileprivate let sql: String

    fileprivate var values: [Primitive]?

    /// initialize
    init(_ db: Database, _ SQL: String) throws {
        self.db = db
        sql = SQL
        try db.check(sqlite3_prepare_v2(db.handle, SQL, -1, &handle, nil), statement: self)
    }

    deinit {
        guard handle != nil else { return }
        sqlite3_finalize(handle)
        handle = nil
    }

    // FIXME: columnCount is 0 and columnNames is [] when sql is `INSERT INTO table (col1,col2,col3) VALUES (?,?,?)`
    /// columns count
    public lazy var columnCount: Int = Int(sqlite3_column_count(self.handle))

    /// field name array
    public lazy var columnNames: [String] = (0 ..< Int32(self.columnCount)).map {
        String(cString: sqlite3_column_name(self.handle, $0))
    }

    /// search cursor
    fileprivate lazy var cursor: Cursor = Cursor(self)

    /// bind datas
    ///
    /// - Parameter values: [Primitive] array, corresponding to sql statement
    public func bind(_ values: [Primitive]) -> Statement {
        guard !values.isEmpty else { return self }
        reset()
        self.values = values
        let count = values.count
        for idx in 0 ..< count { cursor[idx] = values[idx] }
        return self
    }

    /// query records
    public func query() throws -> [[String: Primitive]] {
        guard columnCount > 0 else {
            return []
        }

        var key: String = ""
        var cache: Cache<String, [[String: Primitive]]>?
        if let table = sqlite3_column_table_name(handle, 0),
           let name = NSString(utf8String: table),
           let orm = db.orms.object(forKey: name) as? Orm<Any> {
            key = sql + (values?.description ?? "")
            cache = orm.cache
        }

        if !key.isEmpty, let results = cache?.object(forKey: key) {
            return results
        }

        var ret = true
        var array = [[String: Primitive]]()
        repeat {
            ret = try step()
            if ret {
                var dic = [String: Primitive]()
                for i in 0 ..< columnCount {
                    dic[columnNames[i]] = cursor[i]
                }
                array.append(dic)
            }
        } while ret

        if !key.isEmpty { cache?.setObject(array, forKey: key) }
        return array
    }

    /// execute native sql statement
    public func run() throws {
        reset(clear: false)
        try db.sync { repeat {} while try step() }
    }

    /// execute native sql statement, and bind datas
    public func run(_ bindings: [Primitive]) throws {
        return try bind(bindings).run()
    }

    public func scalar() throws -> Primitive? {
        reset(clear: false)
        _ = try step()
        return cursor[0]
    }

    public func scalar(_ bindings: [Primitive]) throws -> Primitive? {
        return try bind(bindings).scalar()
    }

    public func step() throws -> Bool {
        return try db.check(sqlite3_step(handle), statement: self) == SQLITE_ROW
    }

    /// reset statement
    ///
    /// - Parameter shouldClear: clean bind data
    public func reset(clear shouldClear: Bool = true) {
        sqlite3_reset(handle)
        if shouldClear { sqlite3_clear_bindings(handle) }
    }
}

extension Statement: CustomStringConvertible {
    public var description: String { sql }
}

/// search cursor
fileprivate struct Cursor {
    /// SQL statement
    fileprivate let handle: OpaquePointer

    /// fields count
    fileprivate let columnCount: Int

    /// initialize
    fileprivate init(_ statement: Statement) {
        handle = statement.handle!
        columnCount = statement.columnCount
    }
}

/// Cursors provide direct access to a statement’s current row.
extension Cursor: Sequence {
    /// digital subscript access, like array
    subscript(idx: Int) -> Primitive? {
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
            case SQLITE_TEXT: fallthrough
            case SQLITE3_TEXT:
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
            case let newValue as any BinaryInteger:
                sqlite3_bind_int64(handle, index, Int64(newValue))
            case let newValue as any BinaryFloatingPoint:
                sqlite3_bind_double(handle, index, Double(newValue))
            case let newValue as Bool:
                sqlite3_bind_int64(handle, index, newValue ? 1 : 0)
            case let newValue as String:
                let cString = (newValue as NSString).utf8String
                sqlite3_bind_text(handle, index, cString, -1, SQLITE_TRANSIENT)
            default:
                assert(false, "tried to bind unexpected value \(newValue ?? "")")
            }
        }
    }

    /// string subscript access, like dictionary
    subscript(field: String) -> Primitive? {
        get {
            let idx = Int(sqlite3_bind_parameter_index(handle, field))
            return self[idx]
        }
        set(newValue) {
            let idx = Int(sqlite3_bind_parameter_index(handle, field))
            self[idx] = newValue
        }
    }

    public func makeIterator() -> AnyIterator<Primitive?> {
        var idx = 0
        return AnyIterator {
            if idx >= self.columnCount {
                return Optional<Primitive?>.none
            } else {
                idx += 1
                return self[idx - 1]
            }
        }
    }
}
