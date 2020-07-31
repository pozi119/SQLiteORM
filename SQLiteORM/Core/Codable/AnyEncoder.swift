//
//  AnyCoder.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/30.
//

import Foundation

class AnyEncoder {
    struct Options: OptionSet {
        let rawValue: Int
        static let includeEmptyFields = Options(rawValue: 1 << 0)
    }

    class func encode<T>(_ any: T) throws -> [String: Binding] {
        guard let temp = reflect(any) as? [String: Any] else {
            throw EncodingError.invalidEncode(any)
        }
        var encoded: [String: Binding] = [:]
        for (key, value) in temp {
            switch value {
                case let value as Binding:
                    encoded[key] = value
                case _ as NSNull:
                    break
                default:
                    let data = try JSONSerialization.data(withJSONObject: value, options: [])
                    let string = String(bytes: data.bytes)
                    encoded[key] = string
            }
        }
        return encoded
    }
    
    class func encode<T>(_ values: [T]) -> [[String: Binding]] {
        var array = [[String: Binding]]()
        for value in values {
            do {
                let encoded = try encode(value)
                array.append(encoded)
            } catch _ {
                array.append([:])
            }
        }
        return array
    }

    class func reflect<T>(_ any: T, options: Options = []) -> Any? {
        return reflect(element: any, options: options)
    }

    // MARK: - Private

    private class func reflect<T>(element: T, options: Options = []) -> Any? {
        guard let result = value(for: element, options: options, depth: 0) else {
            return nil
        }
        switch result {
            case _ as [Any], _ as [String: Any]:
                return result
            default:
                return [result]
        }
    }

    private class func value(for any: Any, options: Options = [], depth: Int) -> Any? {
        if let binding = any as? Binding {
            if depth > 1, let data = binding as? Data {
                return data.hex
            }
            return binding
        }

        let mirror = Mirror(reflecting: any)
        if mirror.children.isEmpty {
            switch any {
                case _ as Binding:
                    return any
                case _ as Optional<Any>:
                    if let displayStyle = mirror.displayStyle {
                        switch displayStyle {
                            case .enum:
                                return try? value(forEnum: any, type: mirror.subjectType)
                            default:
                                break
                        }
                    }
                    if options.contains(.includeEmptyFields) {
                        fallthrough
                    } else {
                        return nil
                    }
                default:
                    return String(describing: any)
            }
        } else if let displayStyle = mirror.displayStyle {
            switch displayStyle {
                case .class, .dictionary, .struct:
                    return dictionary(from: mirror, options: options, depth: depth)
                case .collection, .set, .tuple:
                    return array(from: mirror, options: options, depth: depth)
                case .enum, .optional:
                    return value(for: mirror.children.first!.value, options: options, depth: depth)
                @unknown default:
                    print("not matched")
                    return nil
            }
        } else {
            return nil
        }
    }

    private class func dictionary(from mirror: Mirror, options: Options = [], depth: Int) -> [String: Any] {
        return mirror.children.reduce(into: [String: Any]()) {
            var key: String!
            var value: Any!
            if let label = $1.label {
                key = label
                value = $1.value
            } else {
                let array = self.array(from: Mirror(reflecting: $1.value), options: options, depth: depth + 1)
                guard 2 <= array.count,
                    let newKey = (array[0] as? String) else {
                    return
                }
                key = newKey
                value = array[1]
            }
            if let value = self.value(for: value!, options: options, depth: depth + 1) {
                $0[key] = value
            }
        }
    }

    private class func array(from mirror: Mirror, options: Options = [], depth: Int) -> [Any] {
        return mirror.children.compactMap {
            value(for: $0.value, options: options, depth: depth)
        }
    }

    private static var cache: [String: TypeInfo] = [:]
    private class func getTypeInfo(of type: Any.Type) throws -> TypeInfo {
        let key = String(describing: type)
        if let info = cache[key] {
            return info
        } else {
            let info = try typeInfo(of: type)
            cache[key] = info
            return info
        }
    }

    private class func value(forEnum item: Any, type: Any.Type) throws -> Int {
        let info = try getTypeInfo(of: type)
        let cases = info.cases
        let name = String(describing: item)
        let first = (0 ..< cases.count).first { cases[$0].name == name }
        guard let result = first else {
            throw EncodingError.invalidWrap(item)
        }
        return result
    }
}

class AnyDecoder {
    open func decode<T>(_ type: T.Type, from container: [String:Binding]) throws -> T {
        throw DecodingError.mismatch(type)
    }
}
