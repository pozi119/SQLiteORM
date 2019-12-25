//
//  Select.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import Foundation

/// 数据查询
public final class Select {
    /// 表名
    var table: String = ""

    /// 是否去重
    var distinct: Bool = false

    /// 指定查询字段
    var fields: Fields = "*"

    /// 查询条件
    var `where`: Where = ""

    /// 排序条件
    var orderBy: OrderBy = ""

    /// 分组
    var groupBy: GroupBy = ""

    /// 分组条件
    var having: Where = ""

    /// 查询条数
    var limit: Int64 = 0

    /// 起始位置
    var offset: Int64 = 0

    /// 生成具体查询语句
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
    public func allKeyValues<T: Codable>(_ orm: Orm<T>) -> [[String: Binding]] {
        table = orm.table
        return orm.db.query(sql)
    }

    public func allItems<T: Codable>(_ orm: Orm<T>) -> [T] {
        table = orm.table
        let keyValues = orm.db.query(sql)
        do {
            let array = try orm.decoder.decode([T].self, from: keyValues)
            return array
        } catch {
            print(error)
            return []
        }
    }
}
