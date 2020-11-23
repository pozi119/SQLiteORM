//
//  Cache.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/24.
//

import Foundation

/// simple cache
open class Cache<Key, Value> where Key: Hashable {
    /// cache name
    open var name: String = ""

    /// maximun number of cache objects
    open var countLimit: Int = 1024

    /// container
    private var storage = [Key: Value]()

    /// LRU
    private var lru = [Key: UInt64]()

    /// get object
    open func object(forKey key: Key) -> Value? {
        let value = storage[key]
        if value != nil {
            lru[key] = (lru[key] ?? 0) + 1
        }
        return value
    }

    /// save object
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

    /// remove object
    open func removeObject(forKey key: Key) {
        storage.removeValue(forKey: key)
        lru.removeValue(forKey: key)
    }

    /// remove all objects
    open func removeAllObjects() {
        storage.removeAll()
        lru.removeAll()
    }

    open subscript(key: Key) -> Value? {
        get {
            return object(forKey: key)
        }
        set(newValue) {
            guard let value = newValue else {
                removeObject(forKey: key)
                return
            }
            setObject(value, forKey: key)
        }
    }
}
