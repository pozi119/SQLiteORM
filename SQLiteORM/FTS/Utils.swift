//
//  Utils.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Foundation

final class PinYin {
    static let shared: PinYin = PinYin()

    private class func path(of resource: String) -> String {
        let parent = Bundle(for: PinYin.self)
        let bundlePath = parent.path(forResource: "PinYin.bundle", ofType: nil) ?? ""
        let bundle = Bundle(path: bundlePath)
        let path = bundle?.path(forResource: resource, ofType: nil) ?? ""
        return path
    }

    private lazy var transforms: (simplified: String, traditional: String) = {
        let path = PinYin.path(of: "transform.txt")
        let text: String = (try? String(contentsOfFile: path)) ?? ""
        let array = text.split(separator: "\n")
        assert(array.count >= 2 && array[0].count == array[1].count && array[0].count > 0, "Invalid transform file")
        return (String(array[0]), String(array[1]))
    }()

    lazy var cache = Cache<String, (fulls: [String], abbrs: [String])>()

    lazy var pinyins: [String: [String]] = {
        let path = PinYin.path(of: "pinyin.plist")
        var _polyphones = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        return _polyphones
    }()

    lazy var hanzi2pinyins: [unichar: [String]] = {
        let path = PinYin.path(of: "hanzi2pinyin.plist")
        let dic = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        var result: [unichar: [String]] = [:]
        dic.forEach { result[PinYin.strtol($0.key)] = $0.value }
        return result
    }()

    lazy var gb2big5Map: [unichar: unichar] = {
        let simplified = self.transforms.simplified
        let traditional = self.transforms.traditional
        let count = simplified.count
        var map: [unichar: unichar] = [:]
        for i in 0 ..< count {
            let k = (simplified as NSString).character(at: i)
            let v = (traditional as NSString).character(at: i)
            map[k] = v
        }
        return map
    }()

    lazy var big52gbMap: [unichar: unichar] = {
        let simplified = self.transforms.simplified
        let traditional = self.transforms.traditional
        let count = simplified.count
        var map: [unichar: unichar] = [:]
        for i in 0 ..< count {
            let k = (traditional as NSString).character(at: i)
            let v = (simplified as NSString).character(at: i)
            map[k] = v
        }
        return map
    }()

    lazy var trimmingSet: CharacterSet = {
        var charset = CharacterSet()
        charset.formUnion(.whitespacesAndNewlines)
        charset.formUnion(.punctuationCharacters)
        return charset
    }()

    lazy var cleanSet: CharacterSet = {
        var charset = CharacterSet()
        charset.formUnion(.controlCharacters)
        charset.formUnion(.whitespacesAndNewlines)
        charset.formUnion(.nonBaseCharacters)
        charset.formUnion(.punctuationCharacters)
        charset.formUnion(.symbols)
        charset.formUnion(.illegalCharacters)
        return charset
    }()

    lazy var syllables: [String: UInt32] = {
        let path = PinYin.path(of: "syllables.txt")
        let text = (try? String(contentsOfFile: path)) ?? ""
        let array = text.split(separator: "\n").map { String($0) }
        var results: [String: UInt32] = [:]
        for line in array {
            let kv = line.split(separator: ",")
            if kv.count != 2 { continue }
            results[String(kv[0])] = UInt32(kv[1])
        }
        return results
    }()

    lazy var numberFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    class func strtol(_ string: String) -> unichar {
        let bytes = string.utf8.map { UInt8($0) }
        let count = bytes.count
        return (0 ..< count).reduce(unichar(0)) { $0 | (unichar(bytes[$1]) << ((count - $1) * 4)) }
    }
}

public extension String {
    init(bytes: [UInt8]) {
        if let s = String(bytes: bytes, encoding: .utf8) {
            self = s
            return
        }
        if let s = String(bytes: bytes, encoding: .ascii) {
            self = s
            return
        }
        self = ""
    }

    /// has chinese characters
    var hasChinese: Bool {
        let regex = ".*[\\u4e00-\\u9fa5].*"
        let predicate = NSPredicate(format: "SELF MATCHES \(regex)")
        return predicate.evaluate(with: self)
    }

    var bytes: [UInt8] {
        return utf8.map { UInt8($0) }
    }

    var simplified: String {
        var string = ""
        for i in 0 ..< count {
            let s = (self as NSString).character(at: i)
            let v = PinYin.shared.big52gbMap[s] ?? s
            string.append(String(v))
        }
        return string
    }

    var traditional: String {
        var string = ""
        for i in 0 ..< count {
            let s = (self as NSString).character(at: i)
            let v = PinYin.shared.gb2big5Map[s] ?? s
            string.append(String(v))
        }
        return string
    }

//    func transform(_ map: [String: String]) -> String {
//        var string = self
//        let pattern = "[\\u4e00-\\u9fa5]+"
//        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
//        regex?.enumerateMatches(in: self, options: .reportCompletion, range: NSRange(location: 0, length: count), using: { result, _, _ in
//            guard let r = result, r.resultType == .regularExpression else { return }
//            let lower = self.index(self.startIndex, offsetBy: r.range.location)
//            let upper = self.index(lower, offsetBy: r.range.length)
//            var fragment = ""
//            for i in 0 ..< r.range.length {
//                let ch = String(self[self.index(self.startIndex, offsetBy: r.range.location + i)])
//                let trans = PinYin.shared.big52gbMap[ch] ?? ch
//                fragment.append(trans)
//            }
//            string.replaceSubrange(lower ..< upper, with: fragment)
//        })
//        return string
//    }

    var pinyin: String {
        let source = NSMutableString(string: self) as CFMutableString
        CFStringTransform(source, nil, kCFStringTransformToLatin, false)
        var dest = (source as NSMutableString) as String
        dest = dest.folding(options: .diacriticInsensitive, locale: .current)
        return dest.replacingOccurrences(of: "'", with: "")
    }

    func pinyins(at index: Int) -> (fulls: [String], abbrs: [String]) {
        guard count > index else { return ([], []) }
        let string = simplified as NSString
        let ch = string.character(at: index)
        if ch < 0x4E00 || ch > 0x9FA5 {
            return ([String(ch)], [String(ch)])
        }
        let key = PinYin.shared.big52gbMap[ch] ?? ch
        let pinyins = PinYin.shared.hanzi2pinyins[key] ?? []
        let fulls = NSMutableOrderedSet()
        let abbrs = NSMutableOrderedSet()
        for pinyin in pinyins {
            if pinyin.count < 1 { continue }
            let full = String(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: pinyin.count - 1)])
            let abbr = String(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: 1)])
            fulls.add(full)
            abbrs.add(abbr)
        }
        return (fulls.array as! [String], abbrs.array as! [String])
    }

    var pinyins: (fulls: [String], abbrs: [String]) {
        guard count > 0 else { return ([], []) }
        if let results = PinYin.shared.cache[self] {
            return results
        }
        let matrix = pinyinMatrix
        let fulls = matrix.fulls.map { $0.joined(separator: "") }
        let abbrs = matrix.abbrs.map { $0.joined(separator: "") }
        let results = (fulls, abbrs)
        PinYin.shared.cache[self] = results
        return results
    }

    var pinyinMatrix: (fulls: [[String]], abbrs: [[String]]) {
        return pinyinMatrix(16)
    }

    func pinyinMatrix(_ limit: Int) -> (fulls: [[String]], abbrs: [[String]]) {
        guard count > 0 else {
            return ([[self]], [[self]])
        }
        var fulls: [[String]] = []
        var abbrs: [[String]] = []
        for i in 0 ..< count {
            let item = pinyins(at: i)
            fulls.append(item.fulls)
            abbrs.append(item.abbrs)
        }
        let rfulls = fulls.tiled(limit)
        let rabbrs = abbrs.tiled(limit)

        return (rfulls, rabbrs)
    }

    private static var tokenFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }

    var cleanNumberString: String {
        let num = String.tokenFormatter.number(from: self)
        return num?.stringValue ?? ""
    }

    var clean: String {
        let array = components(separatedBy: PinYin.shared.cleanSet)
        return array.joined(separator: "")
    }

    var singleLine: String {
        return replacingOccurrences(of: "\\s| ", with: " ", options: .regularExpression, range: startIndex ..< endIndex)
    }

    var matchingPattern: String {
        guard count > 0 else { return self }
        let string = (lowercased() as NSString).mutableCopy() as! NSMutableString
        CFStringTransform(string as CFMutableString, nil, kCFStringTransformFullwidthHalfwidth, false)
        _ = string.replaceOccurrences(of: "\\s| ", with: " ", options: .regularExpression, range: NSRange(location: 0, length: string.length))
        return string as String
    }

    var regexPattern: String {
        var result = matchingPattern
        let pattern = "\\.|\\^|\\$|\\\\|\\[|\\]|\\(|\\)|\\||\\{|\\}|\\*|\\+|\\?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return result
        }
        let array = regex.matches(in: result, options: [], range: NSRange(location: 0, length: count)).reversed()
        for r in array {
            result.insert("\\", at: result.index(result.startIndex, offsetBy: r.range.location))
        }
        result = result.replacingOccurrences(of: " +", with: " +", options: .regularExpression)
        return result
    }

    var fts5KeywordPattern: String {
        var array: [unichar] = []
        let string = self as NSString
        for i in 0 ..< count {
            var ch = string.character(at: i)
            switch ch {
                case 0x21 ... 0x7E: ch += 0xFEE0
                case 0xA2: ch = 0xFFE0
                case 0xA3: ch = 0xFFE1
                case 0xAC: ch = 0xFFE2
                case 0xAF: ch = 0xFFE3
                case 0xA6: ch = 0xFFE4
                case 0xA5: ch = 0xFFE5
                default: break
            }
            array.append(ch)
        }
        let r = NSString(characters: &array, length: count)
        return r as String
    }

    var fastPinyinSegmentation: [String] {
        return Segmentor.segment(self)
    }

    var pinyinSegmentation: [[String]] {
        return lowercased()._pinyinSegmentation
    }

    private var headPinyins: [String] {
        let bytes = self.bytes
        guard bytes.count > 0 else { return [] }
        let s = String(self.first!)
        guard let array = PinYin.shared.pinyins[s], array.count > 0 else { return [] }
        var results: [String] = []
        var spare = false
        for pinyin in array {
            let subbytes = pinyin.bytes
            if bytes.count >= subbytes.count {
                if Array(bytes[0 ..< subbytes.count]) == subbytes { results.append(pinyin) }
            } else {
                if Array(subbytes[0 ..< bytes.count]) == bytes { spare = true }
            }
        }
        if results.count == 0 && spare { results.append(self) }
        return results
    }

    private var _pinyinSegmentation: [[String]] {
        var results: [[String]] = []
        let heads = headPinyins
        guard heads.count > 0 else { return [] }

        for head in heads {
            if head.count == count {
                results.append([self])
                continue
            }
            let tail = String(self[index(startIndex, offsetBy: head.count) ..< endIndex])
            let tails = tail._pinyinSegmentation
            for pinyins in tails {
                results.append([head] + pinyins)
            }
        }
        return results
    }

    /// preload pinyin resouces
    static func preloadingForPinyin() {
        _ = "中文".pinyins
    }
}

public extension NSAttributedString {
    func trim(to maxLen: Int, with attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard length > maxLen else { return copy() as! NSAttributedString }
        let attributes = attrs as NSDictionary

        var first: NSRange = NSRange()
        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { sAttrs, range, stop in
            let tAttrs = sAttrs as NSDictionary
            if tAttrs == attributes {
                first = range
                stop.assign(repeating: true, count: 1)
            }
        }

        let attrText = mutableCopy() as! NSMutableAttributedString
        let lower = first.location
        let upper = first.upperBound
        let len = first.length

        if upper > maxLen && lower > 2 {
            var rlen = (2 + len > maxLen) ? (lower - 2) : (upper - maxLen)
            let ch = (attrText.string as NSString).character(at: rlen - 1)
            if 0xD800 <= ch && ch <= 0xDBFF { rlen += 1 }
            attrText.deleteCharacters(in: NSRange(location: 0, length: rlen))
            let ellipsis = NSAttributedString(string: "...")
            attrText.insert(ellipsis, at: 0)
        }

        return attrText
    }
}

public extension Array where Element == [String] {
    var maxTiledCount: Int { return reduce(1) { $0 * $1.count } }

    var tiled: [[String]] { return tiled(16) }

    func tiled(_ limit: Int) -> [[String]] {
        let max = maxTiledCount
        guard max > 0, max < 256 else {
            return [map { $0.first ?? "" }]
        }
        let tiledCount = Swift.min(max, limit)
        var dim = [String](repeating: "", count: tiledCount * count)

        var rowRepeat = max
        var secRepeat = 1
        for col in 0 ..< count {
            let sub = self[col]
            rowRepeat = rowRepeat / sub.count
            let sec = max / secRepeat
            for j in 0 ..< sub.count {
                let str = sub[j]
                for k in 0 ..< secRepeat {
                    for l in 0 ..< rowRepeat {
                        let row = k * sec + j * rowRepeat + l
                        if row >= tiledCount { continue }
                        dim[row * count + col] = str
                    }
                }
            }
            secRepeat = secRepeat * sub.count
        }
        return (0 ..< tiledCount).map { [String](dim[($0 * count) ..< ($0 * count + count)]) }
    }
}

struct Segmentor {
    // MARK: - Trie

    private class Trie {
        var frequency: UInt32 = 0
        var next: Bool = false
        var ch: UInt8 = 0
        var childs: [UInt8: Trie] = [:]
    }

    private typealias Phone = (pinyin: String, frequency: UInt32)

    private static let root: Trie = {
        var trie = Trie()
        for (pinyin, frequency) in PinYin.shared.syllables {
            let bytes: [UInt8] = pinyin.utf8.map { UInt8($0) }
            Segmentor.add(pinyin: bytes, frequency: frequency, to: trie)
        }
        return trie
    }()

    private static func add(char ch: UInt8, frequency: UInt32, to node: Trie) {
        guard ch >= 97 && ch <= 123 else { return }
        node.next = true
        var next = node.childs[ch]
        if next == nil {
            next = Trie()
            node.childs[ch] = next
        }
        next!.ch = ch
        if frequency > next!.frequency {
            next!.frequency = frequency
        }
    }

    private static func add(pinyin: [UInt8], frequency: UInt32, to root: Trie) {
        var node = root
        for i in 0 ..< pinyin.count {
            let ch = pinyin[i]
            guard ch >= 97 || ch <= 123 else { break }
            let freq = i == pinyin.count - 1 ? frequency : 0
            add(char: ch, frequency: freq, to: node)
            guard let n = node.childs[ch] else { break }
            node = n
        }
    }

    private static func retrieve(_ pinyin: [UInt8]) -> [Phone] {
        var results: [Phone] = []
        var node = Segmentor.root
        let last = pinyin.count - 1
        for i in 0 ..< pinyin.count {
            let ch = pinyin[i]
            guard ch >= 97 || ch <= 123, let child = node.childs[ch] else { break }
            if child.frequency > 0 || i == last {
                let freq = i == last ? 65535 : child.frequency
                let str = String(bytes: [UInt8](pinyin[0 ... i]), encoding: .ascii) ?? ""
                results.append((str, freq))
            }
            node = child
        }
        results.sort { $0.frequency > $1.frequency }
        return results
    }

    private static func split(_ pinyin: [UInt8]) -> [String] {
        let fronts = retrieve(pinyin)
        let len = pinyin.count
        for phone in fronts {
            let pLen = phone.pinyin.count
            let head = String(bytes: [UInt8](pinyin[0 ..< pLen]))
            if len == pLen {
                return [head]
            } else {
                let tail = [UInt8](pinyin[pLen ..< pinyin.count])
                let rests = retrieve(tail)
                if rests.count > 0 {
                    let rights = split(tail)
                    return [head] + rights
                }
            }
        }
        return []
    }

    // MARK: public

    static func segment(_ pinyin: String) -> [String] {
        return split(pinyin.lowercased().bytes)
    }

    // MARK: - recursion

    private func firstPinyins(of source: String) -> [String] {
        let bytes = source.bytes
        guard bytes.count > 0 else { return [] }
        let s = String(bytes[0])
        guard let array = PinYin.shared.pinyins[s], array.count > 0 else {
            return []
        }
        var results: [String] = []
        for pinyin in array {
            let subbytes = pinyin.bytes
            if bytes.count < subbytes.count {
                continue
            }
            var eq = true
            for i in 0 ..< subbytes.count {
                if bytes[i] != subbytes[i] {
                    eq = false
                    break
                }
            }
            if eq {
                results.append(pinyin)
            }
        }
        return results
    }

    private func recursionSplit(_ source: String) -> [[String]] {
        var results: [[String]] = []
        let heads = firstPinyins(of: source)
        guard heads.count > 0 else { return [] }

        for head in heads {
            let lower = source.index(source.startIndex, offsetBy: head.count)
            let tail = String(source[lower ..< source.endIndex])
            let tails = recursionSplit(tail)
            for pinyins in tails {
                results.append([head] + pinyins)
            }
        }
        return results
    }

    func recursionSegment(_ source: String) -> [[String]] {
        return recursionSplit(source.lowercased())
    }
}
