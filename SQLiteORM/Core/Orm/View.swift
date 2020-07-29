//
//  View.swift
//  SQLiteORM
//
//  Created by Valo on 2019/10/15.
//

import Foundation

// sqlite view
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
    /// maximum rowid. the maximum rowid, auto increment primary key and records count may not be the same
    var maxRowId: Int64 {
        return max(of: "rowid") as? Int64 ?? 0
    }

    /// find a record, not decoded
    ///
    /// - Parameters:
    /// - Returns: [String:Binding], decoding with ORMDecoder
    func findOne(_ condition: Where = Where(""), orderBy: OrderBy = OrderBy("")) -> [String: Binding]? {
        return Select().table(name).where(condition).orderBy(orderBy).limit(1).allKeyValues(db).first
    }

    /// find a record, decoded
    func xFindOne(_ condition: Where = Where(""), orderBy: OrderBy = OrderBy("")) -> T? {
        return Select().table(name).where(condition).orderBy(orderBy).limit(1).allItems(db, type: T.self, decoder: decoder).first
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
    /// - Returns: [String:Binding], decoding with ORMDecoder
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

    /// find data, decoded
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

    /// get number of records
    func count(_ condition: Where = Where("")) -> Int64 {
        return function("count(*)", condition: condition) as? Int64 ?? 0
    }

    /// check if a record exists
    func exist(_ item: T) -> Bool {
        guard let condition = config.constraint(for: item, properties: properties) else { return false }
        return count(condition) > 0
    }

    /// check if a record exists
    func exist(_ keyValues: [String: Binding]) -> Bool {
        guard let condition = config.constraint(for: keyValues) else { return false }
        return count(condition) > 0
    }

    /// get the maximum value of a field
    func max(of field: String, condition: Where = Where("")) -> Binding? {
        return function("max(\(field))", condition: condition)
    }

    /// get the minimum value of a field
    func min(of field: String, condition: Where = Where("")) -> Binding? {
        return function("min(\(field))", condition: condition)
    }

    /// get the sum value of a field
    func sum(of field: String, condition: Where = Where("")) -> Binding? {
        return function("sum(\(field))", condition: condition)
    }

    /// execute a function, such as: max(),min(),sum()
    ///
    /// - Parameters:
    ///   - function: function name
    /// - Returns: function result
    func function(_ function: String, condition: Where = Where("")) -> Binding? {
        let dic = Select().table(name).fields(Fields(function)).where(condition).allKeyValues(db).first
        return dic?.values.first
    }
}
