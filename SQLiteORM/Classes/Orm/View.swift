//
//  View.swift
//  SQLiteORM
//
//  Created by Valo on 2019/10/15.
//

import Foundation

// TODO: 未测试
public class View<T: Codable> {
    public let temp: Bool
    public let name: String
    public let columns: [String]?
    public let table: String
    public let condition: Where

    public let db: Database
    public let config: Config
    public let properties: [String: PropertyInfo]

    private let decoder = OrmDecoder()

    public init(_ name: String,
                temp: Bool = false,
                columns: [String]? = nil,
                condition: Where,
                table: String = "",
                db: Database = Database(.temporary),
                config: Config) {
        assert(config.type != nil && config.columns.count > 0, "invalid config")

        self.temp = temp
        self.name = name
        self.columns = columns

        self.condition = condition
        self.db = db
        self.config = config

        var props: [String: PropertyInfo] = [:]
        let info = try? typeInfo(of: config.type!)
        if info != nil {
            for prop in info!.properties {
                props[prop.name] = prop
            }
        }
        properties = props

        if table.count > 0 {
            self.table = table
        } else {
            self.table = info?.name ?? ""
        }
    }

    public convenience init<S>(_ name: String,
                               temp: Bool = false,
                               columns: [String]? = nil,
                               condition: Where,
                               orm: Orm<S>) {
        self.init(name, temp: temp, columns: columns, condition: condition, table: orm.table, db: orm.db, config: orm.config)
    }

    @discardableResult
    public func create() -> Bool {
        var cols: [String] = []
        if let c = columns, c.count > 0 {
            let all = Set(config.columns)
            let sub = Set(c)
            cols = Array(sub.intersection(all))
        } else {
            cols = config.columns
        }

        let sql = "CREATE " + (temp ? "TEMP " : "") +
            " VIEW IF NOT EXISTS " + name.quoted + " AS " +
            " SELECT " + cols.sqlJoined +
            " FROM " + table.quoted +
            " WHERE " + condition.sql

        do {
            try db.execute(sql)
        } catch _ {
            assert(false, "create view failure")
            return false
        }
        return true
    }

    var exist: Bool {
        let sql = "SELECT count(*) as 'count' FROM sqlite_master WHERE type ='view' and tbl_name = " + name.quoted
        return (try? db.scalar(sql) as? Bool) ?? false
    }

    @discardableResult
    func drop() -> Bool {
        let sql = "DROP VIEW IF EXISTS " + name.quoted
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }
}

public extension View {
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
        return Select().table(name).where(condition).orderBy(orderBy).limit(1).allKeyValues(db).first
    }

    /// 查找一条数据
    ///
    /// - Parameters:
    ///   - condition: 查询条件
    ///   - orderBy: 排序方式
    /// - Returns: [String:Binding]数据,需自行转换成对应的数据类型
    func xFindOne(_ condition: Where = Where(""), orderBy: OrderBy = OrderBy("")) -> T? {
        return Select().table(name).where(condition).orderBy(orderBy).limit(1).allItems(db, type: T.self, decoder: decoder).first
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
        return Select().table(name).where(condition).distinct(distinct).fields(fields)
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
        return Select().table(name).where(condition).distinct(distinct).fields(fields)
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
    func exist(_ item: T) -> Bool {
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
        let dic = Select().table(name).fields(Fields(function)).where(condition).allKeyValues(db).first
        return dic?.values.first
    }
}
