//
//  Binding.swift
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
extension Data: Binding {}

extension Data {
    private static let hexTable: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46]

    private static func hexDigit(_ byte: UInt8) -> UInt8 {
        switch byte {
            case 0x30 ... 0x39: return byte - 0x30
            case 0x41 ... 0x46: return byte - 0x41 + 0xA
            case 0x61 ... 0x66: return byte - 0x61 + 0xA
            default: return 0xFF
        }
    }

    public var bytes: [UInt8] { [UInt8](self) }

    public var hex: String {
        var hexBytes: [UInt8] = []
        for byte in bytes {
            let hi = Data.hexTable[Int((byte >> 4) & 0xF)]
            let lo = Data.hexTable[Int(byte & 0xF)]
            hexBytes.append(hi)
            hexBytes.append(lo)
        }
        return String(bytes: hexBytes)
    }

    init(hex: String) {
        let chars = hex.bytes
        guard chars.count % 2 == 0 else { self.init(); return }
        let len = chars.count / 2
        var buffer: [UInt8] = []
        for i in 0 ..< len {
            let h = Data.hexDigit(chars[i * 2])
            let l = Data.hexDigit(chars[i * 2 + 1])
            guard h != 0xFF || l != 0xFF else { self.init(); return }
            let b = h << 4 | l
            buffer.append(b)
        }
        self.init(buffer)
    }
}

extension Binding {
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
        case is Double.Type:
            return "REAL"

        case is String.Type:
            return "TEXT"

        case is Data.Type:
            return "BLOB"

        default:
            return "JSON"
    }
}
