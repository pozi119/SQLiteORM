//
//  Orm.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import Foundation

fileprivate struct Inspection: OptionSet {
    let rawValue: UInt8

    static let exist = Inspection(rawValue: 1 << 0)
    static let tableChanged = Inspection(rawValue: 1 << 1)
    static let indexChanged = Inspection(rawValue: 1 << 2)

    static let all: Inspection = [.exist, .tableChanged, .indexChanged]
}

public final class Orm<T> {
    /// table inspection results
    public enum Setup {
        case none, create, rebuild
    }

    /// configuration
    public let config: Config

    /// database
    public let db: Database

    /// table name
    public let table: String
    
    /// type
    public let type: T.Type

    /// property corresponding to the field
    public let properties: [String: PropertyInfo]

    private var created = false

    private var content_table: String?

    private var content_rowid: String?

    private weak var relative: Orm?

    private var tableConfig: Config

    private var _existingIndexes: [String]?
    private var existingIndexes: [String] {
        if _existingIndexes == nil {
            let sql = "PRAGMA index_list = \(table.quoted);"
            let indexes = db.query(sql)
            _existingIndexes = indexes.map { ($0["name"] as? String) ?? "" }
        }
        return _existingIndexes!
    }

    /// initialize orm
    ///
    /// - Parameters:
    ///   - flag: create table immediately? in some sences, table creation  may be delayed
    public init(config: Config,
                db: Database = Database(.temporary),
                table: String = "",
                setup: Setup = .create) {
        assert(config.type != nil && config.type! == T.self && config.columns.count > 0, "Invalid config!")

        self.config = config
        self.db = db
        self.type = T.self

        var props = [String: PropertyInfo]()
        let info = try? typeInfo(of: config.type!)
        if info != nil {
            for prop in info!.properties {
                props[prop.name] = prop
            }
        }
        properties = props

        if table.count > 0 {
            self.table = table
        } else {
            self.table = info?.name ?? ""
        }
        tableConfig = Config.factory(self.table, db: db)
        switch setup {
            case .create: try? create()
            case .rebuild: try? rebuild()
            default: break
        }
    }

    public convenience init(config: FtsConfig,
                            db: Database = Database(.temporary),
                            table: String = "",
                            content_table: String,
                            content_rowid: String,
                            setup: Setup = .none) {
        self.init(config: config, db: db, table: table, setup: setup)
        self.content_table = content_table
        self.content_rowid = content_rowid
        switch setup {
            case .create: try? create()
            case .rebuild: try? rebuild()
            default: break
        }
    }

    public convenience init(config: FtsConfig,
                            relative orm: Orm,
                            content_rowid: String) {
        config.treate()
        if
            let cfg = orm.config as? PlainConfig,
            (cfg.primaries.count == 1 && cfg.primaries.first! == content_rowid) || cfg.uniques.contains(content_rowid),
            Set(config.columns).isSubset(of: Set(cfg.columns)),
            cfg.columns.contains(content_rowid) {
        } else {
            let message =
                """
                 The following conditions must be met:
                 1. The relative ORM is the universal ORM
                 2. The relative ORM has uniqueness constraints
                 3. The relative ORM contains all fields of this ORM
                 4. The relative ORM contains the content_rowid
                """
            assert(false, message)
        }

        let fts_table = "fts_" + orm.table
        self.init(config: config, db: orm.db, table: fts_table, setup: .create)
        content_table = orm.table
        self.content_rowid = content_rowid

        // trigger
        let ins_rows = (["rowid"] + config.columns).joined(separator: ",")
        let ins_vals = ([content_rowid] + config.columns).map { "new." + $0 }.joined(separator: ",")
        let del_rows = ([fts_table, "rowid"] + config.columns).joined(separator: ",")
        let del_vals = (["'delete'"] + ([content_rowid] + config.columns).map { "old." + $0 }).joined(separator: ",")

        let ins_tri_name = fts_table + "_insert"
        let del_tri_name = fts_table + "_delete"
        let upd_tri_name = fts_table + "_update"

        let ins_trigger = "CREATE TRIGGER IF NOT EXISTS \(ins_tri_name) AFTER INSERT ON \(orm.table) BEGIN \n"
            + "INSERT INTO \(fts_table) (\(ins_rows)) VALUES (\(ins_vals)); \n"
            + "END;"
        let del_trigger = "CREATE TRIGGER IF NOT EXISTS \(del_tri_name) AFTER DELETE ON \(orm.table) BEGIN \n"
            + "INSERT INTO \(fts_table) (\(del_rows)) VALUES (\(del_vals)); \n"
            + "END;"
        let upd_trigger = "CREATE TRIGGER IF NOT EXISTS \(upd_tri_name) AFTER UPDATE ON \(orm.table) BEGIN \n"
            + "INSERT INTO \(fts_table) (\(del_rows)) VALUES (\(del_vals)); \n"
            + "INSERT INTO \(fts_table) (\(ins_rows)) VALUES (\(ins_vals)); \n"
            + "END;"

        do {
            try orm.create()
            try create()
            try orm.db.run(ins_trigger)
            try orm.db.run(del_trigger)
            try orm.db.run(upd_trigger)
        } catch {
            print(error)
        }
    }

    /// table creation
    public func create() throws {
        guard created == false else { return }
        config.treate()
        try createTable()
        created = true
        if config.indexes.count == 0 || existingIndexes.contains("orm_index_\(table)") { return }
        try createIndex()
    }

    public func rebuild() throws {
        created = false
        let ins = inspect()
        try setup(with: ins)
    }

    /// inspect table
    fileprivate func inspect() -> Inspection {
        var ins: Inspection = .init()
        let exist = db.exists(table)
        guard exist else { return ins }

        ins.insert(.exist)
        switch (tableConfig, config) {
            case let (tableConfig as PlainConfig, config as PlainConfig):
                if tableConfig != config {
                    ins.insert(.tableChanged)
                }
                if !tableConfig.isIndexesEqual(config) {
                    ins.insert(.indexChanged)
                }
            case let (tableConfig as FtsConfig, config as FtsConfig):
                if tableConfig != config {
                    ins.insert(.tableChanged)
                }
            default:
                ins.insert([.tableChanged, .indexChanged])
        }
        return ins
    }

    /// create table with inspection
    fileprivate func setup(with options: Inspection) throws {
        let exist = options.contains(.exist)
        let changed = options.contains(.tableChanged)
        let indexChanged = options.contains(.indexChanged)
        let general = config is PlainConfig

        let tempTable = table + "_" + String(describing: NSDate().timeIntervalSince1970)

        if exist && changed {
            try rename(to: tempTable)
        }
        if !exist || changed {
            try createTable()
        }
        created = true
        if exist && changed && general {
            // MARK: ** FTS table, please migrate data manually **

            try migrationData(from: tempTable)
        }
        if general && (indexChanged || !exist) {
            try rebuildIndex()
        }
    }

    /// rename table
    func rename(to tempTable: String) throws {
        let sql = "ALTER TABLE \(table.quoted) RENAME TO \(tempTable.quoted)"
        try db.run(sql)
    }

    /// create table
    func createTable() throws {
        if db.exists(table) { return }
        var sql = ""
        switch config {
            case let cfg as PlainConfig:
                sql = cfg.createSQL(with: table)
            case let cfg as FtsConfig:
                sql = cfg.createSQL(with: table, content_table: content_table, content_rowid: content_rowid)
            default: break
        }
        try db.run(sql)
    }

    /// create index
    func createIndex() throws {
        guard let cfg = config as? PlainConfig, cfg.indexes.count > 0 else { return }
        let indexName = "orm_index_\(table)"
        let indexesString = cfg.indexes.joined(separator: ",")
        let createSQL = "CREATE INDEX IF NOT EXISTS \(indexName.quoted) on \(table.quoted) (\(indexesString));"
        try db.run(createSQL)
    }

    /// migrating data from old table to new table
    func migrationData(from tempTable: String) throws {
        let columnsSet = NSMutableOrderedSet(array: config.columns)
        columnsSet.intersectSet(Set(tableConfig.columns))
        let columns = columnsSet.array as! [String]

        let fields = columns.joined(separator: ",")
        guard fields.count > 0 else { return }
        let sql = "INSERT INTO \(table.quoted) (\(fields)) SELECT \(fields) FROM \(tempTable.quoted)"
        let drop = "DROP TABLE IF EXISTS \(tempTable.quoted)"
        try db.run(sql)
        try db.run(drop)
    }

    /// drop indexes
    func dropIndexes() throws {
        let indexes = existingIndexes.filter { !$0.hasPrefix("sqlite_autoindex_") }
        guard indexes.count > 0 else { return }
        let sql = indexes.reduce("") { $0 + "DROP INDEX IF EXISTS \($1);" }
        try db.run(sql)
    }

    /// rebuild indexes
    func rebuildIndex() throws {
        guard config is PlainConfig, config.indexes.count > 0 else { return }
        try dropIndexes()
        try createIndex()
        _existingIndexes = nil
    }
}
