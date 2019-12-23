//
//  Highlighter.swift
//  SQLiteORM
//
//  Created by Valo on 2019/8/23.
//

public struct Match {
    public enum `Type`: Int {
        case full = 0, pinyinFull, prefix, pinyinPrefix, middle, pinyinMiddle
        case other, none
    }

    public var type: Type = .none
    public var range: Range<String.Index> = "".startIndex ..< "".endIndex
    public var source: String
    public var attrText: NSAttributedString
}

extension Match: Comparable {
    public static func < (lhs: Match, rhs: Match) -> Bool {
        guard lhs.type == rhs.type else {
            return lhs.type.rawValue < rhs.type.rawValue
        }
        switch lhs.type {
        case .prefix, .pinyinPrefix:
            return lhs.source < rhs.source
        case .middle, .pinyinMiddle:
            if lhs.range.lowerBound == rhs.range.upperBound {
                return lhs.range.upperBound < rhs.range.upperBound
            } else {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
        default:
            return true
        }
    }
}

public class Highlighter {
    var keyword: String
    var method: TokenMethod = .sqliteorm
    var mask: TokenMask = .default
    var attrTextMaxLen: Int = 17
    var highlightAttributes: [NSAttributedString.Key: Any]
    var normalAttributes: [NSAttributedString.Key: Any] = [:]
    var reserved: Any?

    private lazy var keywordTokens: [Token] = {
        assert(self.keyword.count > 0, "invalid keyword")
        var pylen = self.mask.rawValue & TokenMask.pinyin.rawValue
        pylen = max(pylen, 30)
        let mask = (self.mask.rawValue & (~TokenMask.pinyin.rawValue)) | TokenMask.splitPinyin.rawValue | pylen
        return tokenize(self.keyword.decoded.bytes, self.method, .init(rawValue: mask))
    }()

    private lazy var keywordSplitedPinyins = self.keyword.splitedPinyins

    public convenience init(orm: Orm, keyword: String, highlightAttributes: [NSAttributedString.Key: Any]) {
        let config = orm.config as? FtsConfig
        assert(config != nil, "invalid fts orm")
        let tokenizer = config!.tokenizer.components(separatedBy: " ").first ?? ""
        let method = orm.db.enumerator(for: tokenizer)
        self.init(method: method, keyword: keyword, highlightAttributes: highlightAttributes)
    }

    public init(method: TokenMethod, keyword: String, highlightAttributes: [NSAttributedString.Key: Any]) {
        assert(keyword.count > 0, "Invalid keyword")
        self.method = method
        self.keyword = keyword
        self.highlightAttributes = highlightAttributes
    }

    public func highlight(_ source: String) -> Match? {
        var text = source.replacingOccurrences(of: "\n", with: " ").lowercased()
        var kw = keyword.lowercased()
        if mask.contains(.transform) {
            text = text.simplified
            kw = kw.simplified
        }

        var match = Match(source: source, attrText: NSAttributedString(string: source))
        let decoded = text.decoded
        let bytes = decoded.bytes
        let count = bytes.count
        let attrText = NSMutableAttributedString()

        if let range = text.range(of: kw) {
            match.range = range
            if range == text.startIndex ..< text.endIndex {
                match.type = .full
                match.attrText = NSAttributedString(string: source, attributes: highlightAttributes)
            } else if range.lowerBound == text.startIndex {
                match.type = .prefix
                let sk = String(source[range])
                let s2 = String(source[range.upperBound ..< source.endIndex])
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                match.attrText = attrText
            } else {
                match.type = .middle
                var s1 = String(source[source.startIndex ..< range.lowerBound])
                let sk = String(source[range])
                let s2 = String(source[range.upperBound ..< source.endIndex])
                if s1.count + sk.count > attrTextMaxLen {
                    let offset = max(0, attrTextMaxLen - sk.count)
                    s1 = "..." + String(s1[s1.index(s1.endIndex, offsetBy: -offset) ..< s1.endIndex])
                }
                attrText.append(NSAttributedString(string: s1, attributes: normalAttributes))
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                match.attrText = attrText
            }
            return match
        }

        let len = mask.rawValue & TokenMask.pinyin.rawValue
        guard count > 0 && len > count else {
            return match
        }

        let pinyins = text.pinyinsForMatch
        for pinyin in pinyins.fulls + pinyins.firsts {
            if let range = pinyin.range(of: kw) {
                if range == pinyin.startIndex ..< pinyin.endIndex {
                    match.type = kw.count == 1 ? .pinyinPrefix : .pinyinFull
                    break
                } else if range.lowerBound == pinyin.startIndex {
                    match.type = .pinyinPrefix
                } else {
                    if match.type != .pinyinPrefix {
                        match.type = .pinyinMiddle
                    }
                }
            } else {
                var pinyinset = Set(pinyin.splitedPinyins)
                let count = pinyinset.count
                pinyinset.subtract(keywordSplitedPinyins)
                if pinyinset.count < count {
                    match.type = .pinyinMiddle
                }
            }
        }

        let tokens = tokenize(decoded.bytes, method, mask)
        var tokenized = Array(repeating: UInt8(0), count: count)

        var k = 0
        for i in 0 ..< keywordTokens.count {
            let pytk = keywordTokens[i]
            for j in k ..< tokens.count {
                let tk = tokens[j]
                if pytk.token != tk.token { continue }
                tokenized.replaceSubrange(Int(tk.start) ..< Int(tk.end), with: tk.token.decoded.bytes)
                k = j
            }
        }

        var start = 0
        var end = 0
        var hl = false
        var flag = -1

        let block = {
            let sub = String(bytes: bytes[start ..< end], encoding: decoded.encoding) ?? ""
            if flag == 1 && !hl {
                hl = true
                let loc = attrText.length
                let len = sub.count
                let lower = source.index(source.startIndex, offsetBy: loc)
                let upper = source.index(source.startIndex, offsetBy: loc + len)
                match.range = lower ..< upper
                if loc + len > self.attrTextMaxLen {
                    let rem = max(0, self.attrTextMaxLen - len)
                    attrText.deleteCharacters(in: NSMakeRange(loc - rem, rem))
                    attrText.insert(NSAttributedString(string: "..."), at: 0)
                }
            }
            let attrs = flag == 1 ? self.highlightAttributes : self.normalAttributes
            let subAttrText = NSAttributedString(string: sub, attributes: attrs)
            attrText.append(subAttrText)
            start = end
        }

        while end < count {
            let newflag = tokenized[end] == 0 ? 0 : 1
            if newflag != flag && end > start { block() }
            flag = newflag
            end += 1
        }
        if end > start { block() }
        if match.type == .none && hl {
            match.type = .other
        }
        match.attrText = attrText
        return match
    }

    public func highlight(_ sources: [String]) -> [Match?] {
        return sources.map { highlight($0) }
    }
}
