//
//  View.swift
//  SQLiteORM
//
//  Created by Valo on 2019/10/15.
//

import AnyCoder
import Foundation
import Runtime

// sqlite view
public class View<T> {
    public let temp: Bool
    public let name: String
    public let columns: [String]?
    public let table: String
    public let condition: Where

    public let db: Database
    public let config: Config

    private let decoder = ManyDecoder()

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

        let info = try? typeInfo(of: config.type!)

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
    /// - Returns: [String:Primitive], decoding with ORMDecoder
    func find() -> Select {
        return Select().db { db }.table { table }
    }

    /// get number of records
    func count(_ condition: (() -> Where)? = nil) -> Int64 {
        return function("count(*)", condition: condition) as? Int64 ?? 0
    }

    /// check if a record exists
    func exist(_ item: T) -> Bool {
        let condition = constraint(for: item, config)
        guard condition.count > 0 else { return false }
        return count { Where(condition) } > 0
    }

    /// check if a record exists
    func exist(_ keyValues: [String: Primitive]) -> Bool {
        let condition = constraint(of: keyValues, config)
        guard condition.count > 0 else { return false }
        return count { Where(condition) } > 0
    }

    /// get the maximum value of a field
    func max(of field: String, condition: (() -> Where)? = nil) -> Primitive? {
        return function("max(\(field))", condition: condition)
    }

    /// get the minimum value of a field
    func min(of field: String, condition: (() -> Where)? = nil) -> Primitive? {
        return function("min(\(field))", condition: condition)
    }

    /// get the sum value of a field
    func sum(of field: String, condition: (() -> Where)? = nil) -> Primitive? {
        return function("sum(\(field))", condition: condition)
    }

    /// execute a function, such as: max(),min(),sum()
    ///
    /// - Parameters:
    ///   - function: function name
    /// - Returns: function result
    func function(_ function: String, condition: (() -> Where)? = nil) -> Primitive? {
        let select = find().fields { Fields(function) }
        if let condition = condition {
            select.where(condition)
        }
        let dic = select.allKeyValues().first
        return dic?.values.first
    }
}
