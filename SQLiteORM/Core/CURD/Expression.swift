//
//  Expression.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/8.
//

import AnyCoder
import Foundation

@dynamicMemberLookup
public struct Expr {
    public static subscript(dynamicMember key: String) -> String {
        get { key }
        set { }
    }
}

public typealias E = Expr

// MARK: operator

infix operator |==: ComparisonPrecedence // ==
infix operator |!=: ComparisonPrecedence // !=
infix operator |>: ComparisonPrecedence // >
infix operator |>=: ComparisonPrecedence // >=
infix operator |<: ComparisonPrecedence // <
infix operator |<=: ComparisonPrecedence // <=
infix operator |!>: ComparisonPrecedence // !>
infix operator |!<: ComparisonPrecedence // !<
infix operator |<>: ComparisonPrecedence // <>

infix operator |&&: LogicalConjunctionPrecedence // &&
infix operator |||: LogicalConjunctionPrecedence // ||

postfix operator ↑
postfix operator ↓

public extension String {
    static let empty = ""
}

public extension String {
    var asc: String {
        return count > 0 ? self + " ASC" : self
    }

    var desc: String {
        return count > 0 ? self + " DESC" : self
    }

    static postfix func ↑ (_ lhs: String) -> String {
        return lhs.asc
    }

    static postfix func ↓ (_ lhs: String) -> String {
        return lhs.desc
    }
}

// MARK: comparison

public extension String {
    fileprivate static func _operator(_ op: String, lhs: String, value: Primitive) -> String {
        return lhs.quoted + " " + op + " " + value.sqlValue
    }

    static func |== (lhs: String, value: Primitive) -> String {
        return _operator("==", lhs: lhs, value: value)
    }

    static func |!= (lhs: String, value: Primitive) -> String {
        return _operator("!=", lhs: lhs, value: value)
    }

    static func |<> (lhs: String, value: Primitive) -> String {
        return _operator("<>", lhs: lhs, value: value)
    }

    static func |> (lhs: String, value: Primitive) -> String {
        return _operator(">", lhs: lhs, value: value)
    }

    static func |>= (lhs: String, value: Primitive) -> String {
        return _operator(">=", lhs: lhs, value: value)
    }

    static func |!> (lhs: String, value: Primitive) -> String {
        return _operator("!>", lhs: lhs, value: value)
    }

    static func |< (lhs: String, value: Primitive) -> String {
        return _operator("<", lhs: lhs, value: value)
    }

    static func |<= (lhs: String, value: Primitive) -> String {
        return _operator("<=", lhs: lhs, value: value)
    }

    static func |!< (lhs: String, value: Primitive) -> String {
        return _operator("!<", lhs: lhs, value: value)
    }
}

// MARK: - Logic

public extension String {
    static func |&& (lhs: String, rhs: String) -> String {
        switch (lhs.count, rhs.count) {
        case (0, 0): return lhs
        case (_, 0): return lhs
        case (0, _): return rhs
        case (_, _): return "\(lhs.bracket()) AND \(rhs.bracket())"
        }
    }

    static func ||| (lhs: String, rhs: String) -> String {
        switch (lhs.count, rhs.count) {
        case (0, 0): return lhs
        case (_, 0): return lhs
        case (0, _): return rhs
        case (_, _): return "\(lhs.bracket()) OR \(rhs.bracket())"
        }
    }
}

public extension String {
    fileprivate func _logic(_ logic: String, value: Primitive) -> String {
        return quoted + " " + logic + " " + value.sqlValue
    }

    func match(_ value: Primitive) -> String {
        return _logic("MATCH", value: value)
    }

    func like(_ value: Primitive) -> String {
        return _logic("LIKE", value: "\(value)".quote("%"))
    }

    func notLike(_ value: Primitive) -> String {
        return _logic("NOT LIKE", value: "\(value)".quote("%"))
    }

    func glob(_ value: Primitive) -> String {
        return _logic("GLOB", value: "\(value)".quote("*"))
    }

    func notGlob(_ value: Primitive) -> String {
        return _logic("NOT GLOB", value: "\(value)".quote("*"))
    }

    func `is`(_ value: Primitive) -> String {
        return _logic("IS", value: value)
    }

    func isNot(_ value: Primitive) -> String {
        return _logic("IS NOT", value: value)
    }

    func isNull() -> String {
        return "\(quoted) IS NULL"
    }

    func exists(_ value: Primitive) -> String {
        return _logic("EXISTS", value: value)
    }

    func notExists(_ value: Primitive) -> String {
        return _logic("NOT EXISTS", value: value)
    }

    func between(_ turple: (start: Primitive, end: Primitive)) -> String {
        return quoted + " BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue
    }

    func notBetween(_ turple: (start: Primitive, end: Primitive)) -> String {
        return quoted + " NOT BETWEEN " + turple.start.sqlValue + " AND " + turple.end.sqlValue
    }

    func `in`<T: Primitive>(_ array: [T]) -> String {
        return quoted + " IN " + array.sqlJoined.bracket()
    }

    func notIn<T: Primitive>(_ array: [T]) -> String {
        return quoted + " NOT IN " + array.sqlJoined.bracket()
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

    func on(_ condition: String) -> String {
        return self + " ON " + condition
    }

    func concat(_ concat: String, value: Primitive) -> String {
        return self + " " + concat + " " + value.sqlValue
    }
}
