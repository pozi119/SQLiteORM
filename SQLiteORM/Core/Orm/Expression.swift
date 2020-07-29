//
//  Expression.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import Foundation

public protocol SQLable: CustomStringConvertible {
    /// sql statement
    var sql: String { get }
}

extension SQLable {
    public var description: String {
        return sql
    }
}

public protocol Conditional {}
public protocol Filtrable {}

extension String: Conditional {}
extension Array: Conditional {}
extension Dictionary: Conditional {}

extension String: Filtrable {}
extension Array: Filtrable {}

// MARK: - where

public struct Where: SQLable {
    public private(set) var sql: String

    public init(_ condition: String) {
        sql = condition
    }

    public init(_ keyValues: [[String: Binding]]) {
        let array = keyValues.map { Where($0) }
        sql = array.map { "(\($0))" }.joined(separator: " OR ")
    }

    public init(_ conditions: [Where]) {
        sql = conditions.map { "(\($0))" }.joined(separator: " OR ")
    }

    public init(_ conditions: [String]) {
        sql = conditions.joined(separator: " OR ")
    }

    public init(_ keyValue: [String: Binding]) {
        sql = keyValue.map { "(\($0.key.quoted) == \($0.value.sqlValue))" }.joined(separator: " AND ")
    }

    public var quoted: String {
        return sql.quoted
    }
}

extension Where: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension Where: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}

extension Where: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Binding
    public init(dictionaryLiteral elements: (String, Binding)...) {
        var dic = [String: Binding]()
        for (key, val) in elements {
            dic[key] = val
        }
        self.init(dic)
    }
}

// MARK: operator

infix operator !>: ComparisonPrecedence
infix operator !<: ComparisonPrecedence
infix operator <>: ComparisonPrecedence

// MARK: comparison

fileprivate func _operator(_ op: String, lhs: Where, value: Binding) -> Where {
    return Where(lhs.quoted + " " + op + " " + value.sqlValue)
}

public func == (lhs: Where, value: Binding) -> Where {
    return _operator("==", lhs: lhs, value: value)
}

public func != (lhs: Where, value: Binding) -> Where {
    return _operator("!=", lhs: lhs, value: value)
}

public func <> (lhs: Where, value: Binding) -> Where {
    return _operator("<>", lhs: lhs, value: value)
}

public func > (lhs: Where, value: Binding) -> Where {
    return _operator(">", lhs: lhs, value: value)
}

public func >= (lhs: Where, value: Binding) -> Where {
    return _operator(">=", lhs: lhs, value: value)
}

public func !> (lhs: Where, value: Binding) -> Where {
    return _operator("!>", lhs: lhs, value: value)
}

public func < (lhs: Where, value: Binding) -> Where {
    return _operator("<", lhs: lhs, value: value)
}

public func <= (lhs: Where, value: Binding) -> Where {
    return _operator("<=", lhs: lhs, value: value)
}

public func !< (lhs: Where, value: Binding) -> Where {
    return _operator("!<", lhs: lhs, value: value)
}

// MARK: - Logic

public func && (lhs: Where, rhs: Where) -> Where {
    switch (lhs.sql.count, rhs.sql.count) {
        case (0, 0): return lhs
        case (_, 0): return lhs
        case (0, _): return rhs
        case (_, _): return Where("(\(lhs))" + " AND " + "(\(rhs))")
    }
}

public func || (lhs: Where, rhs: Where) -> Where {
    switch (lhs.sql.count, rhs.sql.count) {
        case (0, 0): return lhs
        case (_, 0): return lhs
        case (0, _): return rhs
        case (_, _): return Where("(\(lhs))" + " OR " + "(\(rhs))")
    }
}

public extension Where {
    fileprivate func _logic(_ logic: String, value: Binding) -> Where {
        return Where(quoted + " " + logic + " " + value.sqlValue)
    }

    func match(_ value: Binding) -> Where {
        return _logic("MATCH", value: value)
    }

    func like(_ value: Binding) -> Where {
        return _logic("LIKE", value: value)
    }

    func notLike(_ value: Binding) -> Where {
        return _logic("NOT LIKE", value: value)
    }

    func glob(_ value: Binding) -> Where {
        return _logic("GLOB", value: value)
    }

    func notGlob(_ value: Binding) -> Where {
        return _logic("NOT GLOB", value: value)
    }

    func `is`(_ value: Binding) -> Where {
        return _logic("IS", value: value)
    }

    func isNot(_ value: Binding) -> Where {
        return _logic("IS NOT", value: value)
    }

    func isNull() -> Where {
        return Where("\(quoted) IS NULL")
    }

    func exists(_ value: Binding) -> Where {
        return _logic("EXISTS", value: value)
    }

    func notExists(_ value: Binding) -> Where {
        return _logic("NOT EXISTS", value: value)
    }

    func between(_ turple: (start: Binding, end: Binding)) -> Where {
        return Where(quoted + " BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue)
    }

    func notBetween(_ turple: (start: Binding, end: Binding)) -> Where {
        return Where(quoted + " NOT BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue)
    }

    func `in`<T: Binding>(_ array: [T]) -> Where {
        return Where(quoted + " IN (" + array.sqlJoined + ")")
    }

    func notIn<T: Binding>(_ array: [T]) -> Where {
        return Where(quoted + " NOT IN (" + array.sqlJoined + ")")
    }
}

// MARK: - table

public extension String {
    func innerJoin(_ other: String) -> String {
        return quoted + " JOIN " + other.quoted
    }

    func outerJoin(_ other: String) -> String {
        return quoted + " LEFT OUTER JOIN " + other.quoted
    }

    func crossJoin(_ other: String) -> String {
        return quoted + " CROSS JOIN " + other.quoted
    }

    func column(_ column: String) -> String {
        return self + "." + column
    }

    func on(_ condition: Where) -> String {
        return self + " ON " + condition.sql
    }

    func concat(_ concat: String, value: Binding) -> String {
        return self + " " + concat + " " + value.sqlValue
    }
}

// MARK: - order by

public struct OrderBy: SQLable {
    public private(set) var sql: String

    private let rx = "( +ASC *$)|( +DESC *$)"

    public init(_ order: String) {
        sql = order.count == 0 ? "" : (order.match(rx) ? order : (order + " ASC"))
    }

    public init(_ orders: [String]) {
        var array: [String] = []
        for order in orders {
            if order.count == 0 { continue }
            let t = order.match(rx) ? order : (order + " ASC")
            array.append(t)
        }
        sql = array.joined(separator: ",")
    }
}

extension OrderBy: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension OrderBy: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}

// MARK: - group by

public struct GroupBy: SQLable {
    public private(set) var sql: String

    public init(_ group: String) {
        sql = group
    }

    public init(_ groups: [String]) {
        sql = groups.joined(separator: ",")
    }
}

extension GroupBy: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension GroupBy: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}

// MARK: - fields

public struct Fields: SQLable {
    public private(set) var sql: String

    public init(_ field: String) {
        sql = field
    }

    public init(_ fields: [String]) {
        sql = fields.joined(separator: ",")
    }

    public init() {
        sql = "*"
    }
}

extension Fields: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension Fields: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String
    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }
}
