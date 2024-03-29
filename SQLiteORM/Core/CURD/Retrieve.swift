//
//  Retrieve.swift
//  SQLiteORM
//
//  Created by Valo on 2022/9/28.
//

import AnyCoder
import Foundation

// MARK: - Retrieve

public class Retrieve<T>: Select {
    private let type: T.Type

    public required init(_ orm: Orm<T>) {
        type = T.self
        super.init()
        self.orm { orm }
    }

    public func allItems() -> [T] {
        return allKeyValues().toItems(T.self)
    }

    public func one() -> T? {
        limit { 1 }.allItems().first
    }
}

public extension Orm {
    /// maximum rowid. the maximum rowid, auto increment primary key and records count may not be the same
    var maxRowId: Int64 {
        return max(of: "rowid") as? Int64 ?? 0
    }

    /// find a record, not decoded
    ///
    /// - Parameters:
    /// - Returns: [String:Primitive], decoding with ORMDecoder
    func find() -> Retrieve<T> {
        return Retrieve(self)
    }

    /// get number of records
    func count(_ condition: (() -> String)? = nil) -> Int64 {
        return function("count(*)", condition: condition) as? Int64 ?? 0
    }

    /// check if a record exists
    func exist(_ item: T) -> Bool {
        let condition = constraint(for: item, config)
        guard !condition.isEmpty else { return false }
        return count { condition.toWhere() } > 0
    }

    /// check if a record exists
    func exist(_ keyValues: [String: Primitive]) -> Bool {
        return count { keyValues.toWhere() } > 0
    }

    /// check if a record exists
    func exist(_ condition: (() -> String)? = nil) -> Bool {
        return count(condition) > 0
    }

    /// get the maximum value of a field
    func max(of field: String, condition: (() -> String)? = nil) -> Primitive? {
        return function("max(\(field))", condition: condition)
    }

    /// get the minimum value of a field
    func min(of field: String, condition: (() -> String)? = nil) -> Primitive? {
        return function("min(\(field))", condition: condition)
    }

    /// get the sum value of a field
    func sum(of field: String, condition: (() -> String)? = nil) -> Primitive? {
        return function("sum(\(field))", condition: condition)
    }

    /// execute a function, such as: max(),min(),sum()
    ///
    /// - Parameters:
    ///   - function: function name
    /// - Returns: function result
    func function(_ function: String, condition: (() -> String)? = nil) -> Primitive? {
        let retrieve = find().fields { function }
        if let condition = condition {
            retrieve.where(condition)
        }
        let dic = retrieve.allKeyValues().first
        return dic?.values.first
    }
}
