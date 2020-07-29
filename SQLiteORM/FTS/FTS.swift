//
//  FTS.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation

public extension Database {
    /// register tokenizer
    ///
    /// - Parameters:
    ///   - type: tokenize method
    @discardableResult
    func register(_ method: TokenMethod, for tokenizer: String) -> Bool {
        return SQLiteORMRegisterEnumerator(handle, Int32(method.rawValue), tokenizer)
    }

    /// get tokenize method
    func enumerator(for tokenizer: String) -> TokenMethod {
        let result = SQLiteORMFindEnumerator(handle, tokenizer)
        return TokenMethod(rawValue: Int(result))
    }
}
