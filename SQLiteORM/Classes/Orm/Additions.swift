//
//  Additions.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/10.
//

import Foundation

extension Database {
    /// 数据库对象池
    private static let _pool = NSMapTable<NSString, Database>.strongToWeakObjects()

    /// 从数据库对象池创建数据库.若池中存在,则直接取出.否则创建并放入池中
    ///
    /// - Parameters:
    ///   - location: 数据库位置/路径
    ///   - flags: 打开数据库的flags
    ///   - encrypt: 加密字符串
    /// - Returns: 数据库
    public class func fromPool(_ location: Location = .temporary, flags: Int32 = 0, encrypt: String = "") -> Database? {
        let udid = location.description + "\(flags)" + encrypt
        let db = _pool.object(forKey: udid as NSString)
        guard db == nil else {
            return db!
        }
        return Database(location, flags: flags, encrypt: encrypt)
    }
}

extension Database {
    private static let _queueContext: Int = unsafeBitCast(Database.self, to: Int.self)
    private static let _queueKey = DispatchSpecificKey<Int>()
    private static let _queue: DispatchQueue = {
        var queue = DispatchQueue(label: "SQLite.ORM", attributes: [])
        queue.setSpecific(key: Database._queueKey, value: Database._queueContext)
        return queue
    }()

    /// 数据库同步操作
    ///
    /// - Parameter block: 具体操作
    /// - Returns: 是否操作成功
    /// - Throws: 操作中出现的错误
    public class func sync<T>(_ block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Database._queueKey) == Database._queueContext {
            return try block()
        } else {
            return try Database._queue.sync(execute: block)
        }
    }

    /// 数据库异步操作
    ///
    /// - Parameter block: 具体操作
    /// - Returns: 是否操作成功
    /// - Throws: 操作中出现的错误
    public class func async(_ block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: Database._queueKey) == Database._queueContext {
            block()
        } else {
            Database._queue.async(execute: block)
        }
    }
}
