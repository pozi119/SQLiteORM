//
//  Orm.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import AnyCoder
import Foundation
import Runtime

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

    private var _existingIndexes: [String]?
    private var existingIndexes: [String] {
        if _existingIndexes == nil {
            let sql = "PRAGMA index_list = \(table.quoted);"
            let indexes = db.query(sql)
            _existingIndexes = indexes.map { ($0["name"] as? String) ?? "" }
        }
        return _existingIndexes!
    }

    var clearCache = false

    /// query results cache
    private var _cache: Cache<String, [[String: Primitive]]>?
    var cache: Cache<String, [[String: Primitive]]>? {
        if clearCache {
            _cache?.removeAllObjects()
        }
        return _cache
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
        if let orm = db.orms.object(forKey: table as NSString) as? Orm<T> {
            self.config = orm.config
            self.db = orm.db
            self.table = orm.table
            type = orm.type
            properties = orm.properties
            created = orm.created
            content_table = orm.content_table
            content_rowid = orm.content_rowid
            relative = orm.relative
            _existingIndexes = orm._existingIndexes
            return
        }

        self.config = config
        self.db = db
        type = T.self

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
        switch setup {
            case .create: try? create()
            case .rebuild: try? rebuild()
            default: break
        }
        db.orms.setObject(self, forKey: table as NSString)
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
        let exist = db.exists(table)
        if !exist {
            try create()
            created = true
            return
        }

        var tableConfig = Config.factory(table, db: db)
        if let tblcfg = tableConfig as? PlainConfig, let cfg = config as? PlainConfig, tblcfg != cfg {
            let added = Set(cfg.columns).subtracting(tblcfg.columns)
            if added.count > 0 {
                try? db.begin()
                for col in added {
                    let alertSQL = cfg.sqlToAlert(column: col, table: table)
                    do {
                        try db.run(alertSQL)
                    } catch {
                        try? db.rollback()
                    }
                }
                try? db.commit()

                tableConfig = Config.factory(table, db: db)
                let removed = Set(tableConfig.columns).subtracting(cfg.columns)
                if removed.count > 0 {
                    tableConfig.columns = tableConfig.columns.filter { !removed.contains($0) }
                }
            }
        }

        if tableConfig != config {
            let tempTable = table + "_" + String(describing: NSDate().timeIntervalSince1970)
            try rename(to: tempTable)
            try createTable()
            created = true
            let colset = Set(config.columns).intersection(Set(tableConfig.columns))
            try db.migrating(Array(colset), from: tempTable, to: table, drop: true)
        }

        guard let tblcfg = tableConfig as? PlainConfig, let cfg = config as? PlainConfig else { return }
        if !cfg.isIndexesEqual(tblcfg) {
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
                sql = cfg.sqlToCreate(table: table)
            case let cfg as FtsConfig:
                sql = cfg.sqlToCreate(table: table, content_table: content_table, content_rowid: content_rowid)
            default: break
        }
        try db.run(sql)
    }

    /// create index
    func createIndex() throws {
        guard let cfg = config as? PlainConfig, cfg.indexes.count > 0 else { return }
        let ascIdx = "orm_asc_idx_\(table)"
        let descIdx = "orm_desc_idx_\(table)"
        let ascCols = cfg.indexes.map { $0.quoted }.joined(separator: ",")
        let descCols = cfg.indexes.map { $0.quoted + " DESC" }.joined(separator: ",")
        let ascIdxSQL = "CREATE INDEX IF NOT EXISTS \(ascIdx.quoted) on \(table.quoted) (\(ascCols));"
        let descIdxSQL = "CREATE INDEX IF NOT EXISTS \(descIdx.quoted) on \(table.quoted) (\(descCols));"
        try db.run(ascIdxSQL)
        try db.run(descIdxSQL)
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
