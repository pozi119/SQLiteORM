//
//  Orm.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import Foundation

/// 表检查结果选项
public struct Inspection: OptionSet {
    public let rawValue: UInt8
    public static let exist = Inspection(rawValue: 1 << 0)
    public static let tableChanged = Inspection(rawValue: 1 << 1)
    public static let indexChanged = Inspection(rawValue: 1 << 2)
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public final class Orm<T: Codable> {
    /// 配置
    public let config: Config

    /// 数据库
    public let db: Database

    /// 表名
    public let table: String

    /// 属性
    public let properties: [String: PropertyInfo]

    /// Encoder
    public let encoder = OrmEncoder()

    /// Decoder
    public let decoder = OrmDecoder()

    public private(set) var created = false

    private var content_table: String? = nil

    private var content_rowid: String? = nil

    private weak var relative: Orm? = nil

    private var tableConfig: Config

    /// 初始化ORM
    ///
    /// - Parameters:
    ///   - config: 配置
    ///   - db: 数据库
    ///   - table: 表
    ///   - flag: 是否检查并创建表.某些场景需延迟创建表
    public init(config: Config, db: Database = Database(.temporary), table: String = "", setup flag: Bool = true) {
        assert(config.type != nil && config.columns.count > 0, "invalid config")

        self.config = config
        self.db = db

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
        if flag {
            try? setup()
        }
    }

    public convenience init(config: FtsConfig,
                            db: Database = Database(.temporary),
                            table: String = "",
                            content_table: String,
                            content_rowid: String,
                            setup flag: Bool = true) {
        self.init(config: config, db: db, table: table, setup: false)
        self.content_table = content_table
        self.content_rowid = content_rowid
        if flag {
            try? setup()
        }
    }

    public convenience init(config: FtsConfig,
                            relative orm: Orm,
                            content_rowid: String,
                            setup flag: Bool = true) {
        config.treate()
        if
            let cfg = orm.config as? PlainConfig,
            (cfg.primaries.count == 1 && cfg.primaries.first! == content_rowid) || cfg.uniques.contains(content_rowid),
            Set(config.columns).isSubset(of: Set(cfg.columns)),
            !config.columns.contains(content_rowid) {
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
        self.init(config: config, db: orm.db, table: fts_table, setup: false)
        content_table = orm.table
        self.content_rowid = content_rowid

        do {
            if !orm.created { try orm.setup() }
            if flag { try setup() }
        } catch {
            print(error)
        }

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
            try orm.db.run(ins_trigger)
            try orm.db.run(del_trigger)
            try orm.db.run(upd_trigger)
        } catch {
            print(error)
        }
    }

    /// 创建表
    ///
    /// - Throws: 创建表过程中的错误
    public func setup() throws {
        let ins = inspect()
        try setup(with: ins)
    }

    /// 检查表配置
    ///
    /// - Returns: 检查结果
    public func inspect() -> Inspection {
        var ins: Inspection = .init()
        let exist = db.exists(table)
        guard exist else {
            return ins
        }
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

    /// 根据检查结果创建或更新表
    ///
    /// - Parameter options: 检查结果
    /// - Throws: 创建/更新表过程中的错误
    public func setup(with options: Inspection) throws {
        guard !created else { return }

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
        if exist && changed && general {
            // NOTE: FTS表请手动迁移数据
            try migrationData(from: tempTable)
        }
        if general && (indexChanged || !exist) {
            try rebuildIndex()
        }
        created = true
    }

    /// 重命名表
    ///
    /// - Parameter tempTable: 临时表名
    /// - Throws: 重命名过程中的错误
    func rename(to tempTable: String) throws {
        let sql = "ALTER TABLE \(table.quoted) RENAME TO \(tempTable.quoted)"
        try db.run(sql)
    }

    /// 创建表
    ///
    /// - Throws: 创建表过程中的错误
    public func createTable() throws {
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

    /// 从旧表迁移数据至新表
    ///
    /// - Parameter tempTable: 旧表(临时表)
    /// - Attention: FTS表需手动迁移数据
    /// - Throws: 迁移过程中的错误
    func migrationData(from tempTable: String) throws {
        let columnsSet = NSMutableOrderedSet(array: config.columns)
        columnsSet.intersectSet(Set(tableConfig.columns))
        let columns = columnsSet.array as! [String]

        let fields = columns.joined(separator: ",")
        guard fields.count > 0 else {
            return
        }
        let sql = "INSERT INTO \(table.quoted) (\(fields)) SELECT \(fields) FROM \(tempTable.quoted)"
        let drop = "DROP TABLE IF EXISTS \(tempTable.quoted)"
        try db.run(sql)
        try db.run(drop)
    }

    /// 重建索引
    ///
    /// - Throws: 重建索引过程中的错误
    func rebuildIndex() throws {
        guard config is PlainConfig else {
            return
        }
        // 删除旧索引
        var dropIdxSQL = ""
        let indexesSQL = "SELECT name FROM sqlite_master WHERE type ='index' and tbl_name = \(table.quoted)"
        let array = db.query(indexesSQL)
        for dic in array {
            let name = (dic["name"] as? String) ?? ""
            if !name.hasPrefix("sqlite_autoindex_") {
                dropIdxSQL += "DROP INDEX IF EXISTS \(name.quoted);"
            }
        }
        guard config.indexes.count > 0 else {
            return
        }
        // 建立新索引
        let indexName = "orm_index_\(table)"
        let indexesString = config.indexes.joined(separator: ",")
        let createSQL = indexesSQL.count > 0 ? "CREATE INDEX IF NOT EXISTS \(indexName.quoted) on \(table.quoted) (\(indexesString));" : ""
        if indexesSQL.count > 0 {
            if dropIdxSQL.count > 0 {
                try db.run(dropIdxSQL)
            }
            if createSQL.count > 0 {
                try db.run(createSQL)
            }
        }
    }
}
