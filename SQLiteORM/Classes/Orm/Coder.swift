//
//  Coder.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import Foundation

fileprivate final class Storage {
    private(set) var containers: [Any] = []

    var count: Int {
        return containers.count
    }

    var last: Any? {
        return containers.last
    }

    func push(container: Any) {
        containers.append(container)
    }

    @discardableResult func popContainer() -> Any {
        precondition(containers.count > 0, "Empty container stack.")
        return containers.popLast()!
    }
}

fileprivate struct OrmCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    public init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(index: Int) {
        stringValue = "Index \(index)"
        intValue = index
    }

    static let `super` = OrmCodingKey(stringValue: "super")!
}

fileprivate enum OrmCodableError: Error {
    case cast
    case unwrapped
    case tryValue
}

func cast<T>(_ item: Any?, as type: T.Type) throws -> T {
    if let value = item as? T {
        return value
    }

    guard item != nil && item is Binding else {
        throw OrmCodableError.cast
    }

    var value: T?
    switch type {
    case is Int.Type: value = Int(String(describing: item!)) as? T
    case is Int8.Type: value = Int8(String(describing: item!)) as? T
    case is Int16.Type: value = Int16(String(describing: item!)) as? T
    case is Int32.Type: value = Int32(String(describing: item!)) as? T
    case is Int64.Type: value = Int64(String(describing: item!)) as? T
    case is Int.Type: value = UInt(String(describing: item!)) as? T
    case is UInt8.Type: value = UInt8(String(describing: item!)) as? T
    case is UInt16.Type: value = UInt16(String(describing: item!)) as? T
    case is UInt32.Type: value = UInt32(String(describing: item!)) as? T
    case is UInt64.Type: value = UInt64(String(describing: item!)) as? T
    case is Bool.Type: value = Bool(String(describing: item!)) as? T
    case is Float.Type: value = Float(String(describing: item!)) as? T
    case is Double.Type: value = Double(String(describing: item!)) as? T
    case is String.Type: value = String(describing: item!) as? T
    default: value = nil
    }

    guard value != nil else {
        throw OrmCodableError.cast
    }
    return value!
}

fileprivate extension Dictionary {
    func tryValue(forKey key: Key) throws -> Value {
        guard let value = self[key] else {
            throw OrmCodableError.tryValue
        }
        return value
    }
}

/// 编码器, 将Struct/Class编码生成[[String:Binding]]数组,子Struct/Class将转换为Data
open class OrmEncoder: Encoder {
    open var codingPath: [CodingKey] = []
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    private var storage = Storage()

    public init() {}

    open func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer(KeyedContainer<Key>(encoder: self, codingPath: codingPath))
    }

    open func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContanier(encoder: self, codingPath: codingPath)
    }

    open func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleValueContainer(encoder: self, codingPath: codingPath)
    }

    private func box<T: Encodable>(_ value: T) throws -> Any {
        try value.encode(to: self)
        return storage.popContainer()
    }
}

extension OrmEncoder {
    open func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        do {
            return try cast(try box(value), as: [String: Any].self)
        } catch let error {
            let context = EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values.", underlyingError: error)
            throw EncodingError.invalidValue(value, context)
        }
    }

    open func encode<T: Encodable>(_ values: [T]) throws -> [[String: Any]] {
        var array = [[String: Any]]()
        for value in values {
            do {
                let encoded = try cast(try box(value), as: [String: Any].self)
                array.append(encoded)
            } catch _ {
                array.append([:])
            }
        }
        return array
    }
}

extension OrmEncoder {
    private class KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        private var encoder: OrmEncoder
        private(set) var codingPath: [CodingKey]
        private var storage: Storage

        init(encoder: OrmEncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
            storage = encoder.storage

            storage.push(container: [:] as [String: Any])
        }

        deinit {
            guard let dictionary = storage.popContainer() as? [String: Any] else {
                assertionFailure(); return
            }
            storage.push(container: dictionary)
        }

        private func set(_ value: Any, forKey key: String) {
            guard var dictionary = storage.popContainer() as? [String: Any] else { assertionFailure(); return }
            dictionary[key] = value
            storage.push(container: dictionary)
        }

        private func warp<T: Encodable>(_ value: T) throws -> Binding {
            do {
                return try JSONEncoder().encode(value)
            } catch {
                let depth = storage.count
                do {
                    try value.encode(to: encoder)
                } catch {
                    if storage.count > depth {
                        _ = storage.popContainer()
                    }

                    throw error
                }

                guard storage.count > depth else {
                    throw error
                }

                return storage.popContainer() as! Binding
            }
        }

        func encodeNil(forKey key: Key) throws { set(NSNull(), forKey: key.stringValue) }
        func encode(_ value: Bool, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Int, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Int8, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Int16, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Int32, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Int64, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: UInt, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: UInt8, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: UInt16, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: UInt32, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: UInt64, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Float, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: Double, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode(_ value: String, forKey key: Key) throws { set(value, forKey: key.stringValue) }
        func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            set(try warp(value), forKey: key.stringValue)
        }

        func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            set(try warp(value), forKey: key.stringValue)
        }

        func encodeConditional<T>(_ object: T, forKey key: Key) throws where T: AnyObject, T: Encodable {
            encoder.codingPath.append(key)
            defer { encoder.codingPath.removeLast() }
            set(try warp(object), forKey: key.stringValue)
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            codingPath.append(key)
            defer { codingPath.removeLast() }
            return KeyedEncodingContainer(KeyedContainer<NestedKey>(encoder: encoder, codingPath: codingPath))
        }

        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            codingPath.append(key)
            defer { codingPath.removeLast() }
            return UnkeyedContanier(encoder: encoder, codingPath: codingPath)
        }

        func superEncoder() -> Encoder {
            return encoder
        }

        func superEncoder(forKey key: Key) -> Encoder {
            return encoder
        }
    }

    private class UnkeyedContanier: UnkeyedEncodingContainer {
        var encoder: OrmEncoder
        private(set) var codingPath: [CodingKey]
        private var storage: Storage
        var count: Int { return storage.count }

        init(encoder: OrmEncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
            storage = encoder.storage

            storage.push(container: [] as [Any])
        }

        deinit {
            guard let array = storage.popContainer() as? [Any] else {
                assertionFailure(); return
            }
            storage.push(container: array)
        }

        private func push(_ value: Any) {
            guard var array = storage.popContainer() as? [Any] else { assertionFailure(); return }
            array.append(value)
            storage.push(container: array)
        }

        func encodeNil() throws { push(NSNull()) }
        func encode(_ value: Bool) throws {}
        func encode(_ value: Int) throws { push(try encoder.box(value)) }
        func encode(_ value: Int8) throws { push(try encoder.box(value)) }
        func encode(_ value: Int16) throws { push(try encoder.box(value)) }
        func encode(_ value: Int32) throws { push(try encoder.box(value)) }
        func encode(_ value: Int64) throws { push(try encoder.box(value)) }
        func encode(_ value: UInt) throws { push(try encoder.box(value)) }
        func encode(_ value: UInt8) throws { push(try encoder.box(value)) }
        func encode(_ value: UInt16) throws { push(try encoder.box(value)) }
        func encode(_ value: UInt32) throws { push(try encoder.box(value)) }
        func encode(_ value: UInt64) throws { push(try encoder.box(value)) }
        func encode(_ value: Float) throws { push(try encoder.box(value)) }
        func encode(_ value: Double) throws { push(try encoder.box(value)) }
        func encode(_ value: String) throws { push(try encoder.box(value)) }
        func encode<T: Encodable>(_ value: T) throws {
            encoder.codingPath.append(OrmCodingKey(index: count))
            defer { encoder.codingPath.removeLast() }
            push(try JSONEncoder().encode(value))
        }

        func encodeConditional<T>(_ object: T) throws where T: AnyObject, T: Encodable {
            encoder.codingPath.append(OrmCodingKey(index: count))
            defer { encoder.codingPath.removeLast() }
            push(try JSONEncoder().encode(object))
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            codingPath.append(OrmCodingKey(index: count))
            defer { codingPath.removeLast() }
            return KeyedEncodingContainer(KeyedContainer<NestedKey>(encoder: encoder, codingPath: codingPath))
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            codingPath.append(OrmCodingKey(index: count))
            defer { codingPath.removeLast() }
            return UnkeyedContanier(encoder: encoder, codingPath: codingPath)
        }

        func superEncoder() -> Encoder {
            return encoder
        }
    }

    private class SingleValueContainer: SingleValueEncodingContainer {
        var encoder: OrmEncoder
        private(set) var codingPath: [CodingKey]
        private var storage: Storage
        var count: Int { return storage.count }

        init(encoder: OrmEncoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
            storage = encoder.storage
        }

        private func push(_ value: Any) {
            guard var array = storage.popContainer() as? [Any] else { assertionFailure(); return }
            array.append(value)
            storage.push(container: array)
        }

        func encodeNil() throws { storage.push(container: NSNull()) }
        func encode(_ value: Bool) throws { storage.push(container: value) }
        func encode(_ value: Int) throws { storage.push(container: value) }
        func encode(_ value: Int8) throws { storage.push(container: value) }
        func encode(_ value: Int16) throws { storage.push(container: value) }
        func encode(_ value: Int32) throws { storage.push(container: value) }
        func encode(_ value: Int64) throws { storage.push(container: value) }
        func encode(_ value: UInt) throws { storage.push(container: value) }
        func encode(_ value: UInt8) throws { storage.push(container: value) }
        func encode(_ value: UInt16) throws { storage.push(container: value) }
        func encode(_ value: UInt32) throws { storage.push(container: value) }
        func encode(_ value: UInt64) throws { storage.push(container: value) }
        func encode(_ value: Float) throws { storage.push(container: value) }
        func encode(_ value: Double) throws { storage.push(container: value) }
        func encode(_ value: String) throws { storage.push(container: value) }
        func encode<T: Encodable>(_ value: T) throws { storage.push(container: try encoder.box(value)) }
    }
}

/// 解码器, 将[String:Binding]转换为Struct/Class
open class OrmDecoder: Decoder {
    open var codingPath: [CodingKey]
    open var userInfo: [CodingUserInfoKey: Any] = [:]
    fileprivate var storage = Storage()

    public init() {
        codingPath = []
    }

    public init(container: Any, codingPath: [CodingKey] = []) {
        storage.push(container: container)
        self.codingPath = codingPath
    }

    open func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let container = try lastContainer(forType: [String: Any].self)
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self, codingPath: [], container: try unboxRawType(container, as: [String: Any].self)))
    }

    open func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let container = try lastContainer(forType: [Any].self)
        return UnkeyedContanier(decoder: self, container: try unboxRawType(container, as: [Any].self))
    }

    open func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(decoder: self)
    }

    private func unboxRawType<T>(_ value: Any, as type: T.Type) throws -> T {
        return try cast(value, as: T.self)
    }

    private func unbox<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        do {
            return try unboxRawType(value, as: T.self)
        } catch {
            storage.push(container: value)
            defer { storage.popContainer() }
            return try T(from: self)
        }
    }

    private func unwarp<T: Decodable>(_ item: Any, type: T.Type) throws -> T {
        var result: T
        do {
            switch item {
            case let item as Data:
                result = try JSONDecoder().decode(type, from: item)
            case let item as [String: Any]:
                result = try decode(type, from: item)
            default:
                storage.push(container: item)
                result = try T(from: self)
                storage.popContainer()
            }
        } catch _ {
            return try cast(nil, as: T.self)
        }
        return result
    }

    private func lastContainer<T>(forType type: T.Type) throws -> Any {
        guard let value = storage.last else {
            let description = "Expected \(type) but found nil value instead."
            let error = DecodingError.Context(codingPath: codingPath, debugDescription: description)
            throw DecodingError.valueNotFound(type, error)
        }
        return value
    }
}

extension OrmDecoder {
    open func decode<T: Decodable>(_ type: T.Type, from container: Any) throws -> T {
        return try unbox(container, as: T.self)
    }
}

extension OrmDecoder {
    private class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private var decoder: OrmDecoder
        private(set) var codingPath: [CodingKey]
        private var container: [String: Any]

        init(decoder: OrmDecoder, codingPath: [CodingKey], container: [String: Any]) {
            self.decoder = decoder
            self.codingPath = codingPath
            self.container = container
        }

        var allKeys: [Key] { return container.keys.compactMap { Key(stringValue: $0) } }
        func contains(_ key: Key) -> Bool { return container[key.stringValue] != nil }

        private func find(forKey key: CodingKey) throws -> Any {
            return try container.tryValue(forKey: key.stringValue)
        }

        func _decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let value = try find(forKey: key)
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }
            return try decoder.unbox(value, as: T.self)
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard let entry = self.container[key.stringValue] else {
                let error = DecodingError.Context(codingPath: codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\").")
                throw DecodingError.keyNotFound(key, error)
            }

            return entry is NSNull
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return try _decode(type, forKey: key) }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return try _decode(type, forKey: key) }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return try _decode(type, forKey: key) }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return try _decode(type, forKey: key) }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return try _decode(type, forKey: key) }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return try _decode(type, forKey: key) }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return try _decode(type, forKey: key) }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return try _decode(type, forKey: key) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return try _decode(type, forKey: key) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return try _decode(type, forKey: key) }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return try _decode(type, forKey: key) }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return try _decode(type, forKey: key) }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try _decode(type, forKey: key) }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { return try _decode(type, forKey: key) }
        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            let item = try find(forKey: key)
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }
            return try decoder.unwarp(item, type: T.self)
        }

        func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
            let item = try find(forKey: key)
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }
            return try decoder.unwarp(item, type: T.self)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }

            let value = try find(forKey: key)
            let dictionary = try decoder.unboxRawType(value, as: [String: Any].self)
            return KeyedDecodingContainer(KeyedContainer<NestedKey>(decoder: decoder, codingPath: [], container: dictionary))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }

            let value = try find(forKey: key)
            let array = try decoder.unboxRawType(value, as: [Any].self)
            return UnkeyedContanier(decoder: decoder, container: array)
        }

        func _superDecoder(forKey key: CodingKey = OrmCodingKey.super) throws -> Decoder {
            decoder.codingPath.append(key)
            defer { decoder.codingPath.removeLast() }

            let value = try find(forKey: key)
            return OrmDecoder(container: value, codingPath: decoder.codingPath)
        }

        func superDecoder() throws -> Decoder {
            return try _superDecoder()
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            return try _superDecoder(forKey: key)
        }
    }

    private class UnkeyedContanier: UnkeyedDecodingContainer {
        private var decoder: OrmDecoder
        private(set) var codingPath: [CodingKey]
        private var container: [Any]

        var count: Int? { return container.count }
        var isAtEnd: Bool { return currentIndex >= count! }

        private(set) var currentIndex: Int
        private var currentCodingPath: [CodingKey] { return decoder.codingPath + [OrmCodingKey(index: currentIndex)] }

        init(decoder: OrmDecoder, container: [Any]) {
            self.decoder = decoder
            codingPath = decoder.codingPath
            self.container = container
            currentIndex = 0
        }

        private func checkIndex<T>(_ type: T.Type) throws {
            if isAtEnd {
                let error = DecodingError.Context(codingPath: currentCodingPath, debugDescription: "container is at end.")
                throw DecodingError.valueNotFound(T.self, error)
            }
        }

        func _decode<T: Decodable>(_ type: T.Type) throws -> T {
            try checkIndex(type)

            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer {
                decoder.codingPath.removeLast()
                currentIndex += 1
            }
            return try decoder.unbox(container[currentIndex], as: T.self)
        }

        func decodeNil() throws -> Bool {
            try checkIndex(Any?.self)

            if container[self.currentIndex] is NSNull {
                currentIndex += 1
                return true
            } else {
                return false
            }
        }

        func decode(_ type: Bool.Type) throws -> Bool { return try _decode(type) }
        func decode(_ type: Int.Type) throws -> Int { return try _decode(type) }
        func decode(_ type: Int8.Type) throws -> Int8 { return try _decode(type) }
        func decode(_ type: Int16.Type) throws -> Int16 { return try _decode(type) }
        func decode(_ type: Int32.Type) throws -> Int32 { return try _decode(type) }
        func decode(_ type: Int64.Type) throws -> Int64 { return try _decode(type) }
        func decode(_ type: UInt.Type) throws -> UInt { return try _decode(type) }
        func decode(_ type: UInt8.Type) throws -> UInt8 { return try _decode(type) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { return try _decode(type) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { return try _decode(type) }
        func decode(_ type: UInt64.Type) throws -> UInt64 { return try _decode(type) }
        func decode(_ type: Float.Type) throws -> Float { return try _decode(type) }
        func decode(_ type: Double.Type) throws -> Double { return try _decode(type) }
        func decode(_ type: String.Type) throws -> String { return try _decode(type) }
        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try checkIndex(type)
            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer {
                decoder.codingPath.removeLast()
                currentIndex += 1
            }
            return try decoder.unwarp(container[currentIndex], type: type)
        }

        func decodeIfPresent<T>(_ type: T.Type) throws -> T? where T: Decodable {
            try checkIndex(type)
            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer {
                decoder.codingPath.removeLast()
                currentIndex += 1
            }
            return try decoder.unwarp(container[currentIndex], type: type)
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer { decoder.codingPath.removeLast() }

            try checkIndex(UnkeyedContanier.self)

            let value = container[currentIndex]
            let dictionary = try cast(value, as: [String: Any].self)

            currentIndex += 1
            return KeyedDecodingContainer(KeyedContainer<NestedKey>(decoder: decoder, codingPath: [], container: dictionary))
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer { decoder.codingPath.removeLast() }

            try checkIndex(UnkeyedContanier.self)

            let value = container[currentIndex]
            let array = try cast(value, as: [Any].self)

            currentIndex += 1
            return UnkeyedContanier(decoder: decoder, container: array)
        }

        func superDecoder() throws -> Decoder {
            decoder.codingPath.append(OrmCodingKey(index: currentIndex))
            defer { decoder.codingPath.removeLast() }

            try checkIndex(UnkeyedContanier.self)

            let value = container[currentIndex]
            currentIndex += 1
            return OrmDecoder(container: value, codingPath: decoder.codingPath)
        }
    }

    private class SingleValueContainer: SingleValueDecodingContainer {
        private var decoder: OrmDecoder
        private(set) var codingPath: [CodingKey]

        init(decoder: OrmDecoder) {
            self.decoder = decoder
            codingPath = decoder.codingPath
        }

        func _decode<T>(_ type: T.Type) throws -> T {
            let container = try decoder.lastContainer(forType: type)
            return try decoder.unboxRawType(container, as: T.self)
        }

        func decodeNil() -> Bool { return decoder.storage.last == nil }
        func decode(_ type: Bool.Type) throws -> Bool { return try _decode(type) }
        func decode(_ type: Int.Type) throws -> Int { return try _decode(type) }
        func decode(_ type: Int8.Type) throws -> Int8 { return try _decode(type) }
        func decode(_ type: Int16.Type) throws -> Int16 { return try _decode(type) }
        func decode(_ type: Int32.Type) throws -> Int32 { return try _decode(type) }
        func decode(_ type: Int64.Type) throws -> Int64 { return try _decode(type) }
        func decode(_ type: UInt.Type) throws -> UInt { return try _decode(type) }
        func decode(_ type: UInt8.Type) throws -> UInt8 { return try _decode(type) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { return try _decode(type) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { return try _decode(type) }
        func decode(_ type: UInt64.Type) throws -> UInt64 { return try _decode(type) }
        func decode(_ type: Float.Type) throws -> Float { return try _decode(type) }
        func decode(_ type: Double.Type) throws -> Double { return try _decode(type) }
        func decode(_ type: String.Type) throws -> String { return try _decode(type) }
        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            return try decoder.unwarp(decoder.lastContainer(forType: type), type: type)
        }
    }
}
