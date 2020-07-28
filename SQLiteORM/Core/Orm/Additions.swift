//
//  Additions.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/10.
//

import Foundation

extension Database {
    /// database pool
    private static let pool = NSMapTable<NSString, Database>.strongToWeakObjects()

    /// create database from the pool,  if it exists, take it out directly. Otherwise, create it and put it into the pool
    ///
    /// - Parameters:
    ///   - location: database file path
    ///   - flags: flags for opening database
    ///   - encrypt: encryption key
    /// - Returns: database
    public class func fromPool(_ location: Location = .temporary, flags: Int32 = 0, encrypt: String = "") -> Database {
        let udid = location.description + "\(flags)" + encrypt as NSString
        if let db = pool.object(forKey: udid) {
            return db
        }

        let db = Database(location, flags: flags, encrypt: encrypt)
        pool.setObject(db, forKey: udid)
        return db
    }
}
