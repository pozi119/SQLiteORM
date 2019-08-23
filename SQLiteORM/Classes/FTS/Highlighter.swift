//
//  Highlighter.swift
//  SQLiteORM
//
//  Created by Valo on 2019/8/23.
//

public class Highlighter {
    var method: TokenMethod
    var keyword: String
    var pinyin = false
    var highlightAttributes: [NSAttributedString.Key: Any]
    var normalAttributes: [NSAttributedString.Key: Any] = [:]
    var reserved: Any?

    private lazy var keywordTokens: [SQLiteORMToken] = {
        var tokens = tokenize(self.keyword, self.method)
        if self.pinyin {
            let pys = pinyinTokenize(self.keyword, 0, self.keyword.utf8.count)
            tokens.append(contentsOf: pys)
        }
        return tokens
    }()

    public convenience init(orm: Orm, keyword: String, highlightAttributes: [NSAttributedString.Key: Any]) {
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

    public func highlight(_ source: String) -> (text: NSAttributedString, hits: UInt) {
        let bytes = source.utf8.map { UInt8($0) }
        let count = bytes.count
        var tokens = tokenize(source, method)
        if pinyin {
            let pys = pinyinTokenize(source, 0, count)
            tokens.append(contentsOf: pys)
        }
        var tokenized = Array(repeating: UInt8(0), count: count)

        for token in tokens {
            for pytk in keywordTokens {
                if pytk.token == token.token {
                    tokenized.replaceSubrange(Int(token.start) ..< Int(token.end), with: token.token.utf8.map { UInt8($0) })
                }
            }
        }

        var start = 0
        var end = 0
        var isBegin = true
        var hit: UInt = 0
        var result = NSMutableAttributedString()
        var flag = -1 {
            willSet {
                if newValue != flag && end > start {
                    var string = String(bytes: bytes[start ..< end], encoding: .utf8) ?? ""
                    if isBegin {
                        isBegin = false
                        if flag == 0 && string.count > 12 {
                            let range = string.index(string.endIndex, offsetBy: -3) ..< string.endIndex
                            string = "..." + string[range]
                        }
                    }
                    let attrText = NSAttributedString(string: string, attributes: flag == 1 ? highlightAttributes : normalAttributes)
                    result.append(attrText)
                    start = end
                    if flag == 1 { hit += 1 }
                }
            }
        }

        while end < count {
            flag = tokenized[end] == 0 ? 0 : 1
            end += 1
        }
        flag = -1

        return (result, hit)
    }

    public func highlight(_ sources: [String]) -> [(text: NSAttributedString, hits: UInt)] {
        return sources.map { highlight($0) }
    }
}
