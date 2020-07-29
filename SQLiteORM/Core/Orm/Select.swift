//
//  Select.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import Foundation

/// select  statement
public final class Select {
    /// table name
    var table: String = ""

    /// remove duplicate
    var distinct: Bool = false

    /// special fields
    var fields: Fields = "*"

    /// query condition
    var `where`: Where = ""

    /// sort criteria
    var orderBy: OrderBy = ""

    /// fields for group
    var groupBy: GroupBy = ""

    /// condition for group
    var having: Where = ""

    /// maximum number of results
    var limit: Int64 = 0

    /// starting position
    var offset: Int64 = 0

    /// native sql clause
    var sql: String {
        assert(table.count > 0, "set table first!")

        let distinctClause = distinct ? " DISTINCT " : ""

        let fieldsClause = fields.sql

        let tableClause = " FROM " + table

        var whereClause = `where`.sql
        whereClause = whereClause.count > 0 ? " WHERE \(whereClause)" : ""

        var orderByClause = orderBy.sql
        orderByClause = orderByClause.count > 0 ? " ORDER BY \(orderByClause)" : ""

        var groupByClause = groupBy.sql
        groupByClause = groupByClause.count > 0 ? " GROUP BY \(groupByClause)" : ""

        var havingClause = having.sql
        havingClause = havingClause.count > 0 ? " HAVING \(havingClause)" : ""

        if offset > 0 && limit <= 0 { limit = Int64.max }

        let limitClause = limit > 0 ? " LIMIT \(limit)" : ""

        let offsetClause = offset > 0 ? " OFFSET \(offset)" : ""

        let str = "SELECT " + distinctClause + fieldsClause + tableClause + whereClause + groupByClause + havingClause + orderByClause + limitClause + offsetClause
        return str
    }

    public func table(_ table: String) -> Select {
        self.table = table
        return self
    }

    public func distinct(_ distinct: Bool) -> Select {
        self.distinct = distinct
        return self
    }

    public func fields(_ fields: Fields) -> Select {
        self.fields = fields
        return self
    }

    public func `where`(_ where: Where) -> Select {
        self.where = `where`
        return self
    }

    public func orderBy(_ orderBy: OrderBy) -> Select {
        self.orderBy = orderBy
        return self
    }

    public func groupBy(_ groupBy: GroupBy) -> Select {
        self.groupBy = groupBy
        return self
    }

    public func having(_ having: Where) -> Select {
        self.having = having
        return self
    }

    public func limit(_ limit: Int64) -> Select {
        self.limit = limit
        return self
    }

    public func offset(_ offset: Int64) -> Select {
        self.offset = offset
        return self
    }
}

extension Select {
    public func allKeyValues(_ db: Database) -> [[String: Binding]] {
        return db.query(sql)
    }

    public func allItems<T: Codable>(_ db: Database, type: T.Type, decoder: OrmDecoder) -> [T] {
        let keyValues = db.query(sql)
        do {
            let array = try decoder.decode([T].self, from: keyValues)
            return array
        } catch {
            print(error)
            return []
        }
    }
}
