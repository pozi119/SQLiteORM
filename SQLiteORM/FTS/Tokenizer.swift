//
//  Tokenizer.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation
import NaturalLanguage

public typealias Token = SQLiteORMToken
public typealias IEnumerator = SQLiteORMEnumerator

public struct TokenMask: OptionSet {
    public var rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let transform = TokenMask(rawValue: 1 << 0)
    public static let pinyin = TokenMask(rawValue: 1 << 1)
    public static let abbreviation = TokenMask(rawValue: 1 << 2)
    public static let syllable = TokenMask(rawValue: 1 << 3)

    public static let `default` = TokenMask([.transform])
    public static let allPinYin = TokenMask([.pinyin, .abbreviation])
    public static let all = TokenMask(rawValue: 0xFFFFFF)
}

// @_silgen_name("swift_tokenize")

/// natural languagei tokenizer
public class NaturalEnumerator: NSObject, IEnumerator {
    public static func enumerate(_ input: UnsafePointer<Int8>, mask: UInt64) -> [Token] {
        let string = String(cString: input, encoding: .utf8) ?? ""
        let bytes = string.bytes

        guard bytes.count > 0 else { return [] }
        let source = String(bytes: bytes)

        var results: [Token] = []
        if #available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = source

            let range = source.startIndex ..< source.endIndex
            tokenizer.enumerateTokens(in: range) { (tokenRange, _) -> Bool in
                let tk = source[tokenRange]
                let pre = source[source.startIndex ..< tokenRange.lowerBound]
                let start = pre.utf8.count
                let len = tk.utf8.count
                let token = Token(String(tk), len: Int32(len), start: Int32(start), end: Int32(start + len))
                results.append(token)
                return true
            }
        }

        return results
    }
}

/// CoreFundation tokenizer
public class AppleEnumerator: NSObject, IEnumerator {
    public static func enumerate(_ input: UnsafePointer<Int8>, mask: UInt64) -> [Token] {
        let string = String(cString: input, encoding: .utf8) ?? ""
        let bytes = string.bytes

        guard bytes.count > 0 else { return [] }
        let source = String(bytes: bytes)

        var results: [Token] = []
        let cfText = source as CFString
        let cfRange = CFRangeMake(0, source.count)
        let cfLocale = CFLocaleCopyCurrent()

        let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, cfText, cfRange, kCFStringTokenizerUnitWordBoundary, cfLocale)
        guard tokenizer != nil else { return results }

        var tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer!, 0)
        var range: CFRange

        while tokenType != .init(rawValue: 0) {
            range = CFStringTokenizerGetCurrentTokenRange(tokenizer!)
            let startBound = source.startIndex
            let lowerBound = source.index(startBound, offsetBy: range.location)
            let upperBound = source.index(startBound, offsetBy: range.location + range.length)
            let tk = source[lowerBound ..< upperBound]
            let pre = source[startBound ..< lowerBound]
            let len = tk.utf8.count
            let start = pre.utf8.count
            let token = Token(String(tk), len: Int32(len), start: Int32(start), end: Int32(start + len))
            results.append(token)
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer!)
        }

        return results
    }
}

/// SQLiteORM tokenizer
public class OrmEnumerator: NSObject, IEnumerator {
    public static func enumerate(_ input: UnsafePointer<Int8>, mask: UInt64) -> [Token] {
        return []
    }
}
