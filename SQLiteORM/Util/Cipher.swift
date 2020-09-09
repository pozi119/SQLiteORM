//
//  Cipher.swift
//  SQLiteORM
//
//  Created by Valo on 2019/7/2.
//

import Foundation

#if SQLITE_HAS_CODEC
    import SQLCipher
#elseif os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

#if SQLITE_HAS_CODEC
    public final class Cipher {
        class func encrypt(_ path: String, key: String = "") -> Bool {
            return crypt(path, key: key, encrypt: true)
        }

        class func decrypt(_ path: String, key: String = "") -> Bool {
            return crypt(path, key: key, encrypt: false)
        }

        class func recrypt(_ path: String, oldKey: String, newKey: String = "") -> Bool {
            switch (oldKey.count, newKey.count) {
                case (0, 0): return true
                case (0, _): return encrypt(path, key: newKey)
                case (_, 0): return decrypt(path, key: oldKey)
                default:
                    let sqls = ["PRAGMA key = '\(oldKey)';", "PRAGMA rekey = '\(newKey)';"]
                    return exec(path, sqls: sqls)
            }
        }

        private class func crypt(_ path: String, key: String, encrypt flag: Bool) -> Bool {
            guard key.count > 0 else { return false }

            let target = (path as NSString).appendingPathExtension(".tmp") ?? (path + ".tmp")
            var sqls: [String]
            if flag {
                sqls = ["ATTACH DATABASE '\(path)' AS encrypted KEY '\(key)';",
                        "SELECT sqlcipher_export('encrypted');",
                        "DETACH DATABASE encrypted;"]
            } else {
                sqls = ["ATTACH DATABASE '\(path)' AS plaintext KEY '';",
                        "SELECT sqlcipher_export('plaintext');",
                        "DETACH DATABASE plaintext;"]
            }

            guard exec(path, sqls: sqls) else { return false }

            let fm = FileManager.default
            do {
                try fm.removeItem(atPath: path)
                try fm.moveItem(atPath: target, toPath: path)
            } catch _ {
                return false
            }
            return true
        }

        private class func exec(_ path: String, sqls: [String]) -> Bool {
            var handle: OpaquePointer?
            guard sqlite3_open(path, &handle) == SQLITE_OK else { return false }
            var ret = true
            for sql in sqls {
                let rc = sqlite3_exec(handle, sql, nil, nil, nil)
                if !(rc == SQLITE_OK || rc == SQLITE_DONE) {
                    ret = false
                    break
                }
            }
            sqlite3_close(handle)
            return ret
        }
    }
#endif
