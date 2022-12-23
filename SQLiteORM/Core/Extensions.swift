//
//  Extensions.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/21.
//

import AnyCoder
import Foundation

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
        guard let ch = mark else { return self }
        let fix = "\(ch)"
        if hasPrefix(fix) && hasSuffix(fix) {
            return self
        }
        let escaped = reduce("") { string, character in
            string + (character == ch ? "\(ch)\(ch)" : "\(character)")
        }
        return "\(ch)\(escaped)\(ch)"
    }

    func bracket(_ left: Character = "(", _ right: Character = ")") -> String {
        guard !isEmpty else { return "()" }
        let l = "\(left)"
        let r = "\(right)"
        let prefix = l.isEmpty ? "" : l
        let suffix = r.isEmpty ? "" : r
        return "\(prefix)\(self)\(suffix)"
    }

    func match(_ regex: String) -> Bool {
        let r = range(of: regex, options: [.regularExpression, .caseInsensitive])
        return r != nil
    }
}

public extension Array where Element == String {
    var joined: String {
        return joined(separator: ",")
    }
}

public extension Array where Element: Primitive {
    var sqlJoined: String {
        return map { $0.sqlValue }.joined(separator: ",")
    }
}

public extension Array where Element: Hashable {
    static func === (lhs: Array, rhs: Array) -> Bool {
        return Set(lhs) == Set(rhs)
    }
}

public extension Array where Element == Dictionary<String, any Primitive> {
    func toItems<T>(_ type: T.Type) -> [T] {
        do {
            var array: [T] = []
            if let u = [T].self as? Codable.Type {
                array = try ManyDecoder().decode(u.self, from: self) as! [T]
            } else {
                array = try AnyDecoder.decode(T.self, from: self)
            }
            return array
        } catch {
            print(error)
            return []
        }
    }

    func toWhere() -> String {
        map { $0.toWhere().bracket() }.joined(separator: " OR ")
    }
}

public extension Dictionary {
    mutating func removeValues(forKeys: [Key]) {
        for key in forKeys {
            removeValue(forKey: key)
        }
    }
}

public extension Dictionary where Key == String, Value == any Primitive {
    func toItem<T>(_ type: T.Type) -> T? {
        do {
            var obj: T?
            if let u = T.self as? Codable.Type {
                obj = try ManyDecoder().decode(u.self, from: self) as? T
            } else {
                obj = try AnyDecoder.decode(T.self, from: self)
            }
            return obj
        } catch {
            print(error)
            return nil
        }
    }

    func toWhere() -> String {
        map { ($0.key |== $0.value).bracket() }.joined(separator: " AND ")
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

    var bytes: [UInt8] {
        return utf8.map { UInt8($0) }
    }

    /// has chinese characters
    var hasChinese: Bool {
        let regex = ".*[\\u4e00-\\u9fa5].*"
        let predicate = NSPredicate(format: "SELF MATCHES \(regex)")
        return predicate.evaluate(with: self)
    }

    var pinyin: String {
        let source = NSMutableString(string: self) as CFMutableString
        CFStringTransform(source, nil, kCFStringTransformToLatin, false)
        var dest = (source as NSMutableString) as String
        dest = dest.folding(options: .diacriticInsensitive, locale: .current)
        return dest.replacingOccurrences(of: "'", with: "")
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

    var singleLine: String {
        return replacingOccurrences(of: "\\s| ", with: " ", options: .regularExpression, range: startIndex ..< endIndex)
    }

    var matchingPattern: String {
        guard !isEmpty else { return self }
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
}
