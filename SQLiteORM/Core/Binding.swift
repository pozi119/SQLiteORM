//
//  Primitive.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import AnyCoder
import Foundation

extension Primitive {
    public var sqlValue: String {
        switch self {
        case let string as String:
            return string.quoted
        case let data as Data:
            return data.hex
        default:
            return "\(self)"
        }
    }
}

/// sqlite storage type
///
/// - Parameter type: data type
/// - Returns: storage type
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
    case is Double.Type: fallthrough
    case is NSNumber.Type:
        return "REAL"

    case is String.Type: fallthrough
    case is NSString.Type:
        return "TEXT"

    case is Data.Type: fallthrough
    case is NSData.Type:
        return "BLOB"

    default:
        return "JSON"
    }
}
