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

        public static let `default` = Option(rawValue: 0 << 0)
        public static let pinyin = Option(rawValue: 1 << 0)
        public static let fuzzy = Option(rawValue: 1 << 1)
        public static let token = Option(rawValue: 1 << 2)

        public static let all: Option = .init(rawValue: 0xFFFFFFFF)
    }

    public var lv1: LV1 = .none
    public var lv2: LV2 = .none
    public var lv3: LV3 = .low

    public var ranges: [NSRange] = []
    public var source: String
    public var attrText: NSAttributedString

    public lazy var upperWeight: UInt64 = {
        let _lv1 = lv1.rawValue, _lv2 = lv2.rawValue, _lv3 = lv3.rawValue
        return ((_lv1 & 0xF) << 24) | ((_lv2 & 0xF) << 20) | ((_lv3 & 0xF) << 16)
    }()

    public lazy var lowerWeight: UInt64 = {
        let range = ranges.first ?? NSRange(location: 0, length: 0)
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
        let range = ranges.first ?? NSRange(location: 0, length: 0)
        return "[\(lv1)|\(lv2)|\(lv3)|\(range)|" + String(format: "0x%llx", weight) + "]: " + attrText.description.replacingOccurrences(of: "\n", with: "").strip
    }
}

public class Highlighter {
    private var _keyword: String = ""
    public var keyword: String {
        set { _keyword = newValue.trim; refresh() }
        get { return _keyword }
    }

    public var option: Match.Option = .default
    public var method: TokenMethod = .sqliteorm
    public var mask: TokenMask = .default { didSet { refresh() } }
    public var quantity: Int = 0
    public var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    public var normalAttributes: [NSAttributedString.Key: Any] = [:]

    private var keywordTokens: [Token] = []
    private var kwFullPinyin: String = ""

    public convenience init<T: Codable>(orm: Orm<T>, keyword: String) {
        let config = orm.config as? FtsConfig
        assert(config != nil, "invalid fts orm")

        self.init(keyword: keyword)
        option = [.token]
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
        self.keyword = keyword
    }

    private func refresh() {
        var mask = self.mask
        if mask.pinyin > 0 {
            mask.subtract(.allPinYin)
            mask.formUnion(.syllable)
        }
        let tokens = tokenize(_keyword.bytes, method, mask)
        keywordTokens = tokens

        kwFullPinyin = ""
        if keyword.count <= 30 {
            var kw = keyword.lowercased()
            if self.mask.contains(.transform) {
                kw = kw.simplified
            }
            kwFullPinyin = kw.pinyins.fulls.first ?? ""
        }
    }

    public func highlight(_ source: String) -> Match {
        guard source.count > 0 && keyword.count > 0 else { return Match(source: source) }

        let clean = source.matchingPattern
        var text = clean
        var kw = keyword.lowercased()
        if mask.contains(.transform) {
            text = text.simplified
            kw = kw.simplified
        }
        let bytes = text.bytes
        let match = highlight(source, comparison: text, bytes: bytes, keyword: kw, lv1: .origin)
        return match
    }

    private func highlight(usingRegex source: String, comparison: String, keyword: String, lv1: Match.LV1) -> Match {
        let match = Match(source: source)
        match.lv1 = lv1

        guard let expression = try? NSRegularExpression(pattern: keyword.regexPattern, options: []) else {
            return Match(source: source)
        }

        var results = expression.matches(in: comparison, options: [], range: NSRange(location: 0, length: comparison.count))
        guard results.count > 0 else {
            return Match(source: source)
        }

        if quantity > 0 && results.count > quantity {
            results = Array(results[0 ..< quantity])
        }

        let found = results.first!.range
        switch (found.location, found.length) {
        case (0, comparison.count): match.lv2 = .full
        case (0, _): match.lv2 = .prefix
        default: match.lv2 = .nonprefix
        }
        match.lv3 = lv1 == .origin ? .high : .medium

        var ranges: [NSRange] = []
        let attrText = NSMutableAttributedString(string: source, attributes: normalAttributes)
        for result in results {
            attrText.addAttributes(highlightAttributes, range: result.range)
            ranges.append(result.range)
        }
        match.attrText = attrText
        match.ranges = ranges
        return match
    }

    private func highlight(usingPinyin source: String, comparison: String, keyword: String, lv1: Match.LV1) -> Match {
        let match = Match(source: source)
        match.lv1 = lv1

        guard let expression = try? NSRegularExpression(pattern: keyword.regexPattern, options: []) else {
            return Match(source: source)
        }

        var ranges: Set<NSRange> = Set()
        let matrix = comparison.pinyinMatrix
        let matrixes: [[[String]]] = [lv1 == .origin ? matrix.fulls : [], matrix.abbrs]
        for i in 0 ..< matrixes.count {
            for pinyins in matrixes[i] {
                let pinyin = pinyins.joined()
                let results = expression.matches(in: pinyin, options: [], range: NSRange(location: 0, length: pinyin.count))
                if results.count == 0 { continue }

                let range = results.first!.range
                var lv2: Match.LV2 = .none
                switch (range.lowerBound, range.upperBound) {
                case (0, pinyin.count): lv2 = keyword.count == 1 ? .prefix : .full
                case (0, _): lv2 = .prefix
                default: lv2 = .nonprefix
                }
                if match.lv2.rawValue < lv2.rawValue { match.lv2 = lv2 }

                for result in results {
                    let r = result.range
                    let len = r.length
                    var offset = 0, idx = 0
                    while offset < r.lowerBound && idx < pinyins.count {
                        let s = pinyins[idx]
                        offset += s.count
                        idx += 1
                    }

                    idx = idx >= pinyins.count ? pinyins.count - 1 : idx
                    var hloc = idx, mlen = 0
                    while mlen < len && idx < pinyins.count {
                        let s = pinyins[idx]
                        mlen += s.count
                        idx += 1
                    }

                    ranges.insert(NSRange(location: hloc, length: idx - hloc))
                }
            }
        }

        guard ranges.count > 0 else {
            return Match(source: source)
        }

        var sortedRanges = ranges.sorted { $0.location < $1.location || ($0.location == $1.location && $0.length > $1.length) }
        if quantity > 0 && sortedRanges.count > quantity {
            sortedRanges = Array(sortedRanges[0 ..< quantity])
        }

        let attrText = NSMutableAttributedString(string: source, attributes: normalAttributes)
        sortedRanges.forEach { attrText.addAttributes(highlightAttributes, range: $0) }

        let lv3decision = keyword.count > 1 && comparison.hasPrefix(keyword)
        match.lv3 = lv3decision ? .medium : .low
        match.ranges = sortedRanges
        match.attrText = attrText
        return match
    }

    private func highlight(usingToken source: String, bytes: [UInt8], keyword: String, lv1: Match.LV1) -> Match {
        let nomatch = Match(source: source)
        guard keywordTokens.count > 0 else { return nomatch }

        let mask = self.mask.subtracting(.syllable)
        let sourceTokens = tokenize(bytes, method, mask)
        guard sourceTokens.count > 0 else { return nomatch }

        var tokenmap: [String: NSMutableSet] = [:]
        for token in sourceTokens {
            var set = tokenmap[token.token]
            if set == nil {
                set = NSMutableSet()
                tokenmap[token.token] = set
            }
            set!.add(token)
        }
        var kwtks = Set<String>()
        for token in keywordTokens {
            kwtks.insert(token.token)
        }

        var matchedSet = Set<Token>()
        for tk in kwtks {
            if let set = tokenmap[tk] as? Set<Token> {
                matchedSet.formUnion(set)
            }
        }
        guard matchedSet.count > 0 else { return nomatch }

        var array = matchedSet.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        if quantity > 0 && array.count > quantity {
            array = Array(array[0 ..< quantity])
        }

        let match = Match(source: source)
        match.lv1 = lv1

        let attrText = NSMutableAttributedString(string: source, attributes: normalAttributes)
        var ranges: [NSRange] = []
        for token in array {
            let sub1 = [UInt8](bytes[0 ..< Int(token.start)])
            let sub2 = [UInt8](bytes[Int(token.start) ..< Int(token.end)])
            let s1 = String(bytes: sub1)
            let sk = String(bytes: sub2)
            let range = NSRange(location: s1.count, length: sk.count)
            ranges.append(range)
            attrText.addAttributes(highlightAttributes, range: range)
        }
        match.attrText = attrText
        match.ranges = ranges
        match.lv2 = .other
        match.lv3 = .low
        return match
    }

    private func highlight(_ source: String, comparison: String, bytes: [UInt8], keyword: String, lv1: Match.LV1) -> Match {
        var match = highlight(usingRegex: source, comparison: comparison, keyword: keyword, lv1: lv1)
        guard match.lv2 == .none else { return match }

        if option.contains(.pinyin) {
            match = highlight(usingPinyin: source, comparison: comparison, keyword: keyword, lv1: lv1)
        }
        guard match.lv2 == .none else { return match }

        if option.contains(.token) {
            match = highlight(usingToken: source, bytes: bytes, keyword: keyword, lv1: lv1)
        }
        guard match.lv2 == .none else { return match }

        if option.contains(.fuzzy) && keyword != kwFullPinyin {
            match = highlight(source, comparison: comparison, bytes: bytes, keyword: kwFullPinyin, lv1: .full)
        }

        return match
    }

    public func highlight(_ sources: [String]) -> [Match] {
        return sources.map { highlight($0) }
    }

    public func trim(matched text: NSAttributedString, maxLength: Int) -> NSAttributedString {
        return text.trim(to: maxLength, with: highlightAttributes)
    }
}
