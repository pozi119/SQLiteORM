//
//  Create.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import Foundation

// MARK: - 私有函数

extension Orm {
    fileprivate enum Update {
        case insert, upsert, update
    }

    fileprivate func _update(_ bindings: [String: Binding], type: Update = .insert, condition: Where = Where("")) -> Bool {
        guard bindings.count > 0 else {
            return false
        }
        var dic = bindings
        switch config {
        case let config as PlainConfig:
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
        let values = fields.map { dic[$0] } as! [Binding]
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
            try db.prepare(sql, values).run()
        } catch _ {
            return false
        }
        return true
    }

    fileprivate func _update(multi items: [[String: Binding]], type: Update = .insert, condition: Where = Where("")) -> Int64 {
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
}

// MARK: - 创建数据

public extension Orm {
    /// 插入一条数据
    ///
    /// - Parameter item: 要插入的数据
    /// - Returns: 是否插入成功
    @discardableResult
    func insert<T: Codable>(_ item: T) -> Bool {
        let dic = try? encoder.encode(item)
        return _update(dic as! [String: Binding])
    }

    @discardableResult
    func insert(keyValues: [String: Binding]) -> Bool {
        return _update(keyValues)
    }

    /// 插入多条数据
    ///
    /// - Parameter items: 要插入的数据
    /// - Returns: 插入成功的数量
    @discardableResult
    func insert<T: Codable>(multi items: [T]) -> Int64 {
        let array = items.map { try? encoder.encode($0) } as! [[String: Binding]]
        return _update(multi: array)
    }

    @discardableResult
    func insert(multiKeyValues: [[String: Binding]]) -> Int64 {
        return _update(multi: multiKeyValues)
    }

    /// 插入或更新一条数据
    ///
    /// - Parameter item: 要插入的数据
    /// - Returns: 是否插入或更新成功
    @discardableResult
    func upsert<T: Codable>(_ item: T) -> Bool {
        let dic = try? encoder.encode(item)
        return _update(dic as! [String: Binding], type: .upsert)
    }

    @discardableResult
    func upsert(keyValues: [String: Binding]) -> Bool {
        return _update(keyValues, type: .upsert)
    }

    /// 插入或更新多条数据
    ///
    /// - Parameter items: 要插入的数据
    /// - Returns: 插入或更新成功的数量
    @discardableResult
    func upsert<T: Codable>(multi items: [T]) -> Int64 {
        let array = items.map { try? encoder.encode($0) } as! [[String: Binding]]
        return _update(multi: array, type: .upsert)
    }

    @discardableResult
    func upsert(multiKeyValues: [[String: Binding]]) -> Int64 {
        return _update(multi: multiKeyValues, type: .upsert)
    }
}

// MARK: - Update

public extension Orm {
    /// 更新数据
    ///
    /// - Parameters:
    ///   - condition: 条件
    ///   - bindings: [字段:数据]
    /// - Returns: 是否更新成功
    @discardableResult
    func update(_ condition: Where, with bindings: [String: Binding]) -> Bool {
        return _update(bindings, type: .upsert, condition: condition)
    }

    /// 更新一条数据
    ///
    /// - Parameter item: 要更新的数据
    /// - Returns: 是否更新成功
    @discardableResult
    func update<T: Codable>(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        let bindings = try! encoder.encode(item) as! [String: Binding]
        return _update(bindings, type: .upsert, condition: condition)
    }

    /// 更新一条数据,指定要更新的字段
    ///
    /// - Parameters:
    ///   - item: 要更新的数据
    ///   - fields: 指定字段
    /// - Returns: 是否更新成功
    @discardableResult
    func update<T: Codable>(_ item: T, fields: [String]) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        var bindings = try! encoder.encode(item) as! [String: Binding]
        let trashKeys = Array(Set(bindings.keys).subtracting(fields))
        bindings.removeValues(forKeys: trashKeys)
        return _update(bindings, type: .upsert, condition: condition)
    }

    /// 更新多条数据
    ///
    /// - Parameter items: 要更新的数据
    /// - Returns: 更新成功的数量
    @discardableResult
    func update<T: Codable>(multi items: [T]) -> Int64 {
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

    /// 更新多条数据,指定要更新的字段
    ///
    /// - Parameters:
    ///   - items: 要更新的数据
    ///   - fields: 指定字段
    /// - Returns: 更新成功的数量
    @discardableResult
    func update<T: Codable>(multi items: [T], fields: [String]) -> Int64 {
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

    /// 对指定字段进行`加/减`操作
    ///
    /// - Parameters:
    ///   - condition: 更新条件
    ///   - field: 指定字段
    ///   - value: 更新的值,比如: 2表示加2, -2表示减2
    /// - Returns: 是否更新成功
    @discardableResult
    func increase(_ condition: Where, field: String, value: Int) -> Bool {
        return _update([field: value], type: .update, condition: condition)
    }
}

// MARK: - Retrieve

public extension Orm {
    /// 最大rowid. 此rowid,自增主键和数据条数不一定一致
    var maxRowId: Int64 {
        return max(of: "rowid") as? Int64 ?? 0
    }

    /// 查找一条数据
    ///
    /// - Parameters:
    ///   - condition: 查询条件
    ///   - orderBy: 排序方式
    /// - Returns: [String:Binding]数据,需自行转换成对应的数据类型
    func findOne(_ condition: Where = Where(""), orderBy: OrderBy = OrderBy("")) -> [String: Binding]? {
        return Select().table(table).where(condition).orderBy(orderBy).limit(1).allKeyValues(db).first
    }

    /// 查找一条数据
    ///
    /// - Parameters:
    ///   - condition: 查询条件
    ///   - orderBy: 排序方式
    /// - Returns: [String:Binding]数据,需自行转换成对应的数据类型
    func xFindOne(_ condition: Where = Where(""), orderBy: OrderBy = OrderBy("")) -> T? {
        return Select().table(table).where(condition).orderBy(orderBy).limit(1).allItems(db, type: T.self, decoder: decoder).first
    }

    /// 查询数据
    ///
    /// - Parameters:
    ///   - condition: 查询条件
    ///   - distinct: 是否去重
    ///   - fields: 指定字段
    ///   - groupBy: 分组字段
    ///   - having: 分组条件
    ///   - orderBy: 排序条件
    ///   - limit: 查询数量
    ///   - offset: 起始位置
    /// - Returns: [[String:Binding]]数据,需自行转换成对应数据类型
    func find(_ condition: Where = Where(""),
              distinct: Bool = false,
              fields: Fields = Fields("*"),
              groupBy: GroupBy = GroupBy(""),
              having: Where = Where(""),
              orderBy: OrderBy = OrderBy(""),
              limit: Int64 = 0,
              offset: Int64 = 0) -> [[String: Binding]] {
        return Select().table(table).where(condition).distinct(distinct).fields(fields)
            .groupBy(groupBy).having(having).orderBy(orderBy)
            .limit(limit).offset(offset).allKeyValues(db)
    }

    /// 查询数据
    ///
    /// - Parameters:
    ///   - condition: 查询条件
    ///   - distinct: 是否去重
    ///   - fields: 指定字段
    ///   - groupBy: 分组字段
    ///   - having: 分组条件
    ///   - orderBy: 排序条件
    ///   - limit: 查询数量
    ///   - offset: 起始位置
    /// - Returns: [[String:Binding]]数据,需自行转换成对应数据类型
    func xFind(_ condition: Where = Where(""),
               distinct: Bool = false,
               fields: Fields = Fields("*"),
               groupBy: GroupBy = GroupBy(""),
               having: Where = Where(""),
               orderBy: OrderBy = OrderBy(""),
               limit: Int64 = 0,
               offset: Int64 = 0) -> [T] {
        return Select().table(table).where(condition).distinct(distinct).fields(fields)
            .groupBy(groupBy).having(having).orderBy(orderBy)
            .limit(limit).offset(offset).allItems(db, type: T.self, decoder: decoder)
    }

    /// 查询数据条数
    ///
    /// - Parameter condition: 查询条件
    /// - Returns: 数据条数
    func count(_ condition: Where = Where("")) -> Int64 {
        return function("count(*)", condition: condition) as? Int64 ?? 0
    }

    /// 是否存在某条数据
    ///
    /// - Parameter item: 要查询的数据
    /// - Returns: 是否存在
    func exist<T: Codable>(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        return count(condition) > 0
    }

    func exist(_ keyValues: [String: Binding]) -> Bool {
        guard let condition = config.constraint(for: keyValues) else { return false }
        return count(condition) > 0
    }

    /// 获取某个字段的最大值
    ///
    /// - Parameters:
    ///   - field: 字段名
    ///   - condition: 查询条件
    /// - Returns: 最大值
    func max(of field: String, condition: Where = Where("")) -> Binding? {
        return function("max(\(field))", condition: condition)
    }

    /// 获取某个字段的最小值
    ///
    /// - Parameters:
    ///   - field: 字段名
    ///   - condition: 查询条件
    /// - Returns: 最小值
    func min(of field: String, condition: Where = Where("")) -> Binding? {
        return function("min(\(field))", condition: condition)
    }

    /// 获取某个字段的数据的总和
    ///
    /// - Parameters:
    ///   - field: 字段名
    ///   - condition: 查询条件
    /// - Returns: 求和
    func sum(of field: String, condition: Where = Where("")) -> Binding? {
        return function("sum(\(field))", condition: condition)
    }

    /// 执行某些简单函数,如max(),min(),sum()
    ///
    /// - Parameters:
    ///   - function: 函数名
    ///   - condition: 查询条件
    /// - Returns: 函数执行结果
    func function(_ function: String, condition: Where = Where("")) -> Binding? {
        let dic = Select().table(table).fields(Fields(function)).where(condition).allKeyValues(db).first
        return dic?.values.first
    }
}

// MARK: - Delete

public extension Orm {
    /// 删除表
    ///
    /// - Attention: 删除表后,若需重新访问,请重新生成Orm.请慎用
    /// - Returns: 是否删除成功
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

    /// 删除数据
    ///
    /// - Parameter item: 要删除的数据
    /// - Attention: 若数据无主键,则可能删除该表所有数据,请慎用
    /// - Returns: 是否删除成功
    @discardableResult
    func delete(_ item: Codable) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        return delete(where: condition)
    }

    /// 删除多条数据
    ///
    /// - Parameter items: 要删除的数据
    /// - Attention: 若数据无主键,则可能删除该表所有数据,请慎用
    /// - Returns: 是否删除成功
    @discardableResult
    func delete(_ items: [Codable]) -> Int64 {
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

    /// 删除数据
    ///
    /// - Parameter condition: 删除条件
    /// - Returns: 是否删除成功
    @discardableResult
    func delete(where condition: Where = Where("")) -> Bool {
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
