//
//  Update.swift
//  SQLiteORM
//
//  Created by Valo on 2022/9/28.
//

import AnyCoder
import Foundation

open class Update<T>: CURD {
    public enum Method {
        case insert, upsert, update
    }

    private let orm: Orm<T>

    private var method: Method = .insert

    private var items: [Any] = []

    private var fields: [String] = []

    public required init(_ orm: Orm<T>) {
        self.orm = orm
        super.init()
        self.orm { orm }
    }

    private lazy var validKeys: [String] = {
        let config = orm.config as? PlainConfig
        var props = fields
        // insert or upsert, need constraints
        if method != .update, !fields.isEmpty, let config = config {
            props += (config.primaries.isEmpty ? config.uniques : config.primaries)
        }
        var keys = props.isEmpty ? orm.config.columns : props
        // need to delete self increasing primary key
        if method == .insert,
           let config = config,
           config.primaries.count == 1,
           config.pkAutoInc {
            keys.removeAll { config.primaries.first! == $0 }
        }
        return keys
    }()

    fileprivate func keyValue(of item: Any) throws -> [String: Primitive] {
        var dic = try encodeToKeyValue(item)
        if let config = orm.config as? PlainConfig, config.logAt {
            let now = Date().timeIntervalSinceReferenceDate
            if method != .update {
                dic[Config.createAt] = now
            }
            dic[Config.updateAt] = now
        }
        return dic
    }

    private func prepare(_ keyValue: [String: Primitive]) -> (sql: String, values: [Primitive]) {
        var sql = ""
        let keys = keyValue.keys.filter { validKeys.contains($0) }
        let values = keys.map { keyValue[$0] } as! [Primitive]
        switch method {
        case .insert, .upsert:
            let keysString = keys.map { $0.quoted }.joined(separator: ",")
            let marksString = Array(repeating: "?", count: keyValue.count).joined(separator: ",")
            sql = ((method == .upsert) ? "INSERT OR REPLACE" : "INSERT") + " INTO \(table.quoted) (\(keysString)) VALUES (\(marksString))"
        case .update:
            let setsString = keys.map { $0.quoted + "=?" }.joined(separator: ",")
            let condition = self.where.isEmpty ? constraint(of: keyValue, orm.config).toWhere() : self.where
            let whereClause = condition.isEmpty ? "" : "WHERE \(condition)"
            sql = "UPDATE \(table.quoted) SET \(setsString) \(whereClause)"
        }
        return (sql, values)
    }

    private func run(_ tuple: (sql: String, values: [Primitive])) -> Bool {
        do {
            try orm.db.prepare(tuple.sql, bind: tuple.values).run()
        } catch _ {
            return false
        }
        return true
    }

    @discardableResult
    public func method(_ closure: () -> Method) -> Self {
        method = closure()
        return self
    }

    @discardableResult
    public func items(_ closure: () -> [Any]) -> Self {
        items = closure()
        return self
    }

    @discardableResult
    public func fields(_ closure: () -> [String]) -> Self {
        fields = closure()
        return self
    }

    public func execute() -> Int64 {
        let array = items.map { try? keyValue(of: $0) }.filter { $0 != nil }
        guard !array.isEmpty else { return 0 }
        let tuples = array.map { prepare($0!) }
        if tuples.count == 1 {
            return run(tuples.first!) ? 1 : 0
        }
        var count: Int64 = 0
        do {
            try orm.db.transaction(.immediate) {
                for tuple in tuples {
                    let ret = run(tuple)
                    count += ret ? 1 : 0
                }
            }
        } catch _ {
            return count
        }
        return count
    }
}

// MARK: - insert

public extension Orm {
    /// insert a item
    @discardableResult
    func insert(_ item: T) -> Bool {
        Update(self).method { .insert }.items { [item] }.execute() == 1
    }

    @discardableResult
    func insert(keyValues: [String: Primitive]) -> Bool {
        Update(self).method { .insert }.items { [keyValues] }.execute() == 1
    }

    /// insert multiple items
    ///
    /// - Returns: number of successes
    @discardableResult
    func insert(multi items: [T]) -> Int64 {
        Update(self).method { .insert }.items { items }.execute()
    }

    @discardableResult
    func insert(multiKeyValues: [[String: Primitive]]) -> Int64 {
        Update(self).method { .insert }.items { multiKeyValues }.execute()
    }
}

// MARK: - upsert

public extension Orm {
    /// insert or update a item
    @discardableResult
    func upsert(_ item: T) -> Bool {
        Update(self).method { .upsert }.items { [item] }.execute() == 1
    }

    @discardableResult
    func upsert(keyValues: [String: Primitive]) -> Bool {
        Update(self).method { .upsert }.items { [keyValues] }.execute() == 1
    }

    /// insert or update multiple records
    ///
    /// - Returns: number of successes
    @discardableResult
    func upsert(multi items: [T]) -> Int64 {
        Update(self).method { .upsert }.items { items }.execute()
    }

    @discardableResult
    func upsert(multiKeyValues: [[String: Primitive]]) -> Int64 {
        Update(self).method { .upsert }.items { multiKeyValues }.execute()
    }
}

// MARK: - update

public extension Orm {
    /// update datas
    ///
    /// - Parameters:
    ///   - condition: condit
    ///   - bindings: [filed:data]
    @discardableResult
    func update(with bindings: [String: Primitive], condition: (() -> String)? = nil) -> Bool {
        let up = Update(self).method { .update }.items { [bindings] }
        if let condition = condition {
            up.where(condition)
        }
        return up.execute() == 1
    }

    /// update a item
    @discardableResult
    func update(_ item: T) -> Bool {
        return Update(self).method { .update }.items { [item] }.execute() == 1
    }

    /// update a item, special the fields
    @discardableResult
    func update(_ item: T, fields: [String]) -> Bool {
        return Update(self).method { .update }.items { [item] }.fields { fields }.execute() == 1
    }

    /// update multple items
    ///
    /// - Returns: number of successes
    @discardableResult
    func update(multi items: [T]) -> Int64 {
        return Update(self).method { .update }.items { items }.execute()
    }

    /// update multple items, special the fileds
    ///
    /// - Returns: number of successes
    @discardableResult
    func update(multi items: [T], fields: [String]) -> Int64 {
        return Update(self).method { .update }.items { items }.fields { fields }.execute()
    }

    /// plus / minus on the specified field
    ///
    /// - Parameters:
    ///   - value: update value, example: 2 means plus 2, -2 means minus 2
    @discardableResult
    func increase(_ field: String, value: Int, condition: (() -> String)? = nil) -> Bool {
        guard value != 0 else { return true }
        let val = field + (value > 0 ? "+\(value)" : "\(value)")
        return update(with: [field: val], condition: condition)
    }
}
