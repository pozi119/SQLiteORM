//
//  View.swift
//  SQLiteORM
//
//  Created by Valo on 2019/10/15.
//

import Foundation

// TODO: 未测试
public class View<T: Codable> {
    private var type: T.Type
    private var map: [String: String]

    public private(set) var db: Database
    public private(set) var name: String
    public private(set) var temp: Bool

    private let encoder = OrmEncoder()
    private let decoder = OrmDecoder()

    public init(name: String,
                type: T.Type,
                db: Database,
                table: String,
                temp: Bool = false,
                map: [String: String] = [:]) {
        assert(name.count > 0 && table.count > 0, "invalid name or table")

        self.type = type
        self.db = db
        self.name = name
        self.temp = temp
        self.map = map
        
        create()
    }

    @discardableResult
    public func create() -> Bool {
        // create view
        let info: TypeInfo = try! typeInfo(of: type)
        var columns = [String]()
        var types = [String: String]()
        switch info.kind {
        case .class, .struct:
            for prop in info.properties {
                columns.append(prop.name)
                types[prop.name] = sqlType(of: prop.type)
            }
        default:
            assert(false, "unsupported type")
            return false
        }
        assert(columns.count > 0, "invalid type")

        var sql = "CREATE " + (temp ? "TEMP " : "") + "VIEW IF NOT EXISTS " + name.quoted
        var cols: [String] = []
        for col in columns {
            if let mapped = map[col] {
                cols.append(" \(mapped) AS \(col)")
            } else {
                cols.append(" \(col)")
            }
        }
        sql += cols.joined(separator: ",")

        do {
            try db.execute(sql)
        } catch _ {
            assert(false, "create view failure")
            return false
        }
        return true
    }
}

public extension View {
    func decode(_ keyValues: [String: Binding]) -> T? {
        return try? decoder.decode(T.self, from: self)
    }

    func decode(_ allKeyValues: [[String: Binding]]) -> [T] {
        do {
            let array = try decoder.decode([T].self, from: self)
            return array
        } catch {
            print(error)
            return []
        }
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
        let _sql = Select().table(name).where(condition).orderBy(orderBy).limit(1).sql
        return db.query(_sql).first
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
        let _sql = Select().table(name).where(condition).distinct(distinct).fields(fields)
            .groupBy(groupBy).having(having).orderBy(orderBy)
            .limit(limit).offset(offset).sql
        return db.query(_sql)
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
    func exist(_ condition: Where) -> Bool {
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
        let _sql = Select().table(name).fields(Fields(function)).where(condition).sql
        return db.query(_sql).first?.values.first
    }
}

public extension View {
    /// 删除视图
    @discardableResult
    func drop() -> Bool {
        let sql = "DROP VIEW IF EXISTS \(name.quoted)"
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }
}
