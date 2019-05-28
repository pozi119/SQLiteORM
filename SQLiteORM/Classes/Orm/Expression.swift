//
//  Where.swift
//  ClauseiteORM
//
//  Created by Valo on 2019/5/8.
//

import Foundation

public protocol SQLable: CustomStringConvertible {
    /// sql语句
    var sql: String { get }
}

public protocol Conditional {}
public protocol Filtrable {}

extension String: Conditional {}
extension Array: Conditional {}
extension Dictionary: Conditional {}

extension String: Filtrable {}
extension Array: Filtrable {}

// MARK: - where

public struct Where: SQLable, Conditional {
    private var _expr: String

    public init(_ expr: Conditional) {
        switch expr {
        case let expr as String:
            _expr = expr
        case let expr as Array<Dictionary<String, Binding>> where expr.count > 0:
            let array = expr.map({ (dic) -> Where in
                Where(dic)
            })
            _expr = array.map { "(\($0))" }.joined(separator: " OR ")
        case let expr as Array<Where> where expr.count > 0:
            _expr = expr.map { "(\($0))" }.joined(separator: " OR ")
        case let expr as Array<String> where expr.count > 0:
            _expr = expr.map { "(\($0))" }.joined(separator: " OR ")
        case let expr as Dictionary<String, Binding> where expr.count > 0:
            _expr = expr.map { "(" + "\($0.key)".quote() + " == " + "\($0.value)".quote() + ")" }.joined(separator: " AND ")
        default:
            _expr = "\(expr)"
        }
    }

    public var quoted: String {
        return _expr.quote()
    }

    public var sql: String {
        return _expr
    }

    public var description: String {
        return _expr
    }
}

// MARK: operator

infix operator !>: ComparisonPrecedence
infix operator !<: ComparisonPrecedence
infix operator <>: ComparisonPrecedence

// MARK: comparison

fileprivate func _operator(_ op: String, lhs: Where, value: Binding) -> Where {
    return Where(lhs.quoted + " " + op + " " + "\(value)".quote())
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
    return Where("(\(lhs))" + " AND " + "(\(rhs))")
}

public func || (lhs: Where, rhs: Where) -> Where {
    return Where("(\(lhs))" + " OR " + "(\(rhs))")
}

public extension Where {
    fileprivate func _logic(_ logic: String, value: Binding) -> Where {
        return Where(quoted + " " + logic + " " + "\(value)".quote())
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
        return Where("\(quoted) BETWEEN " + "\(turple.start)".quote() + " AND " + "\(turple.end)".quote())
    }

    func notBetween(_ turple: (start: Binding, end: Binding)) -> Where {
        return Where("\(quoted) NOT BETWEEN " + "\(turple.start)".quote() + " AND " + "\(turple.end)".quote())
    }

    func `in`<T: Binding>(_ array: Array<T>) -> Where {
        return Where("\(quoted) IN (\(array.quoteJoined(separator: ",", quote: "\"")))")
    }

    func notIn<T: Binding>(_ array: Array<T>) -> Where {
        return Where("\(quoted) NOT IN (\(array.quoteJoined(separator: ",", quote: "\"")))")
    }
}

// MARK: - order by

public struct OrderBy: SQLable, Filtrable {
    private var _expr: String

    public init(_ expr: Conditional) {
        let regular = "( +ASC *$)|( +DESC *$)"
        var str: String
        switch expr {
        case let expr as String where expr.count > 0:
            str = expr.quote()
        case let expr as Array<String> where expr.count > 0:
            let filtered = expr.filter({ $0.count > 0 })
            if filtered.count == 0 {
                str = ""
                break
            }
            let ordered = filtered.filter({ $0.match(regular) })
            if ordered.count == 0 {
                str = filtered.quoteJoined(separator: ",", quote: "\"")
            } else {
                str = filtered.map { $0.match(regular) ? $0 : ($0.quote() + " ASC") }.joined(separator: ",")
            }
        default:
            str = ""
        }
        _expr = (str.count == 0 || str.match(regular)) ? str : (str + " ASC")
    }

    public var sql: String {
        return _expr
    }

    public var description: String {
        return _expr
    }
}

// MARK: - group by

public struct GroupBy: SQLable, Filtrable {
    private var _expr: String

    public init(_ expr: Conditional) {
        switch expr {
        case let expr as Array<String> where expr.count > 0:
            _expr = expr.quoteJoined(separator: ",", quote: "\"")
        case let expr as String where expr.count > 0:
            _expr = expr.quote()
        default:
            _expr = ""
        }
    }

    public var sql: String {
        return _expr
    }

    public var description: String {
        return _expr
    }
}

// MARK: - fields

public struct Fields: SQLable, Filtrable {
    private var _expr: String

    public init(_ expr: Conditional) {
        switch expr {
        case let expr as Array<String> where expr.count > 0:
            _expr = expr.quoteJoined(separator: ",", quote: "\"")
        case let expr as String where expr.count > 0:
            _expr = expr
        default:
            _expr = "*"
        }
    }

    public var sql: String {
        return _expr
    }

    public var description: String {
        return _expr
    }
}
