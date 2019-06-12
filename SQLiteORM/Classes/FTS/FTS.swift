//
//  FTS.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation

/// 分词器
public protocol FtsTokenizer {
    /// 核心枚举方法
    static var enumerator: SQLiteORMXEnumerator { get }
}

public extension Database {
    /// 注册分词器
    ///
    /// - Parameters:
    ///   - type: 分词器
    ///   - tokenizer: 分词器名称
    /// - Returns: 是否注册成功
    @discardableResult func register<T>(_ type: T.Type, for tokenizer: String) -> Bool where T: FtsTokenizer {
        return SQLiteORMRegisterEnumerator(handle, type.enumerator, tokenizer)
    }

    /// 获取分词器核心枚举方法
    ///
    /// - Parameter tokenizer: 分词器名称
    /// - Returns: 核心枚举方法
    func enumerator(for tokenizer: String) -> SQLiteORMXEnumerator? {
        return SQLiteORMFindEnumerator(handle, tokenizer)
    }
}

public extension Orm {
    /// 高亮搜索结果
    ///
    /// - Parameters:
    ///   - items: 搜索结果
    ///   - field: 要高亮的字段
    ///   - keyword: 搜索使用的关键字
    ///   - pinyinMaxLen: 进行拼音分词的最大utf8字符串长度
    ///   - attributes: 高亮参数
    /// - Returns: 属性文本数组
    func highlight(_ items: [[String: Binding]],
                   field: String,
                   keyword: String,
                   pinyinMaxLen: Int32 = -1,
                   attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString] {
        guard let cfg = config as? FtsConfig else {
            fatalError("invalid orm!")
        }
        assert(cfg.tokenizer.count > 0, "Invalid orm!")
        let tokenizer = cfg.tokenizer.components(separatedBy: " ").first!
        guard let enumerator = db.enumerator(for: tokenizer) else {
            fatalError("invalid orm!")
        }

        return SQLiteORMHighlight(items, field, keyword, pinyinMaxLen, enumerator, attributes)
    }
}
