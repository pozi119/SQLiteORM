//
//  Delete.swift
//  SQLiteORM
//
//  Created by Valo on 2022/9/28.
//

import AnyCoder
import Foundation

// MARK: - Delete

public extension Orm {
    /// delete a table
    ///
    /// - Attention: ffter deleting the table, if you need to access it again, please regenerate orm; **use caution**
    @discardableResult
    func drop() -> Bool {
        let sql = "DROP TABLE IF EXISTS \(table.quoted)"
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }

    /// delete a record
    ///
    /// - Attention: if the table has no primary key, all data in the table may be deleted;**use caution**
    @discardableResult
    func delete(_ item: T) -> Bool {
        let condition = constraint(for: item, config)
        guard condition.count > 0 else { return false }
        return delete { condition.toWhere() }
    }

    /// delete multi records
    ///
    /// - Attention: if the table has no primary key, all data in the table may be deleted;**use caution**
    @discardableResult
    func delete(_ items: [T]) -> Int64 {
        var count: Int64 = 0
        do {
            try db.transaction(block: {
                for item in items {
                    let ret = delete(item)
                    count += ret ? 1 : 0
                }
            })
        } catch _ {
            return count
        }
        return count
    }

    /// delete records according to condition
    @discardableResult
    func delete(where condition: (() -> String)? = nil) -> Bool {
        let clause = condition != nil ? condition!() : ""
        let sql = "DELETE FROM \(table.quoted)" + (clause.count > 0 ? " WHERE \(clause)" : "")
        do {
            try db.run(sql)
        } catch _ {
            return false
        }
        return true
    }
}
