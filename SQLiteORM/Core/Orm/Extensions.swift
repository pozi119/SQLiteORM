//
//  Extensions.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/21.
//

import Foundation

public extension String {
    var trim: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var strip: String {
        return replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    }

    var quoted: String {
        return quote()
    }

    func quote(_ mark: Character? = "\"") -> String {
        guard mark != nil else {
            return self
        }
        let ch = mark!
        let fix = "\(ch)"
        if hasPrefix(fix) && hasSuffix(fix) {
            return self
        }
        let escaped = reduce("") { string, character in
            string + (character == ch ? "\(ch)\(ch)" : "\(character)")
        }
        return "\(ch)\(escaped)\(ch)"
    }

    func match(_ regex: String) -> Bool {
        let r = range(of: regex, options: [.regularExpression, .caseInsensitive])
        return r != nil
    }
}

public extension Array where Element: Binding {
    var sqlJoined: String {
        return map { $0.sqlValue }.joined(separator: ",")
    }
}

public extension Array where Element: Hashable {
    static func === (lhs: Array, rhs: Array) -> Bool {
        return Set(lhs) == Set(rhs)
    }
}

public extension Dictionary {
    static func === (lhs: Dictionary, rhs: Dictionary) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else {
            return false
        }
        for key in lhs.keys {
            let lvalue = lhs[key]
            let rvalue = rhs[key]
            switch (lvalue, rvalue) {
                case let (lvalue as Bool, rvalue as Bool): return lvalue == rvalue
                case let (lvalue as Int, rvalue as Int): return lvalue == rvalue
                case let (lvalue as Int8, rvalue as Int8): return lvalue == rvalue
                case let (lvalue as Int16, rvalue as Int16): return lvalue == rvalue
                case let (lvalue as Int32, rvalue as Int32): return lvalue == rvalue
                case let (lvalue as Int64, rvalue as Int64): return lvalue == rvalue
                case let (lvalue as UInt, rvalue as UInt): return lvalue == rvalue
                case let (lvalue as UInt8, rvalue as UInt8): return lvalue == rvalue
                case let (lvalue as UInt16, rvalue as UInt16): return lvalue == rvalue
                case let (lvalue as UInt32, rvalue as UInt32): return lvalue == rvalue
                case let (lvalue as UInt64, rvalue as UInt64): return lvalue == rvalue
                case let (lvalue as Float, rvalue as Float): return lvalue == rvalue
                case let (lvalue as Double, rvalue as Double): return lvalue == rvalue
                case let (lvalue as String, rvalue as String): return lvalue == rvalue
                case let (lvalue as Data, rvalue as Data): return lvalue == rvalue
                case (_, _):
                    return false
            }
        }
        return true
    }

    mutating func removeValues(forKeys: [Key]) {
        for key in forKeys {
            removeValue(forKey: key)
        }
    }
}
