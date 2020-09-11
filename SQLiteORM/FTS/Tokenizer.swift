//
//  Tokenizer.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation
import NaturalLanguage

public protocol Enumerator {
    static func enumerate(_ source: String, mask: TokenMask) -> [Token]
}

public let TOKEN_ORIGIN = 0
public let TOKEN_FULLWIDTH = 1
public let TOKEN_FULLPINYIN = 2
public let TOKEN_ABBREVIATION = 3
public let TOKEN_SYLLABLE = 4

public final class Token: Hashable {
    public var word: String
    public var len: Int
    public var start: Int
    public var end: Int

    /// TOKEN_ORIGIN, TOKEN_FULLWIDTH, TOKEN_FULLPINYIN, TOKEN_ABBREVIATION, TOKEN_SYLLABLE
    public var colocated: Int

    private lazy var weight: Int = (0xF - colocated) << 24 | start << 16 | end << 8 | len

    public init(word: String, len: Int, start: Int, end: Int, colocated: Int) {
        self.word = word
        self.len = len
        self.start = start
        self.end = end
        self.colocated = colocated
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(word)
        hasher.combine(len)
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(colocated)
    }
}

extension Token: CustomStringConvertible {
    public var description: String {
        return String(format: "[%2i-%2i|%2i|%i|0x%09lx]: %@ ", start, end, len, colocated, hashValue, word)
    }
}

extension Token: Comparable {
    public static func < (lhs: Token, rhs: Token) -> Bool {
        return lhs.weight == rhs.weight ? lhs.word < rhs.word : lhs.weight < rhs.weight
    }

    public static func <= (lhs: Token, rhs: Token) -> Bool {
        return lhs.weight == rhs.weight ? lhs.word <= rhs.word : lhs.weight <= rhs.weight
    }

    public static func > (lhs: Token, rhs: Token) -> Bool {
        return lhs.weight == rhs.weight ? lhs.word > rhs.word : lhs.weight > rhs.weight
    }

    public static func >= (lhs: Token, rhs: Token) -> Bool {
        return lhs.weight == rhs.weight ? lhs.word >= rhs.word : lhs.weight >= rhs.weight
    }

    public static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

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

    func hasPinyin() -> Bool {
        return intersection([.pinyin, .abbreviation, .syllable]).rawValue > 0
    }
}

/// natural languagei tokenizer
public class NaturalEnumerator: Enumerator {
    public class func enumerate(_ source: String, mask: TokenMask) -> [Token] {
        guard source.count > 0 else { return [] }

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
                let token = Token(word: String(tk), len: len, start: start, end: start + len, colocated: TOKEN_ORIGIN)
                results.append(token)
                return true
            }
        }

        return results
    }
}

/// CoreFundation tokenizer
public class AppleEnumerator: Enumerator {
    public class func enumerate(_ source: String, mask: TokenMask) -> [Token] {
        guard source.count > 0 else { return [] }

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
            let token = Token(word: String(tk), len: len, start: start, end: start + len, colocated: TOKEN_ORIGIN)
            results.append(token)
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer!)
        }

        return results
    }
}

func unicode2utf8(_ ch: UInt32, _ utf8: inout [UInt8]) -> Int {
    var len = 0
    if ch < 0x80 {
        utf8[0] = UInt8(ch & 0x7F)
        len = 1
    } else if ch < 0x800 {
        utf8[0] = UInt8(((ch >> 6) & 0x1F) | 0xC0)
        utf8[1] = UInt8((ch & 0x3F) | 0x80)
        len = 2
    } else if ch < 0x10000 {
        utf8[0] = UInt8(((ch >> 12) & 0xF) | 0xE0)
        utf8[1] = UInt8(((ch >> 6) & 0x3F) | 0x80)
        utf8[2] = UInt8((ch & 0x3F) | 0x80)
        len = 3
    } else if ch < 0x200000 {
        utf8[0] = UInt8(((ch >> 18) & 0x7) | 0xF0)
        utf8[1] = UInt8(((ch >> 12) & 0x3F) | 0x80)
        utf8[2] = UInt8(((ch >> 6) & 0x3F) | 0x80)
        utf8[3] = UInt8((ch & 0x3F) | 0x80)
        len = 4
    } else if ch < 0x4000000 {
        utf8[0] = UInt8(((ch >> 24) & 0x3) | 0xF8)
        utf8[1] = UInt8(((ch >> 18) & 0x3F) | 0x80)
        utf8[2] = UInt8(((ch >> 12) & 0x3F) | 0x80)
        utf8[3] = UInt8(((ch >> 6) & 0x3F) | 0x80)
        utf8[4] = UInt8((ch & 0x3F) | 0x80)
        len = 5
    } else {
        utf8[0] = UInt8(((ch >> 30) & 0x1) | 0xFC)
        utf8[1] = UInt8(((ch >> 24) & 0x3F) | 0x80)
        utf8[2] = UInt8(((ch >> 18) & 0x3F) | 0x80)
        utf8[3] = UInt8(((ch >> 12) & 0x3F) | 0x80)
        utf8[4] = UInt8(((ch >> 6) & 0x3F) | 0x80)
        utf8[5] = UInt8((ch & 0x3F) | 0x80)
        len = 6
    }
    return len
}

func utf82unicode(_ utf8: [UInt8], _ len: Int) -> UInt32 {
    guard utf8.count >= len else { return 0 }

    var ch: UInt32 = 0
    switch len {
        case 1:
            ch = (UInt32)(utf8[0] & 0x7F)
            break

        case 2:
            ch = ((UInt32)(utf8[0] & 0x1F) << 6) | (UInt32)(utf8[1] & 0x3F)
            break

        case 3:
            ch = ((UInt32)(utf8[0] & 0xF) << 12) | ((UInt32)(utf8[1] & 0x3F) << 6) | (UInt32)(utf8[2] & 0x3F)
            break

        case 4:
            ch = ((UInt32)(utf8[0] & 0x7) << 18) | ((UInt32)(utf8[1] & 0x3F) << 12) | ((UInt32)(utf8[2] & 0x3F) << 6) | (UInt32)(utf8[3] & 0x3F)
            break

        case 5:
            ch = ((UInt32)(utf8[0] & 0x3) << 24) | ((UInt32)(utf8[1] & 0x3F) << 18) | ((UInt32)(utf8[2] & 0x3F) << 12) | ((UInt32)(utf8[3] & 0x3F) << 6) | (UInt32)(utf8[4] & 0x3F)
            break

        case 6:
            ch = ((UInt32)(utf8[0] & 0x1) << 30) | ((UInt32)(utf8[1] & 0x3F) << 24) | ((UInt32)(utf8[2] & 0x3F) << 18) | ((UInt32)(utf8[3] & 0x3F) << 12) | ((UInt32)(utf8[4] & 0x3F) << 6) | (UInt32)(utf8[5] & 0x3F)
            break

        default:
            break
    }
    return ch
}

/// SQLiteORM tokenizer
public class OrmEnumerator: Enumerator {
    private class func syllableTokens(_ source: String, _ end: Int) -> [Token] {
        var results: [Token] = []
        #if false
            let allPinyins = source.pinyinSegmentation
            for n in 0 ..< allPinyins.count {
                var start = end - source.count
                let pinyins = allPinyins[n]
                for i in 0 ..< pinyins.count {
                    let tkString = pinyins[i]
                    let len = tkString.count
                    let token = Token(word: tkString, len: len, start: start, end: start + len, colocated: n + TOKEN_SYLLABLE)
                    results.append(token)
                    start += len
                }
            }
        #else
            var start = end - source.count
            let pinyins = source.fastPinyinSegmentation
            for i in 0 ..< pinyins.count {
                let tkString = pinyins[i]
                let len = tkString.count
                let token = Token(word: tkString, len: len, start: start, end: start + len, colocated: TOKEN_ORIGIN)
                results.append(token)
                start += len
            }
        #endif
        return results
    }

    public class func enumerate(_ source: String, mask: TokenMask) -> [Token] {
        let buff = source.bytes
        let nText = buff.count
        guard nText > 0 else { return [] }

        var results: [Token] = []
        let usetrans = mask.contains(.transform)
        let usepinyin = mask.contains(.pinyin)
        let useabbr = mask.contains(.abbreviation)
        let usesyllable = mask.contains(.syllable)

        var idx = 0
        var length = 0
        var syllableString = ""
        var syllableTks: [Token] = []
        var syllableRanges: [Range<Int>] = []

        while idx < nText {
            if buff[idx] < 0xC0 {
                length = 1
            } else if buff[idx] < 0xE0 {
                length = 2
            } else if buff[idx] < 0xF0 {
                length = 3
            } else if buff[idx] < 0xF8 {
                length = 4
            } else if buff[idx] < 0xFC {
                length = 5
            } else {
                length = 6
                assert(false, "wrong utf-8 text")
                break
            }

            var word = [UInt8](buff[idx ..< (idx + length)])
            var wordlen = length

            // full width to half width
            if length == 3 && word[0] == 0xEF {
                let uni = ((unichar)(word[0] & 0xF) << 12) | ((unichar)(word[1] & 0x3F) << 6) | (unichar)(word[2] & 0x3F)
                if uni >= 0xFF01 && uni <= 0xFF5E {
                    word[0] = UInt8(uni - 0xFEE0)
                    word[1] = 0
                    wordlen = 1
                } else if uni >= 0xFFE0 && uni <= 0xFFE5 {
                    switch uni {
                        case 0xFFE0: word[1] = 0xA2; break
                        case 0xFFE1: word[1] = 0xA3; break
                        case 0xFFE2: word[1] = 0xAC; break
                        case 0xFFE3: word[1] = 0xAF; break
                        case 0xFFE4: word[1] = 0xA6; break
                        case 0xFFE5: word[1] = 0xA5; break
                        default: break
                    }
                    word[0] = 0xC2
                    word[2] = 0
                    wordlen = 2
                } else if uni == 0x3000 {
                    word[0] = 0x20
                    word[1] = 0
                    wordlen = 1
                }
            }
            if length >= 3 && (usetrans || usepinyin) {
                let uni = unichar(utf82unicode(word, length))
                if uni > 0 {
                    let simp = PinYin.shared.big52gbMap[uni] ?? uni

                    if usetrans {
                        // trad 2 simp
                        wordlen = unicode2utf8(UInt32(simp), &word)
                    }

                    if usepinyin {
                        let pinyins = PinYin.shared.hanzi2pinyins[simp] ?? []
                        var fulls = Set<NSString>()
                        var abbrs = Set<NSString>()
                        for pinyin in pinyins {
                            let py = pinyin as NSString
                            fulls.insert(py.substring(to: py.length - 1) as NSString)
                            abbrs.insert(py.substring(to: 1) as NSString)
                        }
                        for full in fulls {
                            let token = Token(word: full as String, len: full.length, start: idx, end: idx + length, colocated: TOKEN_FULLPINYIN)
                            results.append(token)
                        }
                        if useabbr {
                            for abbr in abbrs {
                                let token = Token(word: abbr as String, len: abbr.length, start: idx, end: idx + length, colocated: TOKEN_ABBREVIATION)
                                results.append(token)
                            }
                        }
                    }
                }
            }

            // upper case to lower case
            if wordlen == 1 && word[0] > 64 && word[0] < 91 {
                word[0] += 32
            }
            // syllable
            if usesyllable {
                if wordlen == 1 && word[0] > 96 && word[0] < 123 {
                    syllableString += String(bytes: [word[0]])
                } else if syllableString.count > 0 {
                    let subTks = syllableTokens(syllableString, idx)
                    if subTks.count > 0 {
                        syllableRanges.append((idx - syllableString.count) ..< idx)
                        syllableTks += subTks
                    }
                    syllableString = ""
                }
            }

            let wordstr = String(bytes: word)
            let token = Token(word: wordstr, len: wordlen, start: idx, end: idx + length, colocated: wordlen != length ? TOKEN_FULLWIDTH : TOKEN_ORIGIN)
            results.append(token)
            idx += length
        }
        if usesyllable {
            if syllableString.count > 0 {
                let subTks = syllableTokens(syllableString, idx)
                if subTks.count > 0 {
                    syllableRanges.append((idx - syllableString.count) ..< idx)
                    syllableTks += subTks
                }
            }
            if syllableRanges.count > 0 {
                results = results.filter({ (tk) -> Bool in
                    for r in syllableRanges {
                        if r.contains(tk.start) { return false }
                    }
                    return true
                })
                results += syllableTks
            }
        }
        return results
    }
}
