//
//  CURD.swift
//  SQLiteORM
//
//  Created by Valo on 2022/9/28.
//

import AnyCoder
import Foundation

open class CURD {
    /// database
    private(set) var db: Database?

    /// table name
    private(set) var table: String = ""

    /// query condition
    private(set) var `where`: Where = .empty

    public init() {}
}

public extension CURD {
    @discardableResult
    func db(_ closure: () -> Database) -> Self {
        db = closure()
        return self
    }

    @discardableResult
    func table(_ closure: () -> String) -> Self {
        table = closure()
        return self
    }

    @discardableResult
    func orm<T>(_ closure: () -> Orm<T>) -> Self {
        let orm = closure()
        db = orm.db
        table = orm.table
        return self
    }

    @discardableResult
    func `where`(_ closure: () -> Where) -> Self {
        self.where = closure()
        return self
    }
}

func encodeToKeyValue(_ item: Any) throws -> [String: Primitive] {
    let dic: [String: Primitive]
    if let item = item as? [String: Primitive] {
        dic = item
    } else if let item = item as? any Codable {
        dic = try ManyEncoder().encode(item)
    } else {
        dic = try AnyEncoder.encode(item)
    }
    return dic
}

func constraint(of bindings: [String: Primitive], _ config: Config) -> [String: Primitive] {
    guard let config = config as? PlainConfig else { return [:] }
    if config.primaries.count > 0 {
        let filtered = bindings.filter { config.primaries.contains($0.key) }
        if filtered.count == config.primaries.count { return filtered }
    }
    if config.uniques.count > 0 {
        let filtered = bindings.filter { config.uniques.contains($0.key) }
        if filtered.count > 0 { return filtered }
    }
    return [:]
}

func constraint(of bindings: [String: Primitive], with uniques: [String]) -> [String: Primitive] {
    guard uniques.count > 0 else { return [:] }
    let filtered = bindings.filter { uniques.contains($0.key) }
    if filtered.count > 0 { return filtered }
    return [:]
}

func constraint(for item: Any, _ config: Config) -> [String: Primitive] {
    do {
        let bindings = try encodeToKeyValue(item)
        return constraint(of: bindings, config)
    } catch _ {
        return [:]
    }
}

func constraint(for item: Any, with uniques: [String]) -> [String: Primitive] {
    do {
        let bindings = try encodeToKeyValue(item)
        return constraint(of: bindings, with: uniques)
    } catch _ {
        return [:]
    }
}
