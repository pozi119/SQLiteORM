//
//  Highlighter.swift
//  SQLiteORM
//
//  Created by Valo on 2019/8/23.
//

public final class Match {
    fileprivate enum LV1: UInt64 {
        case none = 0, firsts, full, origin
    }

    fileprivate enum LV2: UInt64 {
        case none = 0, other, nonprefix, prefix, full
    }

    fileprivate enum LV3: UInt64 {
        case low = 0, mid, high
    }

    fileprivate var lv1: LV1 = .none
    fileprivate var lv2: LV2 = .none
    fileprivate var lv3: LV3 = .low

    public var range = 0 ..< 0
    public var source: String
    public var attrText: NSAttributedString

    public lazy var weight: UInt64 = {
        let loc: UInt64 = 0xFFFF - (UInt64(range.lowerBound) & 0xFFFF)
        let rate: UInt64 = UInt64(range.upperBound - range.lowerBound) * 0xFFFF / UInt64(source.count)
        let _lv1 = lv1.rawValue, _lv2 = lv2.rawValue, _lv3 = lv3.rawValue
        var _weight = ((_lv1 & 0xF) << 56) | ((_lv2 & 0xF) << 52) | ((_lv3 & 0xF) << 48)
        _weight = _weight | ((loc & 0xFFFF) << 16) | ((rate & 0xFFFF) << 0)
        return _weight
    }()

    init(source: String, attrText: NSAttributedString? = nil) {
        self.source = source
        if let text = attrText {
            self.attrText = text
        } else {
            self.attrText = NSAttributedString(string: source)
        }
    }
}

extension Match: Comparable {
    public static func == (lhs: Match, rhs: Match) -> Bool {
        return lhs.weight == rhs.weight
    }

    public static func < (lhs: Match, rhs: Match) -> Bool {
        return lhs.weight < rhs.weight
    }
}

public class Highlighter {
    var keyword: String
    var method: TokenMethod = .sqliteorm
    var mask: TokenMask = .default
    var fuzzyMatch = false
    var tokenMatch = false
    var attrTextMaxLen: Int = 17
    var highlightAttributes: [NSAttributedString.Key: Any]
    var normalAttributes: [NSAttributedString.Key: Any] = [:]

    private lazy var keywordTokens: [Token] = {
        assert(self.keyword.count > 0, "invalid keyword")
        var pylen = self.mask.rawValue & TokenMask.pinyin.rawValue
        pylen = max(pylen, 30)
        let mask = (self.mask.rawValue & (~TokenMask.pinyin.rawValue)) | TokenMask.splitPinyin.rawValue | pylen
        let tokens = tokenize(self.keyword.bytes, self.method, .init(rawValue: mask))
        return tokens
    }()

    private lazy var keywordPinyin: String = {
        ""
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
        guard source.count > 0 else { return Match(source: source) }

        let clean = source.replacingOccurrences(of: "\n", with: " ")
        var text = clean.lowercased()
        var kw = keyword.lowercased()
        if mask.contains(.transform) {
            text = text.simplified
            kw = kw.simplified
        }

        let bytes = text.bytes
        let cleanbytes = clean.bytes

        var match = highlight(source, keyword: kw, lv1: .origin, clean: clean, text: text, bytes: bytes, cleanbytes: cleanbytes)
        guard match.weight == 0 && fuzzyMatch && keywordPinyin.count > 0 else { return match }
        match = highlight(source, keyword: kw, lv1: .full, clean: clean, text: text, bytes: bytes, cleanbytes: cleanbytes)
        return match
    }

    fileprivate func highlight(_ source: String, keyword kw: String, lv1: Match.LV1, clean: String, text: String, bytes: [UInt8], cleanbytes: [UInt8]) -> Match {
        let nomatch = Match(source: source, attrText: NSAttributedString(string: clean, attributes: normalAttributes))

        let match = Match(source: source)
        match.lv1 = lv1
        let count = bytes.count
        let attrText = NSMutableAttributedString()

        let TrimAttrText = { (r: Range<String.Index>) -> Void in
            let lower = r.lowerBound.utf16Offset(in: clean)
            let upper = r.upperBound.utf16Offset(in: clean)
            if upper > self.attrTextMaxLen && upper <= attrText.length {
                let dlen = min(lower, upper - self.attrTextMaxLen)
                attrText.deleteCharacters(in: NSMakeRange(0, dlen))
                attrText.insert(NSAttributedString(string: "..."), at: 0)
            }
        }

        if let range = text.range(of: kw) {
            let lower = text.distance(from: text.startIndex, to: range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: range.upperBound)
            match.range = lower ..< upper
            switch (range.lowerBound, range.upperBound) {
            case (text.startIndex, text.endIndex):
                match.lv2 = .full
                match.attrText = NSAttributedString(string: source, attributes: highlightAttributes)
            case (text.startIndex, _):
                let sk = String(clean[range])
                let s2 = String(clean[range.upperBound ..< clean.endIndex])
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                match.lv2 = .prefix
                match.attrText = attrText
            default:
                let s1 = String(clean[clean.startIndex ..< range.lowerBound])
                let sk = String(clean[range])
                let s2 = String(clean[range.upperBound ..< clean.endIndex])
                attrText.append(NSAttributedString(string: s1, attributes: normalAttributes))
                attrText.append(NSAttributedString(string: sk, attributes: highlightAttributes))
                attrText.append(NSAttributedString(string: s2, attributes: normalAttributes))
                TrimAttrText(range)
                match.lv2 = .nonprefix
                match.attrText = attrText
            }
        }

        guard match.lv2 == .none else {
            match.lv3 = .high
            return match
        }

        let len = mask.rawValue & TokenMask.pinyin.rawValue
        if count > 0 && len > count {
            let pinyins = text.pinyinsForMatch
            let array = [lv1 == .origin ? pinyins.fulls : [], pinyins.firsts]
            for i in 0 ..< array.count {
                for pinyin in array[i] {
                    if let range = pinyin.range(of: kw) {
                        var lv2: Match.LV2 = .none
                        switch (range.lowerBound, range.upperBound) {
                        case (pinyin.startIndex, pinyin.endIndex): lv2 = .full
                        case (pinyin.startIndex, _): lv2 = .prefix
                        default: lv2 = .nonprefix
                        }
                        let lower = pinyin.distance(from: pinyin.startIndex, to: range.lowerBound)
                        if lv2.rawValue > match.lv2.rawValue || (lv2.rawValue == match.lv2.rawValue && lower < match.range.lowerBound) {
                            let upper = pinyin.distance(from: pinyin.startIndex, to: range.upperBound)
                            match.lv2 = lv2
                            match.range = lower ..< upper
                            match.lv3 = i == 1 ? .mid : .low
                        }
                    }
                    if match.lv2 == .full { break }
                }
                if match.lv2 == .full { break }
            }
        }

        guard tokenMatch || match.lv2 != .none else {
            return nomatch
        }

        let tokens = tokenize(bytes, method, mask)
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
        var r: Range<Int>?

        while end <= count {
            let newflag = end == count ? -1 : tokenized[end] == 0 ? 0 : 1
            if newflag != flag && end > start {
                let sub = String(bytes: bytes[start ..< end], encoding: .utf8) ?? ""
                if flag == 1 && r == nil {
                    let loc = attrText.length
                    let len = sub.count
                    r = loc ..< (loc + len)
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
            match.range = range
            let sr = clean.index(clean.startIndex, offsetBy: range.lowerBound) ..< clean.index(clean.startIndex, offsetBy: range.upperBound)
            TrimAttrText(sr)
            match.attrText = attrText
            if match.lv2 == .none && tokenMatch {
                match.lv2 = .other
                match.lv3 = .low
            }
        }
        return match.lv2 == .none ? nomatch : match
    }

    public func highlight(_ sources: [String]) -> [Match] {
        return sources.map { highlight($0) }
    }
}
