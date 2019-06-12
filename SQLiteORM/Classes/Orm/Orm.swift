//
//  Orm.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/7.
//

import Foundation
import Runtime

public final class Orm {
    /// 配置
    public let config: Config

    /// 数据库
    public let db: Database

    /// 表名
    public let table: String

    /// 属性
    public let properties: [String: PropertyInfo]

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

    /// 初始化ORM
    ///
    /// - Parameters:
    ///   - config: 配置
    ///   - db: 数据库
    ///   - table: 表
    ///   - flag: 是否检查并创建表.某些场景需延迟创建表
    public init(config: Config, db: Database = (Database(.temporary)), table: String = "", setup flag: Bool = true) {
        guard config.type != nil && config.columns.count > 0 else {
            fatalError("invalid config")
        }
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
        if flag {
            try? setup()
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

        let tableConfig = Config.factory(table, db: db)
        switch (tableConfig, config) {
        case let (tableConfig as GeneralConfig, config as GeneralConfig):
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
        let exist = options.contains(.exist)
        let changed = options.contains(.tableChanged)
        let indexChanged = options.contains(.indexChanged)
        let general = config is GeneralConfig

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
    }

    /// 重命名表
    ///
    /// - Parameter tempTable: 临时表名
    /// - Throws: 重命名过程中的错误
    func rename(to tempTable: String) throws {
        let sql = "ALTER TABLE \(table.quoted) RENAME TO \(tempTable.quoted)"
        try db.execute(sql)
    }

    /// 创建表
    ///
    /// - Throws: 创建表过程中的错误
    func createTable() throws {
        let sql = config.createSQL(with: table)
        try db.execute(sql)
    }

    /// 从旧表迁移数据至新表
    ///
    /// - Parameter tempTable: 旧表(临时表)
    /// - Attention: FTS表需手动迁移数据
    /// - Throws: 迁移过程中的错误
    func migrationData(from tempTable: String) throws {
        let fields = config.columns.joined(separator: ",")
        guard fields.count > 0 else {
            return
        }
        let sql = "INSERT INTO \(table.quoted) (\(fields)) SELECT \(fields) FROM \(tempTable.quoted)"
        let drop = "DROP TABLE IF EXISTS \(tempTable.quoted)"
        try db.execute(sql)
        try db.execute(drop)
    }

    /// 重建索引
    ///
    /// - Throws: 重建索引过程中的错误
    func rebuildIndex() throws {
        guard config is GeneralConfig else {
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
        // 建立新索引
        let indexName = "sqlite_orm_index_\(table)"
        let indexesString = config.indexes.joined(separator: ",")
        let createSQL = indexesSQL.count > 0 ? "CREATE INDEX \(indexName.quoted) on \(table.quoted) (\(indexesString));" : ""
        if indexesSQL.count > 0 {
            if dropIdxSQL.count > 0 {
                try db.execute(dropIdxSQL)
            }
            if createSQL.count > 0 {
                try db.execute(createSQL)
            }
        }
    }

    /// 生成约束条件
    ///
    /// - Parameter item: 数据
    /// - Returns: 约束条件
    public func uniqueCondition(for item: Any) -> Where {
        var condition = [String: Binding]()
        switch config {
        case let config as GeneralConfig:
            if config.primaries.count > 0 {
                var dic = [String: Binding]()
                for pk in config.primaries {
                    let prop = properties[pk]
                    let val = try? prop?.get(from: item) as? Binding
                    if val != nil { dic[pk] = val! }
                }
                if dic.count == config.primaries.count {
                    condition = dic
                }
            }
            for unique in config.uniques {
                let prop = properties[unique]
                let val = try? prop?.get(from: item) as? Binding
                if val != nil {
                    condition = [unique: val!]
                }
            }
        default: break
        }
        return Where(condition)
    }
}
