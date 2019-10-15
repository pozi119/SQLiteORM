//
//  Database.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Dispatch
import Foundation

#if SQLITE_SWIFT_STANDALONE
    import sqlite3
#elseif SQLITE_SWIFT_SQLCIPHER
    import SQLCipher
#elseif os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

/// sqlite3 数据库
public final class Database {
    /// 数据库位置
    ///
    /// - memory: 内存数据库
    /// - temporary: 临时数据库
    /// - uri: 指定路径
    public enum Location {
        case memory
        case temporary
        case uri(String)
    }

    /// sqlite3 db句柄
    var handle: OpaquePointer {
        if _handle == nil {
            try! open()
        }
        return _handle!
    }

    /// 数据库路径
    public var path: String { return _path }

    /// 默认Open flags
    private let _essential: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    private var _flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

    fileprivate var _handle: OpaquePointer?
    fileprivate var _path: String = ""
    fileprivate var encrypt: String = ""
    fileprivate var flags: Int32 {
        get {
            return _flags
        }
        set {
            _flags = newValue | _essential
        }
    }

    private static var _caches = [String: Cache<String, Any>]()

    /// query缓存
    lazy var cache: Cache<String, Any> = {
        var _cache: Cache? = Database._caches[path]
        guard _cache == nil else { return _cache! }
        _cache = Cache<String, Any>()
        Database._caches[path] = _cache!
        return _cache!
    }()

    /// 初始化数据库
    ///
    /// - Parameters:
    ///   - location: 位置
    ///   - flags: sqlite3 open flags
    ///   - encrypt: 加密密码
    public init(_ location: Location = .temporary, flags: Int32 = 0, encrypt: String = "") {
        _path = location.description
        self.flags = flags
        self.encrypt = encrypt
    }

    /// 从指定路径创建
    ///
    /// - Parameter path: 数据库文件路径
    public convenience init(with path: String) {
        self.init(.uri(path), flags: 0, encrypt: "")
    }

    deinit {
        close()
    }

    /// 打开数据库
    ///
    /// - Throws: 打开过程中出现的错误
    public func open() throws {
        try check(sqlite3_open_v2(path, &_handle, flags, nil))
        #if SQLITE_SWIFT_SQLCIPHER
            if encrypt.count > 0 {
                // try check(key(encrypt))
            }
        #endif

        setOptions(["PRAGMA synchronous='NORMAL'",
                    "PRAGMA journal_mode=wal"])

        sqlite3_update_hook(handle, global_update, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        sqlite3_commit_hook(handle, global_commit, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    }

    /// 数据库是否打开
    public var isOpen: Bool { return _handle != nil }

    /// 关闭数据库
    public func close() {
        if _handle != nil {
            sqlite3_close(_handle)
        }
        _handle = nil
    }

    /// 配置数据库
    ///
    /// - Parameter sqls: 配置数据库的sql语句.原生语句,未封装
    public func setOptions(_ sqls: [String]) {
        for sql in sqls {
            _ = query(sql)
        }
    }

    // MARK: -

    /// 数据库是否只读.目前默认`open flags`设置为可读写
    public var readonly: Bool { return sqlite3_db_readonly(handle, nil) == 1 }

    /// 最后一次插入操作的rowid
    public var lastInsertRowid: Int64 {
        return sqlite3_last_insert_rowid(handle)
    }

    /// 最后一次操作影响的数据条数
    public var changes: Int {
        return Int(sqlite3_changes(handle))
    }

    /// 打开数据库后修改/更新的数据总数??
    public var totalChanges: Int {
        return Int(sqlite3_total_changes(handle))
    }

    // MARK: - Execute

    /// 执行指定sql语句
    ///
    /// - Parameter SQL: sql语句
    /// - Throws: 执行过程中的错误
    public func execute(_ SQL: String) throws {
        _ = try check(sqlite3_exec(handle, SQL, nil, nil, nil))
    }

    // MARK: - Prepare

    /// 准备statement
    ///
    /// - Parameter statement: sql语句
    /// - Returns: 准备好的sqlite3 statement
    /// - Throws: 准备过程中出现的错误
    public func prepare(_ statement: String) throws -> Statement {
        return try Statement(self, statement)
    }

    /// 准备statement
    ///
    /// - Parameters:
    ///   - statement: sql语句
    ///   - bindings: 绑定的数据,需和sql语句对应
    /// - Returns: 准备好的sqlite3 statement
    /// - Throws: 准备过程中出现的错误
    public func prepare(_ statement: String, _ bindings: [Binding]) throws -> Statement {
        return try prepare(statement).bind(bindings)
    }

    // MARK: - Merge

    public var updateInterval: CFAbsoluteTime = 0 {
        willSet {
            #if os(iOS)
                let name = UIApplication.willTerminateNotification
            #elseif os(OSX)
                let name = NSApplication.willTerminateNotification
            #else
                let name = "unsupported"
            #endif
            if newValue > 0 {
                NotificationCenter.default.addObserver(self, selector: #selector(runMergeUpdates), name: name, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: name, object: nil)
            }
        }
    }

    private var updates: [(String, [Binding])] = []

    private func merge(_ sql: String, values: [Binding]) -> Bool {
        guard updateInterval > 0 else {
            return false
        }
        if updates.count == 0 {
            let deadline = DispatchTime.now() + updateInterval
            Database.serialQueue.asyncAfter(deadline: deadline) {
                self.runMergeUpdates()
            }
        }
        updates.append((sql, values))
        return true
    }

    @objc @discardableResult
    private func runMergeUpdates() -> Bool {
        #if DEBUG
            print("[SQLiteORM][Merge] now: \(CFAbsoluteTimeGetCurrent()), count: \(updates.count), db: \((_path as NSString).lastPathComponent)\n")
        #endif

        guard updates.count > 0 else {
            return true
        }

        let array = updates
        updates.removeAll()

        do {
            try transaction(.immediate) {
                for (sql, values) in array {
                    try prepare(sql, values).run()
                }
            }
        } catch _ {
            return false
        }

        return true
    }

    // MARK: - Run

    /// 查询数据
    ///
    /// - Parameter statement: sql语句
    /// - Returns: 查询结果
    public func query(_ statement: String) -> [[String: Binding]] {
        return (try? prepare(statement).query()) ?? []
    }

    /// 执行语句
    ///
    /// - Parameter statement: sql语句
    /// - Throws: 准备过程中的错误
    public func run(_ statement: String) throws {
        guard !merge(statement, values: []) else {
            return
        }
        return try prepare(statement).run()
    }

    /// 执行语句
    ///
    /// - Parameters:
    ///   - statement: sql语句
    ///   - bindings: 绑定的数据,需和sql语句对应
    /// - Throws: 准备过程中出现的错误
    public func run(_ statement: String, _ bindings: [Binding]) throws {
        guard !merge(statement, values: bindings) else {
            return
        }
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

    /// 事务操作
    ///
    /// - Parameters:
    ///   - mode: 模式
    ///   - block: 具体操作
    /// - Throws: 事务操作过程中的错误
    public func transaction(_ mode: TransactionMode = .deferred, block: () throws -> Void) throws {
        try transaction("BEGIN \(mode.rawValue) TRANSACTION", block, "COMMIT TRANSACTION", or: "ROLLBACK TRANSACTION")
    }

    /// 检查点
    ///
    /// - Parameters:
    ///   - name: 检查点名称
    ///   - block: 具体操作
    /// - Throws: 事务操作过程中的错误
    public func savepoint(_ name: String = UUID().uuidString, block: () throws -> Void) throws {
        let name = name.quote("'")
        let savepoint = "SAVEPOINT \(name)"

        try transaction(savepoint, block, "RELEASE \(savepoint)", or: "ROLLBACK TO \(savepoint)")
    }

    /// 事务操作
    ///
    /// - Parameters:
    ///   - begin: 开始事务的sql语句
    ///   - block: 具体c操作
    ///   - commit: 提交事务的sql语句
    ///   - rollback: 回滚事务的sql语句
    /// - Throws: 事务操作过程中的错误
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

    /// 中断当前sqlite3操作
    public func interrupt() {
        sqlite3_interrupt(handle)
    }

    // MARK: - API

    /// 是否存在某张表
    ///
    /// - Parameter table: 表名
    /// - Returns: 是否存在
    public func exists(_ table: String) -> Bool {
        let value = ((try? scalar("SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and tbl_name = \(table.quoted)")) as Binding??)
        guard let count = value as? Int64 else {
            return false
        }
        return count > 0
    }

    /// 是否FTS数据表
    ///
    /// - Parameter table: 表名
    /// - Returns: 是否FTS数据表
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

    fileprivate typealias BusyHandler = (Int32) -> Int32
    fileprivate var busyHandler: BusyHandler? {
        didSet {
            if busyHandler != nil {
                sqlite3_busy_handler(handle, global_busy, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
            } else {
                sqlite3_busy_handler(handle, nil, nil)
            }
        }
    }

    fileprivate typealias Trace = (UInt32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
    fileprivate var trace: Trace? {
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

    fileprivate typealias UpdateHook = (Int32, UnsafePointer<Int8>, UnsafePointer<Int8>, Int64) -> Void
    fileprivate var updateHook: UpdateHook?

    fileprivate typealias CommitHook = () -> Int32
    fileprivate var commitHook: CommitHook?

    fileprivate typealias RollbackHook = () -> Void
    fileprivate var rollbackHook: RollbackHook? {
        didSet {
            if busyHandler != nil {
                sqlite3_rollback_hook(handle, global_rollback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
            } else {
                sqlite3_rollback_hook(handle, nil, nil)
            }
        }
    }

    // MARK: - Error Handling

    @discardableResult
    func check(_ resultCode: Int32, statement: Statement? = nil) throws -> Int32 {
        guard let error = Result(errorCode: resultCode, db: self, statement: statement) else {
            return resultCode
        }

        throw error
    }

    // MARK: - cipher

    #if SQLITE_SWIFT_SQLCIPHER
        public lazy var cipherVersion: String? = try? scalar("PRAGMA cipher_version") as? String

        public func key(_ key: String, db: String = "main") throws -> Void? {
            let data = key.data(using: .utf8)
            let bytes = [UInt8](data)
            try check(sqlite3_key_v2(handle, db, bytes, bytes.count))
            try scalar("SELECT count(*) FROM sqlite_master;")
        }

        public func rekey(_ key: String, db: String = "main") throws -> Void? {
            let data = key.data(using: .utf8)
            let bytes = [UInt8](data)
            try check(sqlite3_rekey_v2(handle, db, bytes, bytes.count))
        }
    #endif
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
        #if DEBUG
            print("[SQLiteORM][Error] code: \(errorCode), error: \(message), sql: \(String(describing: statement))\n")
        #endif
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
