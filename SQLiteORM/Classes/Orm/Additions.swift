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
        let udid = location.description + "\(flags)" + encrypt as NSString
        var db = _pool.object(forKey: udid)
        guard db == nil else {
            return db
        }
        db = Database(location, flags: flags, encrypt: encrypt)
        _pool.setObject(db, forKey: udid)
        return db
    }
}

extension Database {
    private static let serialVal = "com.valo.sqliteorm.serial"
    private static let concurrentVal = "com.valo.sqliteorm.concurrent"
    private static let queueKey = DispatchSpecificKey<String>()

    /// 串行队列
    public static let serialQueue: DispatchQueue = {
        var queue = DispatchQueue(label: Database.serialVal, attributes: [])
        queue.setSpecific(key: Database.queueKey, value: Database.serialVal)
        return queue
    }()

    /// 并行队列
    public static let concurrentQueue: DispatchQueue = {
        var queue = DispatchQueue(label: Database.concurrentVal, attributes: .concurrent)
        queue.setSpecific(key: Database.queueKey, value: Database.concurrentVal)
        return queue
    }()

    /// 数据库同步操作
    ///
    /// - Parameter block: 具体操作
    /// - Returns: 是否操作成功
    /// - Throws: 操作中出现的错误
    public class func sync<T>(_ block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Database.queueKey) == Database.serialVal {
            return try block()
        } else {
            return try Database.serialQueue.sync(execute: block)
        }
    }

    /// 数据库异步操作
    ///
    /// - Parameter block: 具体操作
    /// - Returns: 是否操作成功
    /// - Throws: 操作中出现的错误
    public class func async(serial: Bool, block: @escaping () -> Void) {
        let queue = serial ? Database.serialQueue : Database.concurrentQueue
        queue.async(execute: block)
    }
}
