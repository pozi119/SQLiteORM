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

    lazy var cache = Cache<String, Any>()

    lazy var polyphones: [String: [String]] = {
        let parent = Bundle(for: PinYin.self)
        let bundlePath = parent.path(forResource: "PinYin.bundle", ofType: nil) ?? ""
        let bundle = Bundle(path: bundlePath)
        let path = bundle?.path(forResource: "polyphone.plist", ofType: nil) ?? ""
        var _polyphones = (NSDictionary(contentsOfFile: path) as? [String: [String]]) ?? [:]
        return _polyphones
    }()
}

public extension String {
    /// 最大支持多音字的中文文本长度
    private static var _maxSupportLengthOfPolyphone: Int = 5
    static var maxSupportLengthOfPolyphone: Int {
        get {
            return _maxSupportLengthOfPolyphone
        }
        set {
            _maxSupportLengthOfPolyphone = newValue
        }
    }

    /// 是否包含汉字
    var hasChinese: Bool {
        let regex = ".*[\\u4e00-\\u9fa5].*"
        let predicate = NSPredicate(format: "SELF MATCHES \(regex)")
        return predicate.evaluate(with: self)
    }

    /// 拼音字符串
    var pinyin: String {
        let source = NSMutableString(string: self) as CFMutableString
        CFStringTransform(source, nil, kCFStringTransformToLatin, false)
        var dest = (source as NSMutableString) as String
        dest = dest.folding(options: .diacriticInsensitive, locale: .current)
        return dest.replacingOccurrences(of: "'", with: "")
    }

    /// 拼音分词
    var pinyinTokens: [String] {
        var results = PinYin.shared.cache.object(forKey: self) as? [String]
        guard results == nil else { return results! }

        var characterSet: CharacterSet = .whitespacesAndNewlines
        characterSet.formUnion(.punctuationCharacters)
        let prepared = trimmingCharacters(in: characterSet)
        let pys = prepared.pinyin.components(separatedBy: characterSet)
        let polypys = prepared.polyphonePinyins
        let flatten = String.flatten(pinyins: pys, polyphones: polypys)

        var array: [String] = []
        for polypys in flatten {
            let totals = polypys.joined(separator: "")
            let initials = polypys.map { $0.prefix(1) }.joined(separator: "")
            array.append(totals)
            array.append(initials)
        }

        results = Array(Set(array))
        PinYin.shared.cache.setObject(results!, forKey: self)
        return results!
    }

    /// 获取多音字拼音
    var polyphonePinyins: [Int: [String]] {
        if count > String._maxSupportLengthOfPolyphone { return [:] }
        let source = self as NSString

        var results: [Int: [String]] = [:]
        for i in 0 ..< count {
            let ch = source.character(at: i)
            let key = String(format: "%X", ch)
            let polys = PinYin.shared.polyphones[key] ?? []
            let set = Set(polys.filter { $0.count > 1 }.map { String($0.prefix($0.count - 1)) })
            results[i] = Array(set)
        }

        return results.filter { $0.value.count > 0 }
    }

    /// 预加载拼音分词资源
    static func preloadingForPinyin() {
        _ = "中文".pinyinTokens
    }

    private static func flatten(pinyins: [String], polyphones: [Int: [String]]) -> [[String]] {
        guard polyphones.count > 0 else { return [pinyins] }
        let chineseCount = pinyins.count
        var results: [[String]] = []
        for (idx, value) in polyphones {
            if idx >= chineseCount || value.count == 0 { continue }
            for item in value {
                if item.count == 0 { continue }
                var temp = pinyins
                temp[idx] = item
                results.append(temp)
            }
        }
        return Array(Set(results))
    }
}

public extension String {
    var trim: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var strip: String {
        return replacingOccurrences(of: " +", with: " ", options: .regularExpression)
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

public extension Dictionary where Key == String, Value == Binding {
    func item<T: Codable>(_ type: T.Type) -> T? {
        return try? OrmDecoder().decode(T.self, from: self)
    }
}

public extension Array where Element: Hashable {
    static func === (lhs: Array, rhs: Array) -> Bool {
        return Set(lhs) == Set(rhs)
    }
}

public extension Array where Element: Binding {
    func quoteJoined(separator: String = "", quote mark: Character? = nil) -> String {
        return map { "\($0)".quote(mark) }.joined(separator: separator)
    }
}

public extension Array where Element == Dictionary<String, Binding> {
    func allItems<T: Codable>(_ type: T.Type) -> [T] {
        do {
            let array = try OrmDecoder().decode([T].self, from: self)
            return array
        } catch {
            print(error)
            return []
        }
    }
}
