//
//  FTS.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation

/// 分词器
public extension Database {
    /// 注册分词器
    ///
    /// - Parameters:
    ///   - type: 分词器
    ///   - tokenizer: 分词器名称
    /// - Returns: 是否注册成功
    @discardableResult func register(_ method: TokenMethod, for tokenizer: String) -> Bool {
        return SQLiteORMRegisterEnumerator(handle, Int32(method.rawValue), tokenizer)
    }

    /// 获取分词器核心枚举方法
    ///
    /// - Parameter tokenizer: 分词器名称
    /// - Returns: 核心枚举方法
    func enumerator(for tokenizer: String) -> TokenMethod {
        let result = SQLiteORMFindEnumerator(handle, tokenizer)
        return TokenMethod(rawValue: Int(result)) ?? .unknown
    }
}
