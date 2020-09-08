//
//  Database.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Dispatch
import Foundation

#if SQLITE_HAS_CODEC
    import SQLCipher
#elseif os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

/// sqlite3 database
public final class Database {
    /// database location
    ///
    /// - memory: memory database
    /// - temporary: temporary database
    /// - uri: special database path
    public enum Location {
        case memory
        case temporary
        case uri(String)
    }

    /// sqlite3 database handle
    var handle: OpaquePointer {
        try? open()
        return _handle!
    }

    /// database path
    public private(set) var path: String

    /// remove file when SQLITE_NOTADB, default is false
    public var removeWhenNotADB: Bool = false

    /// default open flags
    private let _essential: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    private var _flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

    fileprivate var _handle: OpaquePointer?
    fileprivate var encrypt: String = ""
    fileprivate var flags: Int32 {
        get {
            return _flags
        }
        set {
            _flags = newValue | _essential
        }
    }

    private static var _caches = [String: Cache<String, [[String: Binding]]>]()

    /// query results cache
    lazy var cache: Cache<String, [[String: Binding]]> = {
        if let _cache = Database._caches[path] {
            return _cache
        }
        let _cache = Cache<String, [[String: Binding]]>()
        Database._caches[path] = _cache
        return _cache
    }()

    /// initialize database
    public required init(_ location: Location = .temporary, flags: Int32 = 0, encrypt: String = "") {
        path = location.description
        self.flags = flags
        self.encrypt = encrypt
    }

    /// initialize database from file
    public convenience init(with path: String) {
        self.init(.uri(path), flags: 0, encrypt: "")
    }

    deinit {
        close()
    }

    /// open database
    public func open() throws {
        guard _handle == nil else { return }

        try check(sqlite3_open_v2(path, &_handle, flags, nil))
        #if SQLITE_HAS_CODEC
            if encrypt.count > 0 {
                _ = try sync { try check(sqlite3_key(handle, encrypt, Int32(encrypt.count))) }
                try cipherOptions.forEach { try execute($0) }
            }
        #endif
        try normalOptions.forEach { try execute($0) }
        sqlite3_update_hook(handle, global_update, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        sqlite3_commit_hook(handle, global_commit, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    }

    /// is the database open?
    public var isOpen: Bool { return _handle != nil }

    /// close database
    public func close() {
        if _handle != nil {
            sqlite3_close(_handle)
        }
        _handle = nil
    }

    // MARK: -

    /// Is the database read-only? the default is read-write
    public var readonly: Bool { return sqlite3_db_readonly(handle, nil) == 1 }

    /// last insert rowid
    public var lastInsertRowid: Int64 {
        return sqlite3_last_insert_rowid(handle)
    }

    /// number of last changes
    public var changes: Int {
        return Int(sqlite3_changes(handle))
    }

    /// total number of changes after opening database
    public var totalChanges: Int {
        return Int(sqlite3_total_changes(handle))
    }

    /// execute after sqlite3_key_v2()
    ///
    /// example: open 3.x ciphered database
    ///
    /// "pragma kdf_iter = 64000;"
    ///
    /// "pragma cipher_hmac_algorithm = HMAC_SHA1;"
    ///
    /// "pragma cipher_kdf_algorithm = PBKDF2_HMAC_SHA1;"
    ///
    public var cipherOptions: [String] = []

    /// execute after cipherOptions
    ///
    /// example:
    ///
    /// "PRAGMA synchronous = NORMAL"
    ///
    /// "PRAGMA journal_mode = WAL"
    ///
    public var normalOptions: [String] = ["pragma synchronous = normal;", "pragma journal_mode = wal;"]

    // MARK: - queue

    private static let queueKey = DispatchSpecificKey<String>()
    private static var queueNum = 0

    private lazy var name = ((self.path as NSString).lastPathComponent as NSString).deletingPathExtension
    private lazy var queueNum: Int = { defer { Database.queueNum += 1 }; return Database.queueNum }()
    private lazy var writeLabel = "com.sqliteorm.write.\(self.queueNum).\(self.name)"
    private lazy var readLabel = "com.sqliteorm.read.\(self.queueNum).\(self.name)"

    public lazy var writeQueue: DispatchQueue = {
        let queue = DispatchQueue(label: self.writeLabel, qos: .utility, attributes: .init(), autoreleaseFrequency: .inherit, target: nil)
        queue.setSpecific(key: Database.queueKey, value: self.writeLabel)
        return queue
    }()

    public lazy var readQueue: DispatchQueue = {
        let queue = DispatchQueue(label: self.readLabel, qos: .utility, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        queue.setSpecific(key: Database.queueKey, value: self.writeLabel)
        return queue
    }()

    public func sync<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Database.queueKey) == writeLabel {
            return try work()
        } else {
            return try writeQueue.sync(execute: work)
        }
    }

    // MARK: - Execute

    /// execute sql statement directly
    public func execute(_ sql: String) throws {
        _ = try sync { try check(sqlite3_exec(handle, sql, nil, nil, nil)) }
    }

    // MARK: - Prepare

    /// prepare sql statement
    public func prepare(_ statement: String) throws -> Statement {
        return try Statement(self, statement)
    }

    /// prepare sql statement, with values
    public func prepare(_ statement: String, _ bindings: [Binding]) throws -> Statement {
        return try prepare(statement).bind(bindings)
    }

    // MARK: - Run

    /// query  with native sql statement
    public func query(_ statement: String) -> [[String: Binding]] {
        return (try? prepare(statement).query()) ?? []
    }

    /// execute native sql query
    public func query<T: Codable>(_ statement: String, type: T.Type) -> [T] {
        let keyValues = query(statement)
        do {
            let array = try OrmDecoder().decode([T].self, from: keyValues)
            return array
        } catch {
            print(error)
            return []
        }
    }

    /// execute native sql query
    public func query<T>(_ statement: String, type: T.Type) -> [T] {
        let keyValues = query(statement)
        do {
            let array = try AnyDecoder.decode(T.self, from: keyValues)
            return array
        } catch {
            print(error)
            return []
        }
    }

    /// execute native sql statement
    public func run(_ statement: String) throws {
        return try prepare(statement).run()
    }

    /// execute native sql statement, with values
    public func run(_ statement: String, _ bindings: [Binding]) throws {
        return try prepare(statement).run(bindings)
    }

    // MARK: - Scalar

    public func scalar(_ statement: String) throws -> Binding? {
        return try prepare(statement).scalar()
    }

    public func scalar(_ statement: String, _ bindings: [Binding]) throws -> Binding? {
        return try prepare(statement).scalar(bindings)
    }

    // MARK: - Transactions

    public enum TransactionMode: String {
        case deferred = "DEFERRED"
        case immediate = "IMMEDIATE"
        case exclusive = "EXCLUSIVE"
    }

    /// sqlite transaction
    public func transaction(_ mode: TransactionMode = .deferred, block: () throws -> Void) throws {
        try transaction("BEGIN \(mode.rawValue) TRANSACTION", block, "COMMIT TRANSACTION", or: "ROLLBACK TRANSACTION")
    }

    /// sqlite checkpoint
    public func savepoint(_ name: String = UUID().uuidString, block: () throws -> Void) throws {
        let name = name.quote("'")
        let savepoint = "SAVEPOINT \(name)"

        try transaction(savepoint, block, "RELEASE \(savepoint)", or: "ROLLBACK TO \(savepoint)")
    }

    /// sqlite transaction
    fileprivate func transaction(_ begin: String, _ block: () throws -> Void, _ commit: String, or rollback: String) throws {
        try prepare(begin).run()
        do {
            try block()
            try prepare(commit).run()
        } catch {
            try prepare(rollback).run()
            throw error
        }
    }

    /// sqlite3_interrupt()
    public func interrupt() {
        sqlite3_interrupt(handle)
    }

    // MARK: - API

    /// check if the table exists
    public func exists(_ table: String) -> Bool {
        let value = ((try? scalar("SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and tbl_name = \(table.quoted)")) as Binding??)
        guard let count = value as? Int64 else {
            return false
        }
        return count > 0
    }

    /// fts table or not
    public func isFts(_ table: String) -> Bool {
        let sql = "SELECT * FROM sqlite_master WHERE tbl_name = \(table.quoted) AND type = 'table'"
        let array = query(sql)
        guard array.count == 1 else { return false }
        let dic = array.first
        let str = (dic?["sql"] as? String) ?? ""
        return str.match("CREATE +VIRTUAL +TABLE")
    }

    // MARK: - Handlers

    public var busyTimeout: Double = 0 {
        didSet {
            sqlite3_busy_timeout(handle, Int32(busyTimeout * 1000))
        }
    }

    public typealias BusyHandler = (Int32) -> Int32
    public var busyHandler: BusyHandler? {
        didSet {
            if busyHandler != nil {
                sqlite3_busy_handler(handle, global_busy, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
            } else {
                sqlite3_busy_handler(handle, nil, nil)
            }
        }
    }

    public typealias Trace = (UInt32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
    public var trace: Trace? {
        didSet {
            if #available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
                if trace != nil {
                    sqlite3_trace_v2(handle, 0, global_trace, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
                } else {
                    sqlite3_trace_v2(handle, 0, nil, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
                }
            }
        }
    }

    public typealias UpdateHook = (Int32, UnsafePointer<Int8>, UnsafePointer<Int8>, Int64) -> Void
    public var updateHook: UpdateHook?

    public typealias CommitHook = () -> Int32
    public var commitHook: CommitHook?

    public typealias RollbackHook = () -> Void
    public var rollbackHook: RollbackHook? {
        didSet {
            if busyHandler != nil {
                sqlite3_rollback_hook(handle, global_rollback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
            } else {
                sqlite3_rollback_hook(handle, nil, nil)
            }
        }
    }

    public typealias TraceError = (Int32, String, String) -> Void
    public var traceError: TraceError?

    // MARK: - Error Handling

    @discardableResult
    func check(_ resultCode: Int32, statement: Statement? = nil) throws -> Int32 {
        guard let error = Result(errorCode: resultCode, db: self, statement: statement) else {
            return resultCode
        }

        throw error
    }
}

// MAKR: - Hook
fileprivate typealias cBusyHandler = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32
fileprivate typealias cTraceHook = @convention(c) (UInt32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
fileprivate typealias cCommitHook = @convention(c) (UnsafeMutableRawPointer?) -> Int32
fileprivate typealias cRollbackHook = @convention(c) (UnsafeMutableRawPointer?) -> Void
fileprivate typealias cUpdateHook = @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<Int8>?, UnsafePointer<Int8>?, sqlite3_int64) -> Void

fileprivate let global_busy: cBusyHandler = { (pCtx, times) -> Int32 in
    let db: Database? = unsafeBitCast(pCtx, to: Database.self)
    guard db != nil && db?.busyHandler != nil else { return 0 }
    return db!.busyHandler!(times)
}

fileprivate let global_trace: cTraceHook = { (mask, pCtx, p, x) -> Int32 in
    let db: Database? = unsafeBitCast(pCtx, to: Database.self)
    guard db != nil && db?.trace != nil else { return 0 }
    return db!.trace!(mask, p, x)
}

fileprivate let global_update: cUpdateHook = { (pCtx, _, db, _, _) -> Void in
    let db: Database? = unsafeBitCast(pCtx, to: Database.self)

    guard db != nil else { return }
    db!.cache.removeAllObjects()
}

fileprivate let global_commit: cCommitHook = { (pCtx) -> Int32 in
    let db: Database? = unsafeBitCast(pCtx, to: Database.self)
    guard db != nil else { return 0 }
    db!.cache.removeAllObjects()
    return 0
}

fileprivate let global_rollback: cRollbackHook = { (pCtx) -> Void in
    let db: Database? = unsafeBitCast(pCtx, to: Database.self)
    guard db != nil else { return }
}

extension Database: CustomStringConvertible {
    public var description: String {
        return String(cString: sqlite3_db_filename(handle, nil))
    }
}

extension Database.Location: CustomStringConvertible {
    public var description: String {
        switch self {
            case .memory:
                return ":memory:"
            case .temporary:
                return ""
            case let .uri(URI):
                return URI
        }
    }
}

public enum Result: Error {
    fileprivate static let successCodes: Set = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE]

    case error(message: String, code: Int32, statement: Statement?)

    init?(errorCode: Int32, db: Database, statement: Statement? = nil) {
        guard !Result.successCodes.contains(errorCode) else { return nil }

        let message = String(cString: sqlite3_errmsg(db.handle))
        let sql = statement?.description ?? ""
        if let trace = db.traceError {
            trace(errorCode, message, sql)
        } else {
            #if DEBUG
                print("[SQLiteORM][Error] code: \(errorCode), error: \(message), sql: \(sql)\n")
            #endif
        }
        if errorCode == SQLITE_NOTADB && db.removeWhenNotADB {
            db.close()
            try? FileManager.default.removeItem(atPath: db.path)
        }
        self = .error(message: message, code: errorCode, statement: statement)
    }
}

extension Result: CustomStringConvertible {
    public var description: String {
        switch self {
            case let .error(message, errorCode, statement):
                if let statement = statement {
                    return "\(message) (\(statement)) (code: \(errorCode))"
                } else {
                    return "\(message) (code: \(errorCode))"
                }
        }
    }
}
