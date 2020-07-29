//
//  Ftsable.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/29.
//

import Foundation

public protocol Ftsable: Codable {
    /// white list
    static var whitelist: [String] { get }
    
    /// black list
    static var blacklist: [String] { get }
    
    /// when fts indexes count is 0, all fields are indexed by default
    static var indexlist: [String] { get }

    /// fts module, default is fts5
    static var module: String { get }
    
    /// fts tokenizer, default is `sqlitorm`
    static var tokenizer: String { get }
}

// MARK: - optional

public extension Ftsable {
    static var whitelist: [String] { [] }
    static var blacklist: [String] { [] }
    static var indexlist: [String] { [] }

    static var module: String { "fts5" }
    static var tokenizer: String { "sqliteorm \(TokenMask.default.rawValue)" }
}

// MARK: - config

extension FtsConfig {
    public convenience init(ftsable type: Ftsable.Type) {
        self.init(type)
        whites = type.whitelist
        blacks = type.blacklist
        indexes = type.indexlist
        module = type.module
        tokenizer = type.tokenizer
    }
}

// MARK: - orm

extension Orm {
    public convenience init(ftsable type: Ftsable.Type, db: Database = Database(.temporary), table: String = "", setup flag: Bool = true) {
        let config = FtsConfig(ftsable: type)
        self.init(config: config, db: db, table: table, setup: flag)
    }
}
