//
//  Highlighter.swift
//  SQLiteORM
//
//  Created by Valo on 2019/8/23.
//

public final class Match {
    public enum LV1: UInt64 {
        case none = 0, firsts, full, origin
    }

    public enum LV2: UInt64 {
        case none = 0, other, nonprefix, prefix, full
    }

    public enum LV3: UInt64 {
        case low = 0, medium, high
    }

    public struct Option: OptionSet {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let pinyin = Option(rawValue: 1 << 0)
        public static let fuzzy = Option(rawValue: 1 << 1)
        public static let token = Option(rawValue: 1 << 2)

        public static let `default`: Option = .pinyin
        public static let all: Option = .init(rawValue: 0xFFFFFFFF)
    }

    public var lv1: LV1 = .none
    public var lv2: LV2 = .none
    public var lv3: LV3 = .low

    public var range = 0 ..< 0
    public var source: String
    public var attrText: NSAttributedString

    public lazy var upperWeight: UInt64 = {
        let _lv1 = lv1.rawValue, _lv2 = lv2.rawValue, _lv3 = lv3.rawValue
        return ((_lv1 & 0xF) << 24) | ((_lv2 & 0xF) << 20) | ((_lv3 & 0xF) << 16)
    }()

    public lazy var lowerWeight: UInt64 = {
        let loc: UInt64 = ~UInt64(range.lowerBound) & 0xFFFF
        let rate: UInt64 = UInt64(range.upperBound - range.lowerBound) << 32 / UInt64(source.count)
        return ((loc & 0xFFFF) << 16) | ((rate & 0xFFFF) << 0)
    }()

    public lazy var weight: UInt64 = self.upperWeight << 32 | self.lowerWeight

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

extension Match: CustomStringConvertible {
    public var description: String {
        return "[\(lv1)|\(lv2)|\(lv3)|\(range)|" + String(format: "0x%llx", weight) + "]: " + attrText.description.replacingOccurrences(of: "\n", with: " ").strip
    }
}

public class Highlighter {
    public var keyword: String
    public var option: Match.Option = .default
    public var method: TokenMethod = .sqliteorm
    public var mask: TokenMask = .default
    public var attrTextMaxLen: Int = 17
    public var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    public var normalAttributes: [NSAttributedString.Key: Any] = [:]

    private lazy var keywordTokens: [Token] = {
        assert(self.keyword.count > 0, "invalid keyword")
        var mask = self.mask
        if mask.pinyin > 0 {
            mask.subtract(.allPinYin)
            mask.formUnion(.syllable)
        }
        let tokens = tokenize(self.keyword.bytes, self.method, mask)
        return tokens
    }()

    private lazy var keywordPinyin: String = {
        guard self.keyword.count <= 30 else { return "" }
        var kw = self.keyword.lowercased()
        if self.mask.contains(.transform) {
            kw = kw.simplified
        }
        return kw.pinyins.fulls.first ?? ""
    }()

    public convenience init<T: Codable>(orm: Orm<T>, keyword: String) {
        let config = orm.config as? FtsConfig
        assert(config != nil, "invalid fts orm")

        self.init(keyword: keyword)
        option = [.pinyin, .token]
        let components = config!.tokenizer.components(separatedBy: " ")
        if components.count > 0 {
            let tokenizer = components[0]
            let method = orm.db.enumerator(for: tokenizer)
            self.method = method
        }
        if components.count > 1 {
            let mask = components[1]
            self.mask = .init(rawValue: UInt32(mask) ?? 0)
        }
    }

    public init(keyword: String) {
        assert(keyword.count > 0, "Invalid keyword")
        self.keyword = keyword.trim
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
        guard match.upperWeight == 0 && option.contains([.pinyin, .fuzzy]) && keywordPinyin.count > 0 else { return match }
        match = highlight(source, keyword: kw, lv1: .full, clean: clean, text: text, bytes: bytes, cleanbytes: cleanbytes)
        return match
    }

    private func highlight(text: String, range: Range<String.Index>) -> NSAttributedString {
        let attrText = NSMutableAttributedString()
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        let len = upper - lower
        let maxLen = attrTextMaxLen
        let s1 = String(text[text.startIndex ..< range.lowerBound])
        let sk = String(text[range])
        let s2 = String(text[range.upperBound ..< text.endIndex])
        let a1 = NSAttributedString(string: s1, attributes: normalAttributes)
        let ak = NSAttributedString(string: sk, attributes: highlightAttributes)
        let a2 = NSAttributedString(string: s2, attributes: normalAttributes)
        attrText.append(a1)
        attrText.append(ak)
        attrText.append(a2)
        if upper > maxLen && lower > 2 {
            let rlen = (2 + len > maxLen) ? (lower - 2) : (upper - maxLen)
            attrText.deleteCharacters(in: NSRange(location: 0, length: rlen))
            let ellipsis = NSAttributedString(string: "...")
            attrText.insert(ellipsis, at: 0)
        }
        return attrText
    }

    private func highlight(_ source: String, keyword: String, lv1: Match.LV1, clean: String, text: String, bytes: [UInt8], cleanbytes: [UInt8]) -> Match {
        let nomatch = Match(source: source, attrText: NSAttributedString(string: clean, attributes: normalAttributes))

        let match = Match(source: source)
        match.lv1 = lv1
        let count = bytes.count

        let hasSpace = keyword.range(of: " ") != nil
        let exp = hasSpace ? keyword.replacingOccurrences(of: " +", with: " +", options: .regularExpression) : keyword

        if let range = text.range(of: exp) {
            let lower = text.distance(from: text.startIndex, to: range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: range.upperBound)
            switch (range.lowerBound, range.upperBound) {
            case (text.startIndex, text.endIndex): match.lv2 = .full
            case (text.startIndex, _): match.lv2 = .prefix
            default: match.lv2 = .nonprefix
            }
            match.lv3 = lv1 == .origin ? .high : .medium
            match.range = lower ..< upper
            match.attrText = highlight(text: text, range: range)
            return match
        }

        if option.contains(.pinyin) {
            let matrix = text.pinyinMatrix
            let matrixes: [[[String]]] = [lv1 == .origin ? matrix.fulls : [], matrix.abbrs]
            for i in 0 ..< matrixes.count {
                for pinyins in matrixes[i] {
                    let pinyin = pinyins.joined()
                    if let range = pinyin.range(of: exp) {
                        var lv2: Match.LV2 = .none
                        switch (range.lowerBound, range.upperBound) {
                        case (pinyin.startIndex, pinyin.endIndex): lv2 = keyword.count == 1 ? .prefix : .full
                        case (pinyin.startIndex, _): lv2 = .prefix
                        default: lv2 = .nonprefix
                        }
                        let lower = pinyin.distance(from: pinyin.startIndex, to: range.lowerBound)
                        let upper = pinyin.distance(from: pinyin.startIndex, to: range.upperBound)
                        let len = upper - lower
                        if lv2.rawValue > match.lv2.rawValue || (lv2.rawValue == match.lv2.rawValue && (lower < match.range.lowerBound || i == 1)) {
                            var offset = 0, idx = 0
                            while offset < lower && idx < pinyins.count {
                                let s = pinyins[idx]
                                offset += s.count
                                idx += 1
                            }
                            var valid = offset == lower

                            if valid {
                                idx = idx >= pinyins.count ? pinyins.count - 1 : idx
                                var hloc = idx, mlen = 0
                                while mlen < len && idx < pinyins.count {
                                    let s = pinyins[idx]
                                    mlen += s.count
                                    idx += 1
                                }
                                valid = mlen == len
                                if valid {
                                    let hlen = idx - hloc
                                    let lowerBound = text.index(text.startIndex, offsetBy: hloc)
                                    let upperBound = text.index(lowerBound, offsetBy: hlen)

                                    match.lv2 = lv2
                                    match.range = lower ..< upper
                                    match.lv3 = i == 1 ? .medium : .low
                                    match.attrText = highlight(text: text, range: lowerBound ..< upperBound)
                                }
                            }
                        }
                    }
                    if match.lv2 == .full { break }
                }
                if match.lv2 == .full { break }
            }
        }
        if match.lv2 != .none {
            return match
        }

        guard option.contains([.token]) else {
            return nomatch
        }

        var _mask = mask
        if _mask.pinyin > 0 {
            _mask.subtract(.syllable)
        }
        let tokens = tokenize(bytes, method, _mask)
        var tokenized = Array(repeating: UInt8(0), count: count + 1)

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

        var start = -1, end = 0
        for i in 0 ... count {
            let flag = tokenized[i] == 0x0 ? 0 : 1
            if start < 0 && flag == 1 {
                start = i
            } else if start >= 0 && flag == 0 {
                end = i
                break
            }
        }
        if end > 0 {
            let s1 = String(bytes: cleanbytes[0 ..< start], encoding: .utf8) ?? ""
            let sk = String(bytes: cleanbytes[start ..< end], encoding: .utf8) ?? ""
            let lower = clean.index(clean.startIndex, offsetBy: s1.count)
            let upper = clean.index(clean.startIndex, offsetBy: s1.count + sk.count)
            match.attrText = highlight(text: clean, range: lower ..< upper)
            match.range = start ..< end
            if match.lv2 == .none {
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
