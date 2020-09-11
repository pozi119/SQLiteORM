//
//  Highlighter.swift
//  SQLiteORM
//
//  Created by Valo on 2019/8/23.
//

public final class Match {
    /// pinyin or original word matching
    ///
    /// - none: no match
    /// - firsts: first letters matching
    /// - full: full pinyin matching
    /// - origin: original matching
    public enum LV1: UInt64 {
        case none = 0, fuzzy, firsts, fulls, origin
    }

    /// range matching
    ///
    /// - none: no match
    /// - other: word token matching
    /// - nonprefix: middle matching
    /// - prefix: prefix matching
    /// - full: full word matching
    public enum LV2: UInt64 {
        case none = 0, other, middle, prefix, full
    }

    /// match priority
    public enum LV3: UInt64 {
        case low = 0, medium, high
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

    public static func <= (lhs: Match, rhs: Match) -> Bool {
        return lhs.weight <= rhs.weight
    }

    public static func > (lhs: Match, rhs: Match) -> Bool {
        return lhs.weight > rhs.weight
    }

    public static func >= (lhs: Match, rhs: Match) -> Bool {
        return lhs.weight < rhs.weight
    }
}

extension Match: CustomStringConvertible {
    public var description: String {
        let range = ranges.first ?? NSRange(location: 0, length: 0)
        return String(format: "[%i|%i|%i|%@|0x%llx]: %@", lv1.rawValue, lv2.rawValue, lv3.rawValue, NSStringFromRange(range), weight, attrText.description.singleLine.strip)
    }
}

extension Highlighter {
    private static let cache = Cache<String, (words: [[Set<String>]], tokens: [[[String: Token]]])>()
    class func arrange(_ source: String, mask: TokenMask) -> (words: [[Set<String>]], tokens: [[[String: Token]]]) {
        let key = "\(mask)" + source
        if let results = cache[key] { return results }
        let tokens = OrmEnumerator.enumerate(source, mask: mask)
        let results = arrange(tokens)
        cache[key] = results
        return results
    }

    class func arrange(_ tokens: [Token]) -> ([[Set<String>]], [[[String: Token]]]) {
        var commons: [Int: Set<Token>] = [:]
        var syllables: [Int: Set<Token>] = [:]
        for tk in tokens {
            if tk.colocated < TOKEN_SYLLABLE {
                var set = commons[tk.start]
                if set == nil { set = Set<Token>() }
                set!.insert(tk)
                commons[tk.start] = set!
            } else {
                var set = syllables[tk.colocated]
                if set == nil { set = Set<Token>() }
                set!.insert(tk)
                syllables[tk.colocated] = set!
            }
        }

        var arrangedWords: [[Set<String>]] = []
        var arrangedTokens: [[[String: Token]]] = []

        // commons
        let commonSorted = commons.values.sorted { ($0.first?.start ?? 0) < ($1.first?.start ?? 0) }
        var commonWords: [Set<String>] = []
        var commonTokens: [[String: Token]] = []

        for subTokens in commonSorted {
            var subWords = Set<String>()
            var dic: [String: Token] = [:]
            for tk in subTokens {
                subWords.insert(tk.word)
                dic[tk.word] = tk
            }
            commonWords.append(subWords)
            commonTokens.append(dic)
        }
        arrangedWords.append(commonWords)
        arrangedTokens.append(commonTokens)

        // syllables
        for (_, values) in syllables {
            var syllableWords: [Set<String>] = []
            var syllableTokens: [[String: Token]] = []
            let subSorted = values.sorted()
            var pos = 0
            for tk in subSorted {
                if pos >= tk.start { continue }
                for i in pos ..< tk.start {
                    let set = commons[i]
                    if set == nil { continue }

                    var subWords = Set<String>()
                    var dic: [String: Token] = [:]
                    for xtk in subSorted {
                        subWords.insert(xtk.word)
                        dic[tk.word] = xtk
                    }
                    syllableWords.append(subWords)
                    syllableTokens.append(dic)
                }
                pos = tk.end
                syllableWords.append(Set([tk.word]))
                syllableTokens.append([tk.word: tk])
            }
        }
        return (arrangedWords, arrangedTokens)
    }
}

public class Highlighter {
    private var _keyword: String = ""
    public var keyword: String {
        set { _keyword = newValue.trim; _kwTokens = nil }
        get { return _keyword }
    }

    public var mask: TokenMask = .default { didSet { _kwTokens = nil } }
    public var fuzzy: Bool = false { didSet { _kwTokens = nil } }
    public var quantity: Int = 0
    public var useSingleLine: Bool = true
    public var enumerator: Enumerator.Type = OrmEnumerator.self
    public var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    public var normalAttributes: [NSAttributedString.Key: Any] = [:]
    public var reserved: Any?

    private var _kwTokens: [[Set<String>]]?
    private var kwTokens: [[Set<String>]] {
        guard _kwTokens == nil else { return _kwTokens! }
        var xmask = mask
        xmask.formUnion(.syllable)
        xmask.subtract(.abbreviation)
        if fuzzy { xmask.formUnion(.pinyin) } else { xmask.subtract(.pinyin) }
        _kwTokens = Highlighter.arrange(_keyword, mask: xmask).words
        return _kwTokens!
    }

    public convenience init<T>(orm: Orm<T>, keyword: String) {
        let config = orm.config as? FtsConfig
        assert(config != nil, "invalid fts orm")

        self.init(keyword: keyword)
        let components = config!.tokenizer.components(separatedBy: " ")
        if components.count > 0 {
            let tokenizer = components[0]
            if let enumerator = orm.db.enumerator(for: tokenizer) {
                self.enumerator = enumerator
            }
        }
        if components.count > 1 {
            let mask = components[1]
            self.mask = .init(rawValue: UInt64(mask) ?? 0)
        }
    }

    public init(keyword: String) {
        assert(keyword.count > 0, "Invalid keyword")
        self.keyword = keyword
    }

    public func highlight(_ source: String) -> Match {
        guard source.count > 0 && keyword.count > 0 else { return Match(source: source) }

        var reference = source.matchingPattern
        var xkeyword = keyword.matchingPattern
        if mask.contains(.transform) {
            reference = reference.simplified
            xkeyword = xkeyword.simplified
        }

        var match = highlight(usingRegex: source, reference: reference, keyword: xkeyword)
        guard match.lv2 == .none else { return match }

        match = highlight(usingToken: source, reference: reference)
        guard match.lv2 == .none else { return match }

        return Match(source: source)
    }

    private func highlight(usingRegex source: String, reference: String, keyword: String) -> Match {
        let match = Match(source: source)

        guard let expression = try? NSRegularExpression(pattern: keyword.regexPattern, options: []) else { return match }

        var results = expression.matches(in: reference, options: [], range: NSRange(location: 0, length: reference.count))
        guard results.count > 0 else { return match }

        if quantity > 0 && results.count > quantity {
            results = Array(results[0 ..< quantity])
        }

        let found = results.first!.range
        switch (found.location, found.length) {
            case (0, reference.count): match.lv2 = .full
            case (0, _): match.lv2 = .prefix
            default: match.lv2 = .middle
        }
        match.lv1 = .origin
        match.lv3 = .high

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

    private func highlight(usingToken source: String, reference: String) -> Match {
        let nomatch = Match(source: source)
        guard kwTokens.count > 0 else { return nomatch }

        let bytes = reference.bytes
        let xmask = fuzzy ? mask.union(.pinyin) : mask
        let arranged = Highlighter.arrange(reference, mask: xmask)
        let arrangedTokens = arranged.tokens
        let arrangedWords = arranged.words
        guard arrangedWords.count > 0 && arrangedTokens.count > 0 else { return nomatch }

        var lv1: Match.LV1 = .origin
        var whole = true
        let text = useSingleLine ? source.singleLine : source
        let attrText = NSMutableAttributedString(string: text, attributes: normalAttributes)
        var ranges: [NSRange] = []

        for kc in 0 ..< kwTokens.count {
            for sc in 0 ..< arrangedWords.count {
                let groupWords = arrangedWords[sc]
                let kwGroupWords = kwTokens[kc]
                for i in 0 ..< groupWords.count {
                    var j = 0, k = i, sloc = -1, slen = -1
                    while j < kwGroupWords.count && k < groupWords.count {
                        let set = groupWords[k]
                        let kwset = kwGroupWords[j]
                        var matchword: String = ""
                        let mset = set.intersection(kwset)
                        if mset.count > 0 {
                            matchword = mset.first!
                        } else if j == kwGroupWords.count - 1 && kc > 0 {
                            for kwword in kwset {
                                for word in set {
                                    if word.hasPrefix(kwword) {
                                        matchword = word; whole = false; break
                                    }
                                }
                                if matchword.count > 0 { break }
                            }
                        }
                        if matchword.count > 0 {
                            let dic = arrangedTokens[sc][k]
                            let tk = dic[matchword]!
                            var tlv1: Match.LV1 = .none
                            switch (kc, sc) {
                                case (0, 0): tlv1 = tk.colocated <= TOKEN_FULLWIDTH ? .origin : .firsts
                                case (_, 0): tlv1 = .fulls
                                default: tlv1 = .fuzzy
                            }
                            if tlv1.rawValue < lv1.rawValue { lv1 = tlv1 }
                            if sloc < 0 { sloc = tk.start }
                            slen = tk.end - sloc
                            j += 1
                            k += 1
                        } else {
                            break
                        }
                    }
                    if j > 0 && j == kwGroupWords.count {
                        let s1 = String(bytes: Array(bytes[0 ..< sloc]))
                        let s2 = String(bytes: Array(bytes[sloc ..< (sloc + slen)]))
                        let range = NSRange(location: s1.count, length: s2.count)
                        attrText.addAttributes(highlightAttributes, range: range)
                        ranges.append(range)
                        if quantity > 0 && ranges.count >= quantity { break }
                    }
                }
                if ranges.count > 0 { break }
            }
            if ranges.count > 0 { break }
        }

        guard ranges.count > 0 else { return nomatch }
        let first = ranges.first!
        let match = Match(source: source, attrText: attrText)
        match.ranges = ranges
        match.lv1 = lv1
        match.lv2 = first.location == 0 ? (first.length == attrText.length && whole ? .full : .prefix) : .middle
        match.lv3 = lv1 == .origin ? .high : lv1 == .fulls ? .medium : .low
        return match
    }

    public func highlight(_ sources: [String]) -> [Match] {
        return sources.map { highlight($0) }
    }

    public func trim(matched text: NSAttributedString, maxLength: Int) -> NSAttributedString {
        return text.trim(to: maxLength, with: highlightAttributes)
    }
}
