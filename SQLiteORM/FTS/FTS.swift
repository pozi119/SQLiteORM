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
    func register(_ enumerator: IEnumerator.Type, for tokenizer: String) -> Bool {
        return SQLiteORMRegisterEnumerator(handle, enumerator.self, tokenizer)
    }

    /// get tokenize method
    func enumerator(for tokenizer: String) -> IEnumerator.Type? {
        return SQLiteORMFindEnumerator(handle, tokenizer)
    }
}
