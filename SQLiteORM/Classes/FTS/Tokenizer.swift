//
//  Tokenizer.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation
import NaturalLanguage


/// 自然语言处理分词
public struct NLFtsTokenizer: FtsTokenizer {
    public static var enumerator: SQLiteORMXEnumerator {
        return { pText, nText, locale, pinyin, handler in
            if #available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
                let source = NSString(utf8String: pText) as String? ?? ""
                let loc = NSString(utf8String: locale) as String? ?? ""

                let tokenizer = NLTokenizer(unit: .word)
                tokenizer.string = source
                if loc.count > 0 {
                    tokenizer.setLanguage(NLLanguage(rawValue: loc))
                }
                let range = source.startIndex ..< source.endIndex
                var con = true
                tokenizer.enumerateTokens(in: range) { (tokenRange, _) -> Bool in
                    let tk = source[tokenRange]
                    let pre = source[source.startIndex ..< tokenRange.lowerBound]
                    let text = tk.utf8
                    let start = pre.utf8.count
                    let len = text.count
                    let ctk = (tk as NSString).utf8String

                    con = handler(ctk!, Int32(len), Int32(start), Int32(start + len)).boolValue
                    guard con else { return con }

                    guard pinyin.boolValue else { return true }

                    let pinyins = String(tk).pinyinTokens
                    for py in pinyins {
                        if py.count == 0 { continue }
                        let pyText = py.utf8
                        let pyLen = pyText.count
                        let pytk = (py as NSString).utf8String

                        con = handler(pytk!, Int32(pyLen), Int32(start), Int32(start + len)).boolValue
                        guard con else { return con }
                    }
                    return true
                }
            } else {
                _ = handler(pText, nText, 0, nText)
            }
        }
    }
}

/// CoreFundation分词
public struct AppleFtsTokenizer: FtsTokenizer {
    public static var enumerator: SQLiteORMXEnumerator {
        return { pText, nText, locale, pinyin, handler in

            let source = NSString(utf8String: pText) ?? NSString()
            guard nText > 0 && source.length > 0 else { return }

            let cfText = source as CFString
            let cfRange = CFRangeMake(0, source.length)
            let loc = NSString(utf8String: locale) as String? ?? ""
            let cfLocale = loc.count > 0 ? Locale(identifier: loc) as CFLocale : CFLocaleCopyCurrent()

            let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, cfText, cfRange, kCFStringTokenizerUnitWordBoundary, cfLocale)
            guard tokenizer != nil else { return }

            var tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer!, 0)
            var con = true
            var range: CFRange

            while tokenType != .init(rawValue: 0) && con {
                range = CFStringTokenizerGetCurrentTokenRange(tokenizer!)

                let tk = source.substring(with: NSRange(location: range.location, length: range.length))
                let pre = source.substring(to: range.location)
                let text = tk.utf8
                let start = pre.utf8.count
                let len = text.count
                let ctk = (tk as NSString).utf8String

                con = handler(ctk!, Int32(len), Int32(start), Int32(start + len)).boolValue

                if pinyin.boolValue {
                    let pinyins = String(tk).pinyinTokens
                    for py in pinyins {
                        if py.count == 0 { continue }
                        let pyText = py.utf8
                        let pyLen = pyText.count
                        let pytk = (py as NSString).utf8String

                        con = handler(pytk!, Int32(pyLen), Int32(start), Int32(start + len)).boolValue
                    }
                }

                tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer!)
            }
        }
    }
}

/// 结巴分词
public struct JiebaFtsTokenizer: FtsTokenizer {
    public static var enumerator: SQLiteORMXEnumerator {
        return { pText, _, _, pinyin, handler in
            var con = true
            SQLiteORMJieba.enumerateTokens(pText, using: { token, offset, len in
                let end = offset + len
                con = handler(token, Int32(len), Int32(offset), Int32(end)).boolValue

                guard con else { return con }
                guard pinyin.boolValue else { return true }

                let pinyins = (NSString(utf8String: token) as String? ?? "").pinyinTokens
                for py in pinyins {
                    if py.count == 0 { continue }
                    let pyText = py.utf8
                    let pyLen = pyText.count
                    let pytk = (py as NSString).utf8String

                    con = handler(pytk!, Int32(pyLen), Int32(offset), Int32(end)).boolValue
                    guard con else { return con }
                }
                return true
            })
        }
    }
}
