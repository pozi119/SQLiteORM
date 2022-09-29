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
        dic.forEach { result[unichar(strtol($0.key, nil, 16))] = $0.value }
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
}

public extension String {
    var simplified: String {
        var string = ""
        for i in 0 ..< count {
            let s = (self as NSString).character(at: i)
            let v = PinYin.shared.big52gbMap[s] ?? s
            string.append(String(Unicode.Scalar(v)!))
        }
        return string
    }

    var traditional: String {
        var string = ""
        for i in 0 ..< count {
            let s = (self as NSString).character(at: i)
            let v = PinYin.shared.gb2big5Map[s] ?? s
            string.append(String(Unicode.Scalar(v)!))
        }
        return string
    }

    var clean: String {
        let array = components(separatedBy: PinYin.shared.cleanSet)
        return array.joined(separator: "")
    }

    private static var tokenFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }

    /// pinyin segmentation search
    var fts5MatchPattern: String {
        let allPinyins = pinyinSegmentation
        var results: [String] = []

        results.append(fullWidthPattern.quoted)
        for pinyins in allPinyins {
            let pattern = (" " + pinyins.joined(separator: " ")).quoted + " *"
            results.append(pattern)
        }
        return results.joined(separator: " OR ")
    }

    var halfWidthPattern: String {
        var array: [unichar] = []
        let string = self as NSString
        for i in 0 ..< count {
            var ch = string.character(at: i)
            switch ch {
            case 0xFF01 ... 0xFF5E: ch -= 0xFEE0
            case 0xFFE0: ch = 0xA2
            case 0xFFE1: ch = 0xA3
            case 0xFFE2: ch = 0xAC
            case 0xFFE3: ch = 0xAF
            case 0xFFE4: ch = 0xA6
            case 0xFFE5: ch = 0xA5
            default: break
            }
            array.append(ch)
        }
        let r = NSString(characters: &array, length: count)
        return r as String
    }

    var fullWidthPattern: String {
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
        let s = String(first!)
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
        _ = PinYin.shared.pinyins
        _ = PinYin.shared.hanzi2pinyins
        _ = PinYin.shared.syllables
        _ = PinYin.shared.big52gbMap
    }

    static func fts5Highlight(of fields: [String],
                              tableName: String,
                              tableColumns: [String],
                              resultColumns: [String] = [],
                              left: String = "<b>",
                              right: String = "</b>") -> String {
        let resultCols = resultColumns.count > 0 ? resultColumns : tableColumns
        guard fields.count > 0, tableName.count > 0, tableColumns.count > 0 else { return resultCols.joined(separator: ",") }

        let count = tableColumns.count
        var array: [String] = []
        for col in resultCols {
            if !tableColumns.contains(col) { continue }
            var highlight: String?
            if fields.contains(col) {
                if let idx = tableColumns.firstIndex(of: col) {
                    if idx < count {
                        highlight = "highlight(\(tableName), \(idx),'\(left)','\(right)') AS \(col)"
                    }
                }
            }
            if let hl = highlight {
                array.append(hl)
            } else {
                array.append(col)
            }
        }

        return array.joined(separator: ",")
    }
}

public extension NSAttributedString {
    func trim(to maxLen: Int, first range: NSRange) -> NSAttributedString {
        let upper = range.upperBound
        guard length > maxLen, upper > length else { return self }

        let attrText = mutableCopy() as! NSMutableAttributedString
        let lower = range.location
        let len = range.length

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

    func trim(to maxLen: Int, with attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let attributes = attrs as NSDictionary

        var first: NSRange = NSRange()
        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { sAttrs, range, stop in
            let tAttrs = sAttrs as NSDictionary
            if tAttrs == attributes {
                first = range
                stop.assign(repeating: true, count: 1)
            }
        }

        return trim(to: maxLen, first: first)
    }

    convenience init(feature string: String,
                     attibutes: [NSAttributedString.Key: Any],
                     left: String = "<b>",
                     right: String = "</b>") {
        let llen = left.count
        let rlen = right.count
        guard llen > 0, rlen > 0, string.count > 0 else {
            self.init(string: "")
            return
        }

        var mstr = string
        var loc = mstr.startIndex
        var ranges: [Range<String.Index>] = []

        while true {
            if let lr = mstr.range(of: left) {
                mstr.removeSubrange(lr)
                loc = lr.lowerBound

                if let rr = mstr.range(of: right, options: [], range: loc ..< mstr.endIndex) {
                    mstr.removeSubrange(rr)
                    ranges.append(loc ..< rr.lowerBound)
                } else {
                    mstr.insert(contentsOf: left, at: loc)
                    break
                }
            } else {
                break
            }
        }
        let attrText = NSMutableAttributedString(string: mstr)
        for r in ranges {
            let lower = mstr.distance(from: mstr.startIndex, to: r.lowerBound)
            let upper = mstr.distance(from: mstr.startIndex, to: r.upperBound)
            let range = NSRange(location: lower, length: upper - lower)
            attrText.addAttributes(attibutes, range: range)
        }
        self.init(attributedString: attrText)
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
