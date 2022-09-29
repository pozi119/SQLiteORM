//
//  Expression.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import AnyCoder
import Foundation

@dynamicMemberLookup
public struct Expr: RawRepresentable, ExpressibleByStringLiteral {
    public typealias RawValue = String
    public var rawValue: String

    public init?(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static var empty: Self {
        return .init("")
    }

    public var sql: String {
        return rawValue
    }

    public static subscript(dynamicMember member: String) -> Expr {
        get {
            Expr(member)
        }
        set { }
    }

    public typealias StringLiteralType = String
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

public protocol SQLable: CustomStringConvertible {
    /// sql statement
    var sql: String { get }
    init(_ string: String)
}

extension SQLable {
    public var description: String {
        return sql
    }

    public static var empty: Self {
        return .init("")
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
    public typealias Value = Primitive
    public init(dictionaryLiteral elements: (String, Primitive)...) {
        var dic = [String: Primitive]()
        for (key, val) in elements {
            dic[key] = val
        }
        self.init(dic)
    }
}

@dynamicMemberLookup
public struct Where: SQLable {
    var raw: String = ""

    public var sql: String {
        return raw.strip
    }

    public init(_ string: String) {
        raw = string
    }

    public init(_ keyValues: [[String: Primitive]]) {
        let array = keyValues.map { Where($0) }
        raw = array.map { "(\($0))" }.joined(separator: " OR ")
    }

    public init(_ conditions: [Where]) {
        raw = conditions.map { "(\($0))" }.joined(separator: " OR ")
    }

    public init(_ conditions: [String]) {
        raw = conditions.joined(separator: " OR ")
    }

    public init(_ keyValue: [String: Primitive]) {
        raw = keyValue.map { "(\($0.key.quoted) == \($0.value.sqlValue))" }.joined(separator: " AND ")
    }

    public static subscript(dynamicMember member: String) -> Where {
        get {
            Where(member)
        }
        set { }
    }
}

// MARK: operator

infix operator !>: ComparisonPrecedence
infix operator !<: ComparisonPrecedence
infix operator <>: ComparisonPrecedence

// MARK: comparison

fileprivate func _operator(_ op: String, lhs: Where, value: Primitive) -> Where {
    return Where(lhs.raw.quoted + " " + op + " " + value.sqlValue)
}

public func == (lhs: Where, value: Primitive) -> Where {
    return _operator("==", lhs: lhs, value: value)
}

public func != (lhs: Where, value: Primitive) -> Where {
    return _operator("!=", lhs: lhs, value: value)
}

public func <> (lhs: Where, value: Primitive) -> Where {
    return _operator("<>", lhs: lhs, value: value)
}

public func > (lhs: Where, value: Primitive) -> Where {
    return _operator(">", lhs: lhs, value: value)
}

public func >= (lhs: Where, value: Primitive) -> Where {
    return _operator(">=", lhs: lhs, value: value)
}

public func !> (lhs: Where, value: Primitive) -> Where {
    return _operator("!>", lhs: lhs, value: value)
}

public func < (lhs: Where, value: Primitive) -> Where {
    return _operator("<", lhs: lhs, value: value)
}

public func <= (lhs: Where, value: Primitive) -> Where {
    return _operator("<=", lhs: lhs, value: value)
}

public func !< (lhs: Where, value: Primitive) -> Where {
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
    fileprivate func _logic(_ logic: String, value: Primitive) -> Where {
        return Where(raw.quoted + " " + logic + " " + value.sqlValue)
    }

    func match(_ value: Primitive) -> Where {
        return _logic("MATCH", value: value)
    }

    func like(_ value: Primitive) -> Where {
        return _logic("LIKE", value: "\(value)".quote("%"))
    }

    func notLike(_ value: Primitive) -> Where {
        return _logic("NOT LIKE", value: "\(value)".quote("%"))
    }

    func glob(_ value: Primitive) -> Where {
        return _logic("GLOB", value: "\(value)".quote("*"))
    }

    func notGlob(_ value: Primitive) -> Where {
        return _logic("NOT GLOB", value: "\(value)".quote("*"))
    }

    func `is`(_ value: Primitive) -> Where {
        return _logic("IS", value: value)
    }

    func isNot(_ value: Primitive) -> Where {
        return _logic("IS NOT", value: value)
    }

    func isNull() -> Where {
        return Where("\(raw.quoted) IS NULL")
    }

    func exists(_ value: Primitive) -> Where {
        return _logic("EXISTS", value: value)
    }

    func notExists(_ value: Primitive) -> Where {
        return _logic("NOT EXISTS", value: value)
    }

    func between(_ turple: (start: Primitive, end: Primitive)) -> Where {
        return Where(raw.quoted + " BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue)
    }

    func notBetween(_ turple: (start: Primitive, end: Primitive)) -> Where {
        return Where(raw.quoted + " NOT BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue)
    }

    func `in`<T: Primitive>(_ array: [T]) -> Where {
        return Where(raw.quoted + " IN (" + array.sqlJoined + ")")
    }

    func notIn<T: Primitive>(_ array: [T]) -> Where {
        return Where(raw.quoted + " NOT IN (" + array.sqlJoined + ")")
    }
}

// MARK: - table

@dynamicMemberLookup
public struct Table: SQLable {
    var raw: String = ""

    public var sql: String {
        return raw
    }

    public init(_ string: String) {
        raw = string
    }

    public init(_ closure: () -> String) {
        raw = closure()
    }

    public static subscript(dynamicMember table: String) -> Table {
        get {
            Table(table)
        }
        set { }
    }
}

public extension Table {
    func innerJoin(_ other: String) -> Table {
        return Table(raw.quoted + " JOIN " + other.quoted)
    }

    func outerJoin(_ other: String) -> Table {
        return Table(raw.quoted + " LEFT OUTER JOIN " + other.quoted)
    }

    func crossJoin(_ other: String) -> Table {
        return Table(raw.quoted + " CROSS JOIN " + other.quoted)
    }

    func column(_ column: String) -> Table {
        return Table(raw + "." + column)
    }

    func on(_ condition: Where) -> Table {
        return Table(raw + " ON " + condition.sql)
    }

    func concat(_ concat: String, value: Primitive) -> Table {
        return Table(raw + " " + concat + " " + value.sqlValue)
    }
}

// MARK: - order by

public struct OrderBy: SQLable {
    var raw: String = ""

    public var sql: String {
        return raw
    }

    private let rx = "( +ASC *$)|( +DESC *$)"

    public init(_ order: String) {
        raw = order.count == 0 ? "" : (order.match(rx) ? order : (order + " ASC"))
    }

    public init(_ orders: [String]) {
        var array: [String] = []
        for order in orders {
            if order.count == 0 { continue }
            let t = order.match(rx) ? order : (order + " ASC")
            array.append(t)
        }
        raw = array.joined(separator: ",")
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
    var raw: String = ""

    public var sql: String {
        return raw
    }

    public init(_ group: String) {
        raw = group
    }

    public init(_ groups: [String]) {
        raw = groups.joined(separator: ",")
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
    var raw: String = ""

    public var sql: String {
        return raw == "" ? "*" : raw
    }

    public init(_ field: String) {
        raw = field
    }

    public init(_ fields: [String]) {
        raw = fields.joined(separator: ",")
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
