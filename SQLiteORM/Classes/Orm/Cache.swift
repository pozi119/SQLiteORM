//
//  Cache.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/24.
//

import Foundation

/// 简单缓存
open class Cache<Key, Value>: NSObject where Key: Hashable, Value: Any {
    /// 缓存名
    open var name: String = ""

    /// 最大缓存数量
    open var countLimit: Int = 1024

    /// 实际存储对象
    private var storage = [Key: Value]()

    /// 简单lru算法存储对象
    private var lru = [Key: UInt64]()

    /// 获取对象
    ///
    /// - Parameter key: key
    /// - Returns: 缓存的对象
    open func object(forKey key: Key) -> Value? {
        let value = storage[key]
        if value != nil {
            lru[key] = (lru[key] ?? 0) + 1
        }
        return value
    }

    /// 存储对象
    ///
    /// - Parameters:
    ///   - obj: 要存储的对象
    ///   - key: key
    open func setObject(_ obj: Value, forKey key: Key) {
        storage[key] = obj
        lru[key] = (lru[key] ?? 0) + 1
        if lru.count > countLimit {
            let sorted = lru.sorted(by: { $0.1 < $1.1 })
            let will = lru.count / 2
            let half = sorted[0 ... will]
            let keys = half.map { $0.key }
            lru.removeValues(forKeys: keys)
            storage.removeValues(forKeys: keys)
        }
    }

    /// 移除对象
    ///
    /// - Parameter key: key
    open func removeObject(forKey key: Key) {
        storage.removeValue(forKey: key)
        lru.removeValue(forKey: key)
    }

    /// 移除所有对象
    open func removeAllObjects() {
        storage.removeAll()
        lru.removeAll()
    }
}
