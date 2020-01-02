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
    public var range: Range<Int> = 0 ..< 0
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
        let tokens = tokenize(self.keyword.bytes, self.method, .init(rawValue: mask))
        return tokens.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
    }()

    private lazy var keywordSplitedPinyins = self.keyword.splitedPinyins

    public convenience init<T: Codable>(orm: Orm<T>, keyword: String, highlightAttributes: [NSAttributedString.Key: Any]) {
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

    public func highlight(_ source: String) -> Match {
        let clean = source.replacingOccurrences(of: "\n", with: " ")
        var text = clean.lowercased()
        var kw = keyword.lowercased()
        if mask.contains(.transform) {
            text = text.simplified
            kw = kw.simplified
        }

        var match = Match(source: source, attrText: NSAttributedString(string: source))
        let bytes = text.bytes
        let cleanbytes = clean.bytes
        let count = bytes.count
        let attrText = NSMutableAttributedString()

        let TrimAttrText = { (r: Range<String.Index>) -> Void in
            let lower = r.lowerBound.utf16Offset(in: clean)
            let upper = r.upperBound.utf16Offset(in: clean)
            if upper > self.attrTextMaxLen && upper <= attrText.length{
                let dlen = min(lower, upper - self.attrTextMaxLen)
                attrText.deleteCharacters(in: NSMakeRange(0, dlen))
                attrText.insert(NSAttributedString(string: "..."), at: 0)
            }
        }

        if let range = text.range(of: kw) {
            if range == text.startIndex ..< text.endIndex {
                match.type = .full
                match.attrText = NSAttributedString(string: source, attributes: highlightAttributes)
                match.range = 0 ..< bytes.count
            } else if range.lowerBound == text.startIndex {
                match.type = .prefix
                let sk = String(clean[range])
                let s2 = String(clean[range.upperBound ..< clean.endIndex])
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                match.attrText = attrText
                match.range = 0 ..< sk.bytes.count
            } else {
                match.type = .middle
                let s1 = String(clean[clean.startIndex ..< range.lowerBound])
                let sk = String(clean[range])
                let s2 = String(clean[range.upperBound ..< clean.endIndex])
                attrText.append(NSAttributedString(string: s1, attributes: normalAttributes))
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                TrimAttrText(range)
                match.attrText = attrText
                let loc = s1.bytes.count
                let len = sk.bytes.count
                match.range = loc ..< (loc + len)
            }
            return match
        }

        guard match.type == .none else {
            return match
        }

        let len = mask.rawValue & TokenMask.pinyin.rawValue
        if count > 0 && len > count {
            let pinyins = text.pinyinsForMatch
            for pinyin in pinyins.firsts {
                if let range = pinyin.range(of: kw) {
                    if range == pinyin.startIndex ..< pinyin.endIndex {
                        match.type = .pinyinFull
                        break
                    } else if range.lowerBound == pinyin.startIndex {
                        match.type = .pinyinPrefix
                    } else {
                        if match.type == .none {
                            match.type = .pinyinMiddle
                        }
                    }
                }
            }
            if match.type == .none {
                for pinyin in pinyins.fulls {
                    if let range = pinyin.range(of: kw) {
                        if range == pinyin.startIndex ..< pinyin.endIndex {
                            match.type = .pinyinFull
                            break
                        } else if range.lowerBound == pinyin.startIndex {
                            match.type = .pinyinPrefix
                        } else {
                            if match.type == .none {
                                match.type = .pinyinMiddle
                            }
                        }
                    }
                }
            }
        }

        let tokens = tokenize(bytes, method, mask).sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        var tokenized = Array(repeating: UInt8(0), count: count)

        var k = 0
        for i in 0 ..< keywordTokens.count {
            let pytk = keywordTokens[i]
            for j in k ..< tokens.count {
                let tk = tokens[j]
                if pytk.token != tk.token { continue }
                let r = Int(tk.start) ..< Int(tk.end)
                tokenized[r].replaceSubrange(r, with: cleanbytes[r])
                k = j
                break
            }
        }

        var start = 0
        var end = 0
        var flag = -1
        var r: Range<String.Index>?

        while end <= count {
            let newflag = end == count ? -1 : tokenized[end] == 0 ? 0 : 1
            if newflag != flag && end > start {
                let sub = String(bytes: bytes[start ..< end], encoding: .utf8) ?? ""
                if flag == 1 && r == nil {
                    let loc = attrText.length
                    let len = sub.count
                    let lower = clean.index(clean.startIndex, offsetBy: loc)
                    let upper = clean.index(clean.startIndex, offsetBy: loc + len)
                    r = lower ..< upper
                }
                let attrs = flag == 1 ? highlightAttributes : normalAttributes
                let subAttrText = NSAttributedString(string: sub, attributes: attrs)
                attrText.append(subAttrText)
                start = end
            }
            flag = newflag
            end += 1
        }
        if let range = r {
            let s1 = String(clean[clean.startIndex ..< range.lowerBound])
            let sk = String(clean[range])
            let pos = s1.bytes.count
            let len = sk.bytes.count
            match.range = pos ..< (pos + len)
            TrimAttrText(range)
            match.attrText = attrText
            if match.type == .none{
                match.type = .other
            }
        }
        return match
    }

    public func highlight(_ sources: [String]) -> [Match] {
        return sources.map { highlight($0) }
    }
}
