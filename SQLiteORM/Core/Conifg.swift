//
//  Conifg.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/6.
//

import AnyCoder
import Foundation
import Runtime

public class Config {
    public static let createAt: String = "createAt"
    public static let updateAt: String = "updateAt"

    fileprivate var allColumns: [String] = []

    fileprivate var allTypes: [String: String] = [:]

    /// type of struct / class that generates config. Nil for creating from table
    public var type: Any.Type?

    /// create from table or not
    public var fromTable: Bool = false

    /// all fileds
    public var columns: [String] = []

    /// primary keys
    public var primaries: [String] = []

    /// white list
    public var whites: [String] = []

    /// black list
    public var blacks: [String] = []

    /// index fileds, when fts indexes count is 0, all fields are indexed by default
    public var indexes: [String] = []

    /// the storage type corresponding to the field
    public var types: [String: String] = [:]

    /// initialize from some type
    public init(_ type: Any.Type) {
        self.type = type
        let info: TypeInfo = try! typeInfo(of: type)

        var columns = [String]()
        var types = [String: String]()
        switch info.kind {
        case .class, .struct:
            for prop in info.properties {
                columns.append(prop.name)
                types[prop.name] = sqlType(of: prop.type)
            }

        default:
            assert(false, "unsupported type")
        }
        self.columns = columns
        self.types = types

        allColumns = columns
        allTypes = types
    }

    /// initilalize form table
    init(table: String, db: Database) {
        fromTable = true
    }

    /// initilalize form table, class function
    /// - Returns: general configuration / fts configuration
    public class func factory(_ table: String, db: Database) -> Config {
        let fts = db.isFts(table)
        if fts {
            return FtsConfig(table: table, db: db)
        }
        return PlainConfig(table: table, db: db)
    }

    /// pretreatement
    public func treate() {
        whites = Array(Set(whites))
        blacks = Array(Set(blacks))

        let orderedSet = NSMutableOrderedSet(array: allColumns)
        if whites.count > 0 {
            orderedSet.intersectSet(Set(whites))
        } else if blacks.count > 0 {
            orderedSet.minusSet(Set(blacks))
        }
        columns = orderedSet.array as! [String]

        orderedSet.intersectSet(Set(indexes))
        indexes = orderedSet.array as! [String]
    }

    func sqlToCreate(table: String) -> String {
        return ""
    }
}

/// general configuration
public final class PlainConfig: Config {
    fileprivate var allDfltVals: [String: Primitive] = [:]

    /// record creation / modification time or not
    public var logAt: Bool = false

    /// is it an auto increment primary key, only valid if the number of primary keys is 1
    public var pkAutoInc: Bool = false

    /// not null fileds
    public var notnulls: [String] = []

    /// unique fileds
    public var uniques: [String] = []

    /// default value corresponding to the field
    public var dfltVals: [String: Primitive] = [:]

    /// initialize from some type
    override public init(_ type: Any.Type) {
        super.init(type)
    }

    /// initialize from table
    override init(table: String, db: Database) {
        super.init(table: table, db: db)
        var columns = [String]()
        var primaries = [String]()
        var notnulls = [String]()
        var uniques = [String]()
        var indexes = [String]()

        var types = [String: String]()
        var dfltVals = [String: Primitive]()

        // get table configuration
        let tableInfoSql = "PRAGMA table_info = \(table.quoted);"
        let infos = db.query(tableInfoSql)
        for dic in infos {
            let name = dic["name"] as? String ?? ""
            let type = dic["type"] as? String ?? ""
            let notnull = (dic["notnull"] as? Int64 ?? 0) > 0
            let dflt_value = dic["dflt_value"]
            let pk = (dic["pk"] as? Int64 ?? 0) > 0

            columns.append(name)
            types[name] = type
            dfltVals[name] = dflt_value
            if pk { primaries.append(name) }
            if notnull { notnulls.append(name) }
        }

        // get index configuration
        let indexListSql = "PRAGMA index_list = \(table.quoted);"
        let indexList = db.query(indexListSql)
        for dic in indexList {
            let idxname = dic["name"] as? String ?? ""
            let unique = (dic["unique"] as? Int64 ?? 0) > 0

            let indexInfoSql = "PRAGMA index_info = \(idxname.quoted);"
            let indexInfos = db.query(indexInfoSql)
            for idxinfo in indexInfos {
                let name = idxinfo["name"] as? String ?? ""
                if unique {
                    uniques.append(name)
                } else {
                    indexes.append(name)
                }
            }
        }

        // get primary key configuration
        var pkAutoInc = false
        if primaries.count > 0 {
            let sql = "SELECT * FROM sqlite_master WHERE tbl_name = \(table.quoted) AND type = 'table'"
            let cols = db.query(sql)
            let tableSql = cols.first?["sql"] as? String ?? ""
            if tableSql.match("AUTOINCREMENT") { pkAutoInc = true }
        }

        let logAt = columns.contains(Config.createAt) && columns.contains(Config.updateAt)

        self.logAt = logAt
        self.pkAutoInc = pkAutoInc
        self.columns = columns
        self.primaries = primaries
        self.notnulls = notnulls
        self.indexes = indexes
        self.uniques = uniques

        self.types = types
        self.dfltVals = dfltVals

        allColumns = columns
        allTypes = types
        allDfltVals = dfltVals
    }

    /// pretreatement
    override public func treate() {
        super.treate()

        let primariesSet = NSMutableOrderedSet(array: columns)
        primariesSet.intersectSet(Set(primaries))
        primaries = primariesSet.array as! [String]

        notnulls = Array(Set(notnulls).intersection(columns).subtracting(primaries))
        uniques = Array(Set(uniques).intersection(columns).subtracting(primaries))

        let indexesSet = NSMutableOrderedSet(array: indexes)
        indexesSet.minusSet(Set(uniques))
        indexesSet.minusSet(Set(primaries))
        indexes = indexesSet.array as! [String]
        types = allTypes.filter { columns.contains($0.key) }
        dfltVals = allDfltVals.filter { columns.contains($0.key) }
    }

    /// compare index configuration
    func isIndexesEqual(_ other: PlainConfig) -> Bool {
        treate()
        return indexes == other.indexes
    }

    /// generate create sql for field
    /// - Returns: sql caluse
    func sqlToCreate(column: String) -> String {
        let typeString = types[column] ?? ""
        var pkString = ""
        if primaries.count == 1 && primaries.contains(column) {
            pkString = pkAutoInc ? " NOT NULL PRIMARY KEY AUTOINCREMENT" : " NOT NULL PRIMARY KEY"
        }
        let nullString = notnulls.contains(column) ? " NOT NULL" : ""
        let uniqueString = uniques.contains(column) ? " UNIQUE" : ""
        let defaultValue = dfltVals[column]
        let dfltString = defaultValue != nil ? " DEFAULT(\(String(describing: defaultValue)))" : ""
        return "\(column.quoted) " + typeString + pkString + nullString + uniqueString + dfltString
    }

    func sqlToAlert(column: String, table: String) -> String {
        return "ALTER TABLE \(table.quoted) ADD COLUMN " + sqlToCreate(column: column)
    }

    /// generate create sql for table
    override public func sqlToCreate(table: String) -> String {
        treate()
        var array = columns.map { sqlToCreate(column: $0) }
        if primaries.count > 1 {
            array.append("PRIMARY KEY (" + primaries.joined(separator: ",") + ")")
        }

        guard array.count > 0 else { return "" }

        let sql = array.joined(separator: ",")
        return "CREATE TABLE IF NOT EXISTS \(table.quoted) (\(sql))".strip
    }
}

/// FTS表配置
public final class FtsConfig: Config {
    /// fts module: fts3/fts4/fts5
    public var module: String = "fts5"

    /// tokenzier; such as: ascii,porter,nl,apple,sqliteorm
    public var tokenizer: String = ""

    /// fts version
    public var version: UInt {
        switch module {
        case let module where module.match("fts5"): return 5
        case let module where module.match("fts4"): return 4
        default: return 3
        }
    }

    /// initialize from some type
    override public init(_ type: Any.Type) {
        super.init(type)
    }

    /// initialize from table
    override init(table: String, db: Database) {
        super.init(table: table, db: db)

        let sql = "SELECT * FROM sqlite_master WHERE tbl_name = \(table.quoted) AND type = 'table'"
        let cols = db.query(sql)
        let tableSql = cols.first?["sql"] as? String ?? ""
        let options: NSString.CompareOptions = [.regularExpression, .caseInsensitive]

        var module = "fts3"
        var tokenizer = ""
        var columns = [String]()
        var indexes = [String]()

        // get fts moudle name, version
        var r = tableSql.range(of: " +fts.*\\(", options: options)
        if r != nil {
            let start = r!.lowerBound
            let end = tableSql.index(r!.upperBound, offsetBy: -1)
            module = String(tableSql[start ..< end]).trim
        }
        self.module = module
        let version = self.version

        // get fts tokenizer
        r = tableSql.range(of: "\\(.*\\)", options: options)
        assert(r != nil, "invalid fts table")
        let ftsOptionsString = String(tableSql[r!.lowerBound ..< r!.upperBound])
        let ftsOptions = ftsOptionsString.components(separatedBy: .init(charactersIn: ",)"))
        for optionStr in ftsOptions {
            if optionStr.match("tokenize *=.*") {
                let sr = optionStr.range(of: "=.*", options: options)
                let start = optionStr.index(sr!.lowerBound, offsetBy: 1)
                tokenizer = String(optionStr[start ..< optionStr.endIndex]).trim.replacingOccurrences(of: "'|\"", with: "", options: .regularExpression)
            }
        }
        // get table configuration
        let tableInfoSql = "PRAGMA table_info = \(table.quoted);"
        let infos = db.query(tableInfoSql)
        for dic in infos {
            let name = dic["name"] as? String ?? ""
            let regex = version == 5 ? "\(name.quoted) +UNINDEXED" : "notindexed *= *\(name.quoted)"
            if !tableSql.match(regex) {
                indexes.append(name)
            }
            columns.append(name)
        }

        self.tokenizer = tokenizer
        self.columns = columns
        self.indexes = indexes

        allColumns = columns
    }

    /// generate sql for create fts table
    public func sqlToCreate(table: String, content_table: String? = nil, content_rowid: String? = nil) -> String {
        if indexes.count == 0 {
            indexes = columns
        }
        treate()
        let notindexedsSet = NSMutableOrderedSet(array: columns)
        notindexedsSet.minusSet(Set(indexes))
        let notindexeds = notindexedsSet.array as! [String]

        var rows: [String] = columns.map { $0.quoted }
        if notindexeds.count > 0 {
            if version >= 5 {
                rows = columns.map { notindexeds.contains($0) ? $0.quoted + " UNINDEXED" : $0.quoted }
            } else if version == 4 {
                notindexeds.forEach { rows.append("notindexed=\($0.quoted)") }
            }
        }

        guard rows.count > 0 else { return "" }

        if tokenizer.count > 0 {
            rows.append(version < 5 ? "tokenize=\(tokenizer)" : "tokenize = '\(tokenizer)'")
        }
        if let con_tbl = content_table {
            rows.append("content='\(con_tbl)'")
            if let con_rowid = content_rowid, con_tbl.count > 0 && con_rowid.count > 0 {
                rows.append("content_rowid='\(con_rowid)'")
            }
        }

        let sql = rows.joined(separator: ",")

        return "CREATE VIRTUAL TABLE IF NOT EXISTS \(table.quoted) USING \(module)(\(sql))".strip
    }
}

extension Config: Equatable {
    public static func == (lhs: Config, rhs: Config) -> Bool {
        lhs.treate()
        rhs.treate()
        switch (lhs, rhs) {
        case let (lhs as PlainConfig, rhs as PlainConfig):
            var ldflt = [String: String]()
            var rdflt = [String: String]()
            lhs.dfltVals.forEach { ldflt[$0.key] = String(describing: $0.value) }
            rhs.dfltVals.forEach { rdflt[$0.key] = String(describing: $0.value) }
            return lhs.pkAutoInc == rhs.pkAutoInc &&
                lhs.columns === rhs.columns &&
                lhs.types == rhs.types &&
                lhs.primaries === rhs.primaries &&
                lhs.notnulls === rhs.notnulls &&
                lhs.uniques === rhs.uniques &&
                ldflt == rdflt

        case let (lhs as FtsConfig, rhs as FtsConfig):
            return lhs.module == rhs.module &&
                lhs.tokenizer == rhs.tokenizer &&
                lhs.columns === rhs.columns &&
                lhs.indexes === rhs.indexes

        default: return false
        }
    }
}
