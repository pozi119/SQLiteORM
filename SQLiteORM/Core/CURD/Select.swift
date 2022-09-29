//
//  Select.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import AnyCoder
import Foundation

/// select  statement
public class Select: CURD {
    /// remove duplicate
    private var distinct: Bool = false

    /// special fields
    private var fields: String = "*"

    /// sort criteria
    private var orderBy: String = .empty

    /// fields for group
    private var groupBy: String = .empty

    /// condition for group
    private var having: String = .empty

    /// maximum number of results
    private var limit: Int64 = 0

    /// starting position
    private var offset: Int64 = 0

    /// native sql clause
    private var sql: String {
        assert(table.count > 0, "set table first!")

        let distinctClause = distinct ? " DISTINCT " : ""

        let fieldsClause = fields

        let tableClause = " FROM " + table.quoted

        var whereClause = `where`
        whereClause = whereClause.count > 0 ? " WHERE \(whereClause)" : ""

        var orderByClause = orderBy
        orderByClause = orderByClause.count > 0 ? " ORDER BY \(orderByClause)" : ""

        var groupByClause = groupBy
        groupByClause = groupByClause.count > 0 ? " GROUP BY \(groupByClause)" : ""

        var havingClause = having
        havingClause = havingClause.count > 0 ? " HAVING \(havingClause)" : ""

        if offset > 0 && limit <= 0 { limit = Int64.max }

        let limitClause = limit > 0 ? " LIMIT \(limit)" : ""

        let offsetClause = offset > 0 ? " OFFSET \(offset)" : ""

        let str = "SELECT " + distinctClause + fieldsClause + tableClause + whereClause + groupByClause + havingClause + orderByClause + limitClause + offsetClause
        return str
    }

    @discardableResult
    public func distinct(_ closure: () -> Bool) -> Self {
        distinct = closure()
        return self
    }

    @discardableResult
    public func fields(_ closure: () -> String) -> Self {
        fields = closure()
        return self
    }

    @discardableResult
    public func orderBy(_ closure: () -> String) -> Self {
        orderBy = closure()
        return self
    }

    @discardableResult
    public func groupBy(_ closure: () -> String) -> Self {
        groupBy = closure()
        return self
    }

    @discardableResult
    public func having(_ closure: () -> String) -> Self {
        having = closure()
        return self
    }

    @discardableResult
    public func limit(_ closure: () -> Int64) -> Self {
        limit = closure()
        return self
    }

    @discardableResult
    public func offset(_ closure: () -> Int64) -> Self {
        offset = closure()
        return self
    }
}

extension Select {
    public func oneKeyValue() -> [String: Primitive]? {
        limit { 1 }
        assert(db != nil, "Please set db first!")
        return db!.query(sql).first
    }

    public func allKeyValues() -> [[String: Primitive]] {
        assert(db != nil, "Please set db first!")
        return db!.query(sql)
    }

    public func allValues(field: String) -> [Primitive] {
        let keyValues = allKeyValues()
        return keyValues.map { $0[field] ?? "" }
    }
}
