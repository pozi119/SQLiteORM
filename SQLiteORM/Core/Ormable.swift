//
//  Ormable.swift
//  SQLiteORM
//
//  Created by Valo on 2020/7/29.
//

import Foundation
import AnyCoder

public protocol Ormable: Codable {
    /// primary keys
    static var primaries: [String] { get }

    /// white list
    static var whites: [String] { get }

    /// black list
    static var blacks: [String] { get }

    /// index fields
    static var indexes: [String] { get }

    /// not null fileds
    static var notnulls: [String] { get }

    /// unique fileds
    static var uniques: [String] { get }

    /// default value corresponding to the field
    static var dfltVals: [String: Primitive] { get }

    /// record creation / modification time or not
    static var logAt: Bool { get }

    /// is it an auto increment primary key, only valid if the number of primary keys is 1
    static var pkAutoInc: Bool { get }
}

// MARK: - optional

public extension Ormable {
    static var primaries: [String] { [] }
    static var whites: [String] { [] }
    static var blacks: [String] { [] }
    static var indexes: [String] { [] }
    static var notnulls: [String] { [] }
    static var uniques: [String] { [] }
    static var dfltVals: [String: Primitive] { [:] }

    static var logAt: Bool { false }
    static var pkAutoInc: Bool { false }
}

// MARK: - config

extension PlainConfig {
    public convenience init(ormable type: Ormable.Type) {
        self.init(type)
        primaries = type.primaries
        whites = type.whites
        blacks = type.blacks
        indexes = type.indexes
        notnulls = type.notnulls
        uniques = type.uniques
        dfltVals = type.dfltVals
        logAt = type.logAt
        pkAutoInc = type.pkAutoInc
    }
}

// MARK: - orm

extension Orm {
    public convenience init(ormable type: Ormable.Type, db: Database = Database(.temporary), table: String = "", setup: Setup = .create) {
        let config = PlainConfig(ormable: type)
        self.init(config: config, db: db, table: table, setup: setup)
    }
}
