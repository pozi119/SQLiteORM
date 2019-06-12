//
//  Value.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Foundation

public protocol Binding {}

extension Bool: Binding {}
extension Int: Binding {}
extension Int8: Binding {}
extension Int16: Binding {}
extension Int32: Binding {}
extension Int64: Binding {}
extension UInt: Binding {}
extension UInt8: Binding {}
extension UInt16: Binding {}
extension UInt32: Binding {}
extension UInt64: Binding {}

extension Float: Binding {}
extension Double: Binding {}
extension String: Binding {}

extension Data: Binding {
    public var bytes: [UInt8] {
        return [UInt8](self)
    }
}

extension Binding{
    public var sqlValue:String{
        let type = Self.self
        switch type {
        case is String.Type:
            return "\(self)".quoted
        case is Data.Type:
            return "\(self)".quoted
        default:
            return "\(self)"
        }
    }
}

/// 获取sqlite存储类型
///
/// - Parameter type: 数据类型
/// - Returns: 存储类型
public func sqlType(of type: Any.Type) -> String {
    switch type {
    case is Bool.Type: fallthrough
    case is Int.Type: fallthrough
    case is Int8.Type: fallthrough
    case is Int16.Type: fallthrough
    case is Int32.Type: fallthrough
    case is Int64.Type: fallthrough
    case is UInt.Type: fallthrough
    case is UInt8.Type: fallthrough
    case is UInt16.Type: fallthrough
    case is UInt32.Type: fallthrough
    case is UInt64.Type:
        return "INTEGER"

    case is Float.Type: fallthrough
    case is Double.Type:
        return "REAL"

    case is String.Type:
        return "TEXT"

    case is Data.Type:
        return "BLOB"

    default:
        return "BLOB"
    }
}
