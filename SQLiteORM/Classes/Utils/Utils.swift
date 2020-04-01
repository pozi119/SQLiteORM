//
//  Utils.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/5.
//

import Foundation

/// 拼音相关
fileprivate final class PinYin {
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

    lazy var hanzi2pinyins: [String: [String]] = {
        let path = PinYin.path(of: "hanzi2pinyin.plist")
        var _polyphones = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        return _polyphones
    }()

    lazy var gb2big5Map: [String: String] = {
        let simplified = self.transforms.simplified
        let traditional = self.transforms.traditional
        let count = simplified.count
        var map: [String: String] = [:]
        for i in 0 ..< count {
            let k = String(simplified[simplified.index(simplified.startIndex, offsetBy: i)])
            let v = String(traditional[traditional.index(traditional.startIndex, offsetBy: i)])
            map[k] = v
        }
        return map
    }()

    lazy var big52gbMap: [String: String] = {
        let simplified = self.transforms.simplified
        let traditional = self.transforms.traditional
        let count = simplified.count
        var map: [String: String] = [:]
        for i in 0 ..< count {
            let k = String(traditional[traditional.index(traditional.startIndex, offsetBy: i)])
            let v = String(simplified[simplified.index(simplified.startIndex, offsetBy: i)])
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

    lazy var numberFormatter: NumberFormatter = {
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
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

    /// 是否包含汉字
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
            let s = String(self[index(startIndex, offsetBy: i)])
            let v = PinYin.shared.big52gbMap[s]
            string.append(v ?? s)
        }
        return string
    }

    var traditional: String {
        var string = ""
        for i in 0 ..< count {
            let s = String(self[index(startIndex, offsetBy: i)])
            let v = PinYin.shared.gb2big5Map[s]
            string.append(v ?? s)
        }
        return string
    }

    func transform(_ map: [String: String]) -> String {
        var string = self
        let pattern = "[\\u4e00-\\u9fa5]+"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        regex?.enumerateMatches(in: self, options: .reportCompletion, range: NSRange(location: 0, length: count), using: { result, _, _ in
            guard let r = result, r.resultType == .regularExpression else { return }
            let lower = self.index(self.startIndex, offsetBy: r.range.location)
            let upper = self.index(lower, offsetBy: r.range.length)
            var fragment = ""
            for i in 0 ..< r.range.length {
                let ch = String(self[self.index(self.startIndex, offsetBy: r.range.location + i)])
                let trans = PinYin.shared.big52gbMap[ch] ?? ch
                fragment.append(trans)
            }
            string.replaceSubrange(lower ..< upper, with: fragment)
        })
        return string
    }

    /// 拼音字符串
    var pinyin: String {
        let source = NSMutableString(string: self) as CFMutableString
        CFStringTransform(source, nil, kCFStringTransformToLatin, false)
        var dest = (source as NSMutableString) as String
        dest = dest.folding(options: .diacriticInsensitive, locale: .current)
        return dest.replacingOccurrences(of: "'", with: "")
    }

    func pinyins(at index: Int) -> (fulls: [String], abbrs: [String]) {
        guard count > index else { return ([], []) }
        let idx = self.index(startIndex, offsetBy: index)
        let string = simplified as NSString
        var ch = string.character(at: index)
        let single = String(self[idx])
        if ch < 0x4E00 || ch > 0x9FA5 {
            return ([single], [single])
        }
        let trans = PinYin.shared.big52gbMap[single] ?? single
        ch = (trans as NSString).character(at: 0)
        let zcs = ["z", "c", "s"]
        let key = String(format: "%X", ch)
        let pinyins = PinYin.shared.hanzi2pinyins[key] ?? []
        let fulls = NSMutableOrderedSet()
        let abbrs = NSMutableOrderedSet()
        for pinyin in pinyins {
            if pinyin.count < 1 { continue }
            let full = String(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: pinyin.count - 1)])
            let abbr = String(pinyin[pinyin.startIndex ..< pinyin.index(pinyin.startIndex, offsetBy: 1)])
            fulls.add(full)
            abbrs.add(abbr)
            if zcs.contains(abbr) {
                abbrs.add(abbr + "h")
            }
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

    var numberWithoutSeparator: String {
        let num = String.tokenFormatter.number(from: self)
        return num?.stringValue ?? ""
    }

    var clean: String {
        let array = components(separatedBy: PinYin.shared.cleanSet)
        return array.joined(separator: "")
    }

    private var headPinyins: [String] {
        let bytes = self.bytes
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

    private var _splitedPinyins: [[String]] {
        var results: [[String]] = []
        let heads = headPinyins
        guard heads.count > 0 else { return [] }

        for head in heads {
            let tail = String(self[index(startIndex, offsetBy: head.count) ..< endIndex])
            let tails = tail._splitedPinyins
            for pinyins in tails {
                results.append([head] + pinyins)
            }
        }
        return results
    }

    var splitedPinyins: [[String]] {
        return lowercased()._splitedPinyins
    }

    /// 预加载拼音分词资源
    static func preloadingForPinyin() {
        _ = "中文".pinyins
    }
}

public extension String {
    var trim: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var strip: String {
        return replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    }

    var quoted: String {
        return quote()
    }

    func quote(_ mark: Character? = "\"") -> String {
        guard mark != nil else {
            return self
        }
        let ch = mark!
        let fix = "\(ch)"
        if hasPrefix(fix) && hasSuffix(fix) {
            return self
        }
        let escaped = reduce("") { string, character in
            string + (character == ch ? "\(ch)\(ch)" : "\(character)")
        }
        return "\(ch)\(escaped)\(ch)"
    }

    func match(_ regex: String) -> Bool {
        let r = range(of: regex, options: [.regularExpression, .caseInsensitive])
        return r != nil
    }
}

public extension Dictionary {
    static func === (lhs: Dictionary, rhs: Dictionary) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else {
            return false
        }
        for key in lhs.keys {
            let lvalue = lhs[key]
            let rvalue = rhs[key]
            switch (lvalue, rvalue) {
            case let (lvalue as Bool, rvalue as Bool): guard lvalue == rvalue else { return false }
            case let (lvalue as Int, rvalue as Int): guard lvalue == rvalue else { return false }
            case let (lvalue as Int8, rvalue as Int8): guard lvalue == rvalue else { return false }
            case let (lvalue as Int16, rvalue as Int16): guard lvalue == rvalue else { return false }
            case let (lvalue as Int32, rvalue as Int32): guard lvalue == rvalue else { return false }
            case let (lvalue as Int64, rvalue as Int64): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt, rvalue as UInt): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt8, rvalue as UInt8): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt16, rvalue as UInt16): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt32, rvalue as UInt32): guard lvalue == rvalue else { return false }
            case let (lvalue as UInt64, rvalue as UInt64): guard lvalue == rvalue else { return false }
            case let (lvalue as Float, rvalue as Float): guard lvalue == rvalue else { return false }
            case let (lvalue as Double, rvalue as Double): guard lvalue == rvalue else { return false }
            case let (lvalue as String, rvalue as String): guard lvalue == rvalue else { return false }
            case let (lvalue as Data, rvalue as Data): guard lvalue == rvalue else { return false }
            case (_, _):
                return false
            }
        }
        return true
    }

    mutating func removeValues(forKeys: [Key]) {
        for key in forKeys {
            removeValue(forKey: key)
        }
    }
}

public extension Array where Element: Hashable {
    static func === (lhs: Array, rhs: Array) -> Bool {
        return Set(lhs) == Set(rhs)
    }
}

public extension Array where Element: Binding {
    var sqlJoined: String {
        return map { $0.sqlValue }.joined(separator: ",")
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
