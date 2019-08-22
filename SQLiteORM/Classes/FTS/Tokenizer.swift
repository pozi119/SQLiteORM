//
//  Tokenizer.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation
import NaturalLanguage

public struct Token {
    var token: String = ""
    var len: Int = 0
    var start: Int = 0
    var end: Int = 0
}

extension Token: CustomStringConvertible {
    public var description: String {
        return token + ",\(len),\(start),\(end)"
    }
}

public enum TokenMethod: Int {
    case apple, natural, sqliteorm
    case unknown = 0xFFFFFFFF
}

enum TokenType {
    case none, letter, digit, symbol, other
    case auxiliary
}

struct TokenCursor {
    var type: TokenType = .none
    var offset: Int = 0
    var len: Int = 0
}

@_silgen_name("swift_tokenize")
public func tokenize(_ source: String, _ method: TokenMethod = .unknown) -> [Token] {
    switch method {
    case .apple: return appleTokenize(source)
    case .natural: return naturalTokenize(source)
    case .sqliteorm: return ormTokenize(source)
    default: return []
    }
}

/// 自然语言处理分词
func naturalTokenize(_ source: String, locale: String = "") -> [Token] {
    guard source.count > 0 else { return [] }

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
            let text = tk.utf8
            let start = pre.utf8.count
            let len = text.count
            let token = Token(token: String(tk), len: len, start: start, end: start + len)
            results.append(token)
            return true
        }
    }
    return results
}

/// CoreFundation分词
func appleTokenize(_ source: String, locale: String = "") -> [Token] {
    guard source.count > 0 else { return [] }

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
        let token = Token(token: String(tk), len: len, start: start, end: start + len)
        results.append(token)
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer!)
    }
    return results
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

func isSymbol(_ ch: unichar) -> Bool {
    return symbolsSet.characterIsMember(ch)
}

/// SQLiteORM分词
func ormTokenize(_ source: String) -> [Token] {
    let cSource = source.utf8CString.map { UInt8($0) }
    let sourceLen = cSource.count
    guard sourceLen > 0 else { return [] }

    var cursors: [TokenCursor] = []
    var len = 0
    var type: TokenType = .none
    var end = false
    var offset = 0

    while offset < sourceLen {
        autoreleasepool { () -> Void in
            let ch = cSource[offset]
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
                        unicode = (unicode << 6) | (unichar(cSource[j]) & 0x3F)
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

    var results: [Token] = []
    var lastType: TokenType = .none
    var partOffset = 0
    var partLength = 0

    for cursor in cursors {
        autoreleasepool { () -> Void in
            let change = cursor.type != lastType
            if change {
                if partLength > 0 {
                    switch lastType {
                    case .letter: fallthrough
                    case .digit:
                        let range = partOffset ..< (partOffset + partLength)
                        let string = String(bytes: cSource[range], encoding: .ascii) ?? ""
                        results.append(Token(token: string, len: partLength, start: partOffset, end: partOffset + partLength))

                    default: break
                    }
                }

                switch cursor.type {
                case .letter: fallthrough
                case .digit:
                    partOffset = cursor.offset
                    partLength = 0

                default: break
                }
            }

            switch cursor.type {
            case .letter: fallthrough
            case .digit:
                partLength += cursor.len

            case .symbol: fallthrough
            case .other: fallthrough
            case .auxiliary:
                if cursor.len > 0 {
                    let range = cursor.offset ..< (cursor.offset + cursor.len)
                    let string = String(bytes: cSource[range], encoding: .ascii) ?? ""
                    if string.count > 0 {
                        results.append(Token(token: string, len: cursor.len, start: cursor.offset, end: cursor.offset + cursor.len))
                    }
                }

            default: break
            }
        }
        lastType = cursor.type
    }

    return results
}

/// 拼音分词
@_silgen_name("swift_pinyinTokenize")
public func pinyinTokenize(_ source: String, _ start: Int, _ end: Int) -> [Token] {
    guard source.count > 0 else { return [] }
    var results: [Token] = []
    let pinyins = source.pinyinTokens
    for py in pinyins {
        let len = py.utf8.count
        if len <= 0 || py == source {
            continue
        }
        results.append(Token(token: py, len: len, start: start, end: end))
    }
    return results
}

/// 数字分词
@_silgen_name("swift_numberTokenize")
public func numberTokenize(_ source: String) -> [Token] {
    let utf8 = source.utf8CString
    let len = utf8.count

    guard len > 0 else { return [] }

    var array: [(String, Int)] = []
    var str = ""
    var offset = -1

    for i in 0 ..< len {
        let ch = utf8[i]
        if ch >= 0x30 && ch <= 0x39 {
            if ch > 0x30 && offset < 0 {
                offset = i
            }
            if offset >= 0 {
                str.append("\(ch)")
            }
        } else if offset >= 0 {
            switch ch {
            case 0x2C:
                str.append(",")
                break
            default:
                array.append((str, offset))
                str = ""
                offset = -1
                break
            }
        }
    }
    if offset >= 0 {
        array.append((str, offset))
    }

    var results: [Token] = []
    for (s, o) in array {
        let tks = s.numberTokens
        if tks.count < 2 {
            continue
        }
        let l = s.count
        for numstr in tks {
            results.append(Token(token: numstr, len: l, start: o, end: o + l))
        }
    }

    return results
}
