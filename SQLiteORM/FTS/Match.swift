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

    init(attrText: NSAttributedString, attributes: [NSAttributedString.Key: Any], keyword: String) {
        source = attrText.string
        self.attrText = attrText
        guard keyword.count > 0 else { return }

        var ranges: [NSRange] = []
        var fs: String?
        var fr: NSRange?
        let attrdic = attributes as NSDictionary
        attrText.enumerateAttributes(in: NSRange(location: 0, length: attrText.length), options: []) { attrs, range, _ in
            let dic = attrs as NSDictionary
            if dic == attrdic {
                ranges.append(range)
                if fs == nil {
                    let lower = source.index(source.startIndex, offsetBy: range.location)
                    let upper = source.index(source.startIndex, offsetBy: range.location + range.length)
                    fs = String(source[lower ..< upper])
                    fr = range
                }
            }
        }
        self.ranges = ranges

        guard ranges.count > 0, let firstString = fs, let fisrtRange = fr else { return }

        // lv1
        let lowerkw = keyword.lowercased()
        let lowerfs = firstString.lowercased()
        let rch = (lowerfs as NSString).character(at: 0)
        let kch = (lowerkw as NSString).character(at: 0)
        if kch == rch {
            lv1 = .origin
        } else if rch >= 0x3000, kch >= 0x3000 {
            let map = PinYin.shared.big52gbMap
            let runi = map[rch] ?? rch
            let kuni = map[kch] ?? kch
            lv1 = runi == kuni ? .origin : .fuzzy
        } else if rch >= 0x3000, kch < 0xC0 {
            let map = PinYin.shared.big52gbMap
            let runi = map[rch] ?? rch
            let pinyins = PinYin.shared.hanzi2pinyins[runi] ?? []
            var isfull = false
            for pinyin in pinyins {
                if (lowerkw.count >= pinyin.count && lowerkw.hasPrefix(pinyin))
                    || (lowerkw.count < pinyin.count && pinyin.hasPrefix(lowerkw)) {
                    isfull = true
                    break
                }
            }
            lv1 = isfull ? .fulls : .firsts
        }

        // lv2
        var lv2: LV2 = fisrtRange.location > 0 ? .middle : (fisrtRange.length == source.count ? .full : .prefix)
        if lv2 == .full, lv1 == .fulls, rch > 0x3000, kch < 0xC0 {
            let ech = (lowerfs as NSString).character(at: lowerkw.count - 1)
            let map = PinYin.shared.big52gbMap
            let euni = map[ech] ?? ech
            let pinyins = PinYin.shared.hanzi2pinyins[euni] ?? []
            let lastkw = String(lowerkw.suffix(1))
            lv2 = .prefix
            for pinyin in pinyins {
                if (lowerkw.count >= pinyin.count && lowerkw.hasSuffix(pinyin)) || pinyin.hasPrefix(lastkw) {
                    lv2 = .full
                    break
                }
            }
        }
        self.lv2 = lv2

        // lv3
        lv3 = (lv1 == .origin) ? .high : (lv1 == .fulls ? .medium : .low)
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
