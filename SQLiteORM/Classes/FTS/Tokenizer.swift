//
//  Tokenizer.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation
import NaturalLanguage

public typealias Token = SQLiteORMToken

public struct TokenMethod: OptionSet, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let apple = TokenMethod(rawValue: 1 << 0)
    public static let natural = TokenMethod(rawValue: 1 << 1)
    public static let sqliteorm = TokenMethod(rawValue: 1 << 2)

    public static let unknown = TokenMethod([])
}

public struct TokenMask: OptionSet {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    var pinyin: UInt32 { return rawValue & 0xFFFF }

    public static let pinyin = TokenMask(rawValue: 0xFFFF)
    public static let abbreviation = TokenMask(rawValue: 1 << 16)
    public static let number = TokenMask(rawValue: 1 << 17)
    public static let transform = TokenMask(rawValue: 1 << 18)

    public static let `default` = TokenMask([.number, .transform])
    public static let allPinYin = TokenMask([.pinyin, .abbreviation])
    public static let all = TokenMask(rawValue: 0xFFFFFF)

    public static let syllable = TokenMask(rawValue: 1 << 24)
    public static let query = TokenMask(rawValue: 1 << 25)
}

private enum TokenType: Int {
    case none = 0, letter, digit, symbol, other
    case auxiliary
}

private struct TokenCursor {
    var type: TokenType = .none
    var offset: Int = 0
    var len: Int = 0
}

private class CursorTuple {
    var cursors: [TokenCursor]
    var type: TokenType
    var encoding: String.Encoding
    var syllable: Bool = false

    init(cursors: [TokenCursor], type: TokenType, encoding: String.Encoding) {
        self.cursors = cursors
        self.type = type
        self.encoding = encoding
    }

    class func group(_ cursors: [TokenCursor]) -> [CursorTuple] {
        guard cursors.count > 0 else { return [] }

        var results: [CursorTuple] = []
        var last: TokenType = .none
        var subs: [TokenCursor] = []
        for c in cursors {
            let change = c.type != last
            var encoding: String.Encoding = .init(rawValue: UInt.max)
            if change {
                switch last {
                case .letter, .digit: encoding = .ascii
                default: encoding = .utf8
                }
                if encoding.rawValue != .max {
                    let tuple = CursorTuple(cursors: subs, type: last, encoding: encoding)
                    results.append(tuple)
                }
                last = c.type
                subs.removeAll()
            }
            subs.append(c)
        }
        return results
    }
}

public protocol Tokenizer {
    static func tokenize(_ bytes: [UInt8], _ method: TokenMethod, _ mask: TokenMask) -> [Token]
}

@_silgen_name("swift_tokenize")
public func swift_tokenize(_ source: NSString, _ method: Int, _ mask: UInt32) -> NSArray {
    guard source.length > 0 else { return [] as NSArray }
    let bytes = source.lowercased.bytes
    return tokenize(bytes, TokenMethod(rawValue: method), .init(rawValue: mask)) as NSArray
}

private var tokenizers: [TokenMethod: Tokenizer.Type] = [:]
public func register(_ tokenizer: Tokenizer.Type, for method: TokenMethod) {
    tokenizers[method] = tokenizer
}

public func tokenize(_ bytes: [UInt8], _ method: TokenMethod = .unknown, _ mask: TokenMask) -> [Token] {
    var tokens: [Token] = []
    switch method {
    case .apple: tokens = appleTokenize(bytes, mask: mask)
    case .natural: tokens = naturalTokenize(bytes, mask: mask)
    case .sqliteorm: tokens = ormTokenize(bytes, mask: mask)
    default:
        if let tokenizer = tokenizers[method] {
            tokens = tokenizer.tokenize(bytes, method, mask)
        }
        break
    }
    return Array(Set(tokens))
}

/// 自然语言处理分词
private func naturalTokenize(_ bytes: [UInt8], mask: TokenMask, locale: String = "") -> [Token] {
    guard bytes.count > 0 else { return [] }
    let source = String(bytes: bytes)

    var results: [Token] = []
    if #available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = source
        if locale.count > 0 {
            tokenizer.setLanguage(NLLanguage(rawValue: locale))
        }
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

    if mask.rawValue > 0 {
        let extras = extraTokens(of: bytes, mask: mask)
        results += extras
    }
    return results
}

/// CoreFundation分词
private func appleTokenize(_ bytes: [UInt8], mask: TokenMask, locale: String = "") -> [Token] {
    guard bytes.count > 0 else { return [] }
    let source = String(bytes: bytes)

    var results: [Token] = []
    let cfText = source as CFString
    let cfRange = CFRangeMake(0, source.count)
    let cfLocale = locale.count > 0 ? Locale(identifier: locale) as CFLocale : CFLocaleCopyCurrent()

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

    if mask.rawValue > 0 {
        let extras = extraTokens(of: bytes, mask: mask)
        results += extras
    }
    return results
}

/// SQLiteORM分词
private func ormTokenize(_ bytes: [UInt8], mask: TokenMask) -> [Token] {
    guard bytes.count > 0 else { return [] }

    var results: [Token] = []
    let cs = cursors(of: bytes)
    let tuples = CursorTuple.group(cs)

    if mask.rawValue > 0 {
        let extras = extraTokens(of: bytes, tuples: tuples, mask: mask)
        results += extras
    }

    let ormTks = ormTokens(of: bytes, tuples: tuples, mask: mask)
    results += ormTks

    return results
}

private func extraTokens(of bytes: [UInt8], mask: TokenMask) -> [Token] {
    let cs = cursors(of: bytes)
    let tuples = CursorTuple.group(cs)
    return extraTokens(of: bytes, tuples: tuples, mask: mask)
}

private func extraTokens(of bytes: [UInt8], tuples: [CursorTuple], mask: TokenMask) -> [Token] {
    let pinyinTks = pinyinTokens(of: bytes, tuples: tuples, mask: mask)
    let syllableTks = syllableTokens(of: bytes, tuples: tuples, mask: mask)
    let numberTks = numberTokens(of: bytes, mask: mask)
    return pinyinTks + numberTks + syllableTks
}

private var symbolsSet: NSCharacterSet = {
    var set = CharacterSet()
    set.formUnion(.controlCharacters)
    set.formUnion(.whitespacesAndNewlines)
    set.formUnion(.nonBaseCharacters)
    set.formUnion(.punctuationCharacters)
    set.formUnion(.symbols)
    set.formUnion(.illegalCharacters)
    return set as NSCharacterSet
}()

private func isSymbol(_ ch: unichar) -> Bool {
    return symbolsSet.characterIsMember(ch)
}

private func cursors(of bytes: [UInt8]) -> [TokenCursor] {
    guard bytes.count > 0 else { return [] }
    let sourceLen = bytes.count

    var cursors: [TokenCursor] = []
    var len = 0
    var type: TokenType = .none
    var end = false
    var offset = 0

    while offset < sourceLen {
        autoreleasepool { () -> Void in
            let ch = bytes[offset]
            if ch < 0xC0 {
                len = 1
                if ch >= 0x30 && ch <= 0x39 {
                    type = .digit
                } else if (ch >= 0x41 && ch <= 0x5A) || (ch >= 0x61 && ch <= 0x7A) {
                    type = .letter
                } else {
                    type = isSymbol(unichar(ch)) ? .symbol : .other
                }
            } else if ch < 0xF0 {
                var unicode: unichar = 0
                if ch < 0xE0 {
                    len = 2
                    unicode = unichar(ch) & 0x1F
                } else {
                    len = 3
                    unicode = unichar(ch) & 0x0F
                }
                for j in (offset + 1) ..< (offset + len) {
                    if j < sourceLen {
                        unicode = (unicode << 6) | (unichar(bytes[j]) & 0x3F)
                    } else {
                        type = .none
                        len = sourceLen - j
                        end = true
                    }
                }
                if !end {
                    type = isSymbol(unichar(ch)) ? .symbol : .other
                }
            } else {
                type = .auxiliary
                if ch < 0xF8 {
                    len = 4
                } else if ch < 0xFC {
                    len = 5
                } else {
                    len = 3 // split every chinese character
                    // len = 6; // split every two chinese characters
                }
            }

            if end { return }
            cursors.append(TokenCursor(type: type, offset: offset, len: len))
            offset += len
        }
    }
    cursors.append(TokenCursor(type: .none, offset: sourceLen, len: 0))

    return cursors
}

private func wordTokens(of bytes: [UInt8], cursors: [TokenCursor], encoding: String.Encoding, quantity: Int = 3, tail: Bool = false) -> [Token] {
    guard bytes.count > 0, cursors.count > 0, quantity > 0 else { return [] }
    var tokens: [Token] = []
    let count = cursors.count
    let loop = tail ? count : (max(count - quantity, 0) + 1)
    for i in 0 ..< loop {
        let c1 = cursors[i]
        let loc = c1.offset
        var len = c1.len
        var j = 1
        while j < quantity && i + j < count {
            let c2 = cursors[i + j]
            len += c2.len
            j += 1
        }
        let sub = [UInt8](bytes[loc ..< (loc + len)])
        if let text = String(bytes: sub, encoding: encoding), text.count > 0 {
            let token = Token(text, len: Int32(len), start: Int32(loc), end: Int32(loc + len))
            tokens.append(token)
        }
    }

    return tokens
}

private func pinyinTokens(of bytes: [UInt8], tuples: [CursorTuple], mask: TokenMask) -> [Token] {
    guard mask.pinyin > 0, bytes.count > 0, tuples.count > 0, mask.pinyin >= bytes.count else { return [] }
    let abbr = mask.contains(.abbreviation)

    var results: [Token] = []
    for tuple in tuples {
        if tuple.type != .other || tuple.cursors.count == 0 { continue }
        let forfulls = wordTokens(of: bytes, cursors: tuple.cursors, encoding: tuple.encoding, quantity: 2, tail: false)
        for tk in forfulls {
            let fruit = tk.token.pinyins
            for pinyin in fruit.fulls {
                let fulltk = Token(pinyin, len: Int32(pinyin.count), start: tk.start, end: tk.end)
                results.append(fulltk)
            }
        }
        if !abbr { continue }
        let forabbrs = wordTokens(of: bytes, cursors: tuple.cursors, encoding: tuple.encoding, quantity: 3, tail: false)
        for tk in forabbrs {
            let fruit = tk.token.pinyins
            for pinyin in fruit.abbrs {
                let abbrtk = Token(pinyin, len: Int32(pinyin.count), start: tk.start, end: tk.end)
                results.append(abbrtk)
            }
        }
    }

    return results
}

private func syllableTokens(of bytes: [UInt8], tuples: [CursorTuple], mask: TokenMask) -> [Token] {
    guard mask.contains(.syllable), bytes.count > 0 else { return [] }

    var results: [Token] = []
    for tuple in tuples {
        if tuple.type != .letter || tuple.cursors.count == 0 { continue }
        let offset = tuple.cursors.first!.offset
        let len = tuples.count
        let sub = [UInt8](bytes[offset ..< (offset + len)])
        let str = String(bytes: sub, encoding: tuple.encoding) ?? ""
        let pinyins = str.pinyinSegmentation

        var start = offset
        for i in 0 ..< pinyins.count {
            var tk = pinyins[i]
            let flen = tk.count
            if i + 1 < pinyins.count {
                let second = pinyins[i + 1]
                tk += second
            }
            let tklen = tk.count
            let token = Token(tk, len: Int32(tklen), start: Int32(start), end: Int32(start + tklen))
            results.append(token)
            tuple.syllable = true
            start += flen
        }
    }
    return results
}

private func numberTokens(of bytes: [UInt8], mask: TokenMask) -> [Token] {
    guard mask.contains(.number), bytes.count > 3 else { return [] }

    var array: [(String, Int)] = []
    var offset = 0
    let copied = bytes + [0x0]
    var container: [UInt8] = []

    for i in 0 ..< copied.count {
        let ch = copied[i]
        var flag = false

        switch ch {
        case 0x30 ... 0x39, 0x2B ... 0x2E, 0x45, 0x65:
            flag = true
        default: break
        }

        if flag {
            container.append(ch)
            offset += 1
        } else {
            if offset > 0 {
                let numberString = String(bytes: container, encoding: .ascii) ?? ""
                array.append((numberString, i - offset))
            }
            offset = 0
            container = []
        }
    }

    var results: [Token] = []

    for (origin, offset) in array {
        let num = origin.cleanNumberString
        if num.count <= 0 { continue }

        let bytes = origin.bytes
        let len = bytes.count

        let loop = max(len - 3, 0) + 1

        for j in 0 ..< loop {
            var k = 0
            var l = 0
            var tkbytes: [UInt8] = []
            while l < 3 && j + k < len {
                let ch = bytes[j + k]
                if ch != 0x2C {
                    tkbytes.append(ch)
                    l += 1
                }
                k += 1
            }
            let tkstr = String(bytes: tkbytes)
            let token = Token(tkstr, len: Int32(l), start: Int32(offset + j), end: Int32(offset + j + k))
            results.append(token)
        }
    }

    return results
}

private func ormTokens(of bytes: [UInt8], tuples: [CursorTuple], mask: TokenMask) -> [Token] {
    guard bytes.count > 0, tuples.count > 0 else { return [] }
    let tail = !mask.contains(.query)
    var results: [Token] = []

    for tuple in tuples {
        if tuple.syllable { continue }
        let quantity = tuple.encoding == .ascii ? 3 : 2
        let tokens = wordTokens(of: bytes, cursors: tuple.cursors, encoding: tuple.encoding, quantity: quantity, tail: tail)
        results += tokens
    }
    return results
}
