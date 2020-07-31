//
//  CodingExtension.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/31.
//

import Foundation

extension EncodingError {
    public static func invalidEncode(_ object: Any, _ underlyingError: Error? = nil) -> Self {
        let context = EncodingError.Context(codingPath: [], debugDescription: "\(object) can not be encoded into any values.", underlyingError: underlyingError)
        return EncodingError.invalidValue(object, context)
    }

    public static func invalidCast(_ object: Any, _ type: Any.Type, _ underlyingError: Error? = nil) -> Self {
        let context = EncodingError.Context(codingPath: [], debugDescription: "\(object) can not be cast to \(type).", underlyingError: underlyingError)
        return EncodingError.invalidValue(object, context)
    }

    public static func invalidWrap(_ object: Any, _ underlyingError: Error? = nil) -> Self {
        let context = EncodingError.Context(codingPath: [], debugDescription: "\(object) can not be warpped.", underlyingError: underlyingError)
        return EncodingError.invalidValue(object, context)
    }

    public static func invalidUnwrap(_ object: Any, _ underlyingError: Error? = nil) -> Self {
        let context = EncodingError.Context(codingPath: [], debugDescription: "\(object) can not be unwarpped.", underlyingError: underlyingError)
        return EncodingError.invalidValue(object, context)
    }

    public static func invalidType(type: Any.Type, _ underlyingError: Error? = nil) -> Self {
        let context = EncodingError.Context(codingPath: [], debugDescription: "invalid type.", underlyingError: underlyingError)
        return EncodingError.invalidValue(type, context)
    }
}

extension DecodingError {
    public static func mismatch(_ type: Any.Type, _ underlyingError: Error? = nil) -> Self {
        let context = DecodingError.Context(codingPath: [], debugDescription: "invalid type.", underlyingError: underlyingError)
        return DecodingError.typeMismatch(type, context)
    }
}
