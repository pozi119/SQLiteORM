//
//  CURD.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import AnyCoder
import Foundation

// MARK: - private functions

extension Orm {
    fileprivate enum Update {
        case insert, upsert, update
    }

    fileprivate func _update(_ bindings: [String: Primitive], type: Update = .insert, condition: Where = .empty) -> Bool {
        guard bindings.count > 0 else { return false }
        try? create()

        var dic = bindings
        switch config {
        case let config as PlainConfig:
            dic.removeValues(forKeys: config.blacks)
            if type == .insert && config.primaries.count == 1 && config.pkAutoInc {
                dic.removeValues(forKeys: config.primaries)
            }
            if config.logAt {
                let now = NSDate().timeIntervalSince1970
                if type != .update {
                    dic[Config.createAt] = now
                }
                dic[Config.updateAt] = now
            }
        default:
            break
        }
        var sql = ""
        let fields = dic.keys
        let values = fields.map { dic[$0] } as! [Primitive]
        switch type {
        case .insert, .upsert:
            let keys = fields.map { $0.quoted }.joined(separator: ",")
            let marks = Array(repeating: "?", count: dic.count).joined(separator: ",")
            sql = ((type == .upsert) ? "INSERT OR REPLACE" : "INSERT") + " INTO \(table.quoted) (\(keys)) VALUES (\(marks))"
        case .update:
            let sets = fields.map { $0.quoted + "=?" }.joined(separator: ",")
            var whereClause = condition.sql
            whereClause = whereClause.count > 0 ? "WHERE \(whereClause)" : ""
            sql = "UPDATE \(table.quoted) SET \(sets) \(whereClause)"
        }
        do {
            try db.prepare(sql, bind: values).run()
        } catch _ {
            return false
        }
        return true
    }

    fileprivate func _update(multi items: [[String: Primitive]], type: Update = .insert, condition: Where = .empty) -> Int64 {
        var count: Int64 = 0
        do {
            try db.transaction(.immediate) {
                for item in items {
                    let ret = _update(item, type: type, condition: condition)
                    count += ret ? 1 : 0
                }
            }
        } catch _ {
            return count
        }
        return count
    }

    func encode(_ item: Any) throws -> [String: Primitive] {
        let dic: [String: Primitive]
        if let item = item as? any Codable {
            dic = try ManyEncoder().encode(item)
        } else {
            dic = try AnyEncoder.encode(item)
        }
        let filtered = dic.filter { config.columns.contains($0.key) }
        return filtered
    }
}

// MARK: - insert

public extension Orm {
    /// insert a item
    @discardableResult
    func insert(_ item: T) -> Bool {
        do {
            let encoded = try encode(item)
            return _update(encoded, type: .insert)
        } catch {
            return false
        }
    }

    @discardableResult
    func insert(keyValues: [String: Primitive]) -> Bool {
        return _update(keyValues)
    }

    /// insert multiple items
    ///
    /// - Returns: number of successes
    @discardableResult
    func insert(multi items: [T]) -> Int64 {
        var array: [[String: Primitive]] = []
        for item in items {
            if let kv = try? encode(item) {
                array.append(kv)
            }
        }
        return _update(multi: array, type: .insert)
    }

    @discardableResult
    func insert(multiKeyValues: [[String: Primitive]]) -> Int64 {
        return _update(multi: multiKeyValues)
    }

    /// insert or update a item
    @discardableResult
    func upsert(_ item: T) -> Bool {
        do {
            let encoded = try encode(item)
            return _update(encoded, type: .upsert)
        } catch {
            return false
        }
    }

    @discardableResult
    func upsert(keyValues: [String: Primitive]) -> Bool {
        return _update(keyValues, type: .upsert)
    }

    /// insert or update multiple records
    ///
    /// - Returns: number of successes
    @discardableResult
    func upsert(multi items: [T]) -> Int64 {
        var array: [[String: Primitive]] = []
        for item in items {
            if let kv = try? encode(item) {
                array.append(kv)
            }
        }
        return _update(multi: array, type: .upsert)
    }

    @discardableResult
    func upsert(multiKeyValues: [[String: Primitive]]) -> Int64 {
        return _update(multi: multiKeyValues, type: .upsert)
    }
}

// MARK: - Update

public extension Orm {
    /// update datas
    ///
    /// - Parameters:
    ///   - condition: condit
    ///   - bindings: [filed:data]
    @discardableResult
    func update(_ condition: Where, with bindings: [String: Primitive]) -> Bool {
        return _update(bindings, type: .update, condition: condition)
    }

    /// update a item
    @discardableResult
    func update(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        do {
            let encoded = try encode(item)
            return _update(encoded, type: .update, condition: condition)
        } catch {
            return false
        }
    }

    /// update a item, special the fields
    @discardableResult
    func update(_ item: T, fields: [String]) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        do {
            var encoded = try encode(item)
            let trashKeys = Array(Set(encoded.keys).subtracting(fields))
            encoded.removeValues(forKeys: trashKeys)
            return _update(encoded, type: .update, condition: condition)
        } catch {
            return false
        }
    }

    /// update multple items
    ///
    /// - Returns: number of successes
    @discardableResult
    func update(multi items: [T]) -> Int64 {
        var count: Int64 = 0
        do {
            try db.transaction(.immediate) {
                for item in items {
                    let ret = update(item)
                    count += ret ? 1 : 0
                }
            }
        } catch _ {
            return count
        }
        return count
    }

    /// update multple items, special the fileds
    ///
    /// - Returns: number of successes
    @discardableResult
    func update(multi items: [T], fields: [String]) -> Int64 {
        var count: Int64 = 0
        do {
            try db.transaction(.immediate) {
                for item in items {
                    let ret = update(item, fields: fields)
                    count += ret ? 1 : 0
                }
            }
        } catch _ {
            return count
        }
        return count
    }

    /// plus / minus on the specified field
    ///
    /// - Parameters:
    ///   - value: update value, example: 2 means plus 2, -2 means minus 2
    @discardableResult
    func increase(_ condition: Where, field: String, value: Int) -> Bool {
        return _update([field: value], type: .update, condition: condition)
    }
}

// MARK: - Retrieve

public extension Orm {
    /// maximum rowid. the maximum rowid, auto increment primary key and records count may not be the same
    var maxRowId: Int64 {
        return max(of: "rowid") as? Int64 ?? 0
    }

    /// find a record, not decoded
    ///
    /// - Parameters:
    /// - Returns: [String:Primitive], decoding with ORMDecoder
    func findOne(_ condition: Where = .empty, orderBy: OrderBy = .empty) -> [String: Primitive]? {
        return Select().orm(self).where(condition).orderBy(orderBy).limit(1).allKeyValues().first
    }

    /// find a record, decoded
    func xFindOne(_ condition: Where = .empty, orderBy: OrderBy = .empty) -> T? {
        return Select().where(condition).orderBy(orderBy).limit(1).allItems(self).first
    }

    /// find data, not decoded
    ///
    /// - Parameters:
    ///   - condition: query terms
    ///   - distinct: remove duplicate
    ///   - fields: special fields
    ///   - groupBy: fields for group
    ///   - having: condition for group
    ///   - orderBy: sort criteria
    ///   - limit: maximum number of results
    ///   - offset: starting position
    /// - Returns: [String:Primitive], decoding with ORMDecoder
    func find(_ condition: Where = .empty,
              distinct: Bool = false,
              fields: Fields = .empty,
              groupBy: GroupBy = .empty,
              having: Where = .empty,
              orderBy: OrderBy = .empty,
              limit: Int64 = 0,
              offset: Int64 = 0) -> [[String: Primitive]] {
        return Select().orm(self).where(condition).distinct(distinct).fields(fields)
            .groupBy(groupBy).having(having).orderBy(orderBy)
            .limit(limit).offset(offset).allKeyValues()
    }

    /// find data, decoded
    func xFind(_ condition: Where = .empty,
               distinct: Bool = false,
               fields: Fields = .empty,
               groupBy: GroupBy = .empty,
               having: Where = .empty,
               orderBy: OrderBy = .empty,
               limit: Int64 = 0,
               offset: Int64 = 0) -> [T] {
        return Select().where(condition).distinct(distinct).fields(fields)
            .groupBy(groupBy).having(having).orderBy(orderBy)
            .limit(limit).offset(offset).allItems(self)
    }

    /// get number of records
    func count(_ condition: Where = .empty) -> Int64 {
        return function("count(*)", condition: condition) as? Int64 ?? 0
    }

    /// check if a record exists
    func exist(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        return count(condition) > 0
    }

    /// check if a record exists
    func exist(_ keyValues: [String: Primitive]) -> Bool {
        guard let condition = config.constraint(for: keyValues) else { return false }
        return count(condition) > 0
    }

    /// get the maximum value of a field
    func max(of field: String, condition: Where = .empty) -> Primitive? {
        return function("max(\(field))", condition: condition)
    }

    /// get the minimum value of a field
    func min(of field: String, condition: Where = .empty) -> Primitive? {
        return function("min(\(field))", condition: condition)
    }

    /// get the sum value of a field
    func sum(of field: String, condition: Where = .empty) -> Primitive? {
        return function("sum(\(field))", condition: condition)
    }

    /// execute a function, such as: max(),min(),sum()
    ///
    /// - Parameters:
    ///   - function: function name
    /// - Returns: function result
    func function(_ function: String, condition: Where = .empty) -> Primitive? {
        let dic = Select().orm(self).fields(Fields(function)).where(condition).allKeyValues().first
        return dic?.values.first
    }
}

// MARK: - Delete

public extension Orm {
    /// delete a table
    ///
    /// - Attention: ffter deleting the table, if you need to access it again, please regenerate orm; **use caution**
    @discardableResult
    func drop() -> Bool {
        let sql = "DROP TABLE IF EXISTS \(table.quoted)"
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }

    /// delete a record
    ///
    /// - Attention: if the table has no primary key, all data in the table may be deleted;**use caution**
    @discardableResult
    func delete(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        return delete(where: condition)
    }

    /// delete multi records
    ///
    /// - Attention: if the table has no primary key, all data in the table may be deleted;**use caution**
    @discardableResult
    func delete(_ items: [T]) -> Int64 {
        var count: Int64 = 0
        do {
            try db.transaction(block: {
                for item in items {
                    let ret = delete(item)
                    count += ret ? 1 : 0
                }
            })
        } catch _ {
            return count
        }
        return count
    }

    /// delete records according to condition
    @discardableResult
    func delete(where condition: Where = .empty) -> Bool {
        let clause = condition.sql
        let sql = "DELETE FROM \(table.quoted)" + (clause.count > 0 ? " WHERE \(clause)" : "")
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }
}
