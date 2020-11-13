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
        class func encrypt(_ source: String, target: String = "", key: String = "", options: [String] = []) -> Bool {
            return change(source, target: target, tarKey: key, tarOpts: options)
        }

        class func decrypt(_ source: String, target: String = "", key: String = "", options: [String] = []) -> Bool {
            return change(source, target: target, srcKey: key, srcOpts: options)
        }

        class func change(_ source: String, target: String = "",
                          srcKey: String = "", srcOpts: [String] = [],
                          tarKey: String = "", tarOpts: [String] = []) -> Bool {
            guard source.count > 0, target.count > 0, source != target else { return true }

            let xTarget = target.count > 0 ? target : (source + "-tmpcipher")
            let dir = (xTarget as NSString).deletingLastPathComponent
            let fm = FileManager.default
            var isdir: ObjCBool = false
            let exist = fm.fileExists(atPath: dir, isDirectory: &isdir)
            if !exist || !isdir.boolValue {
                do {
                    try fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    return false
                }
            }

            var handle: OpaquePointer?
            guard sqlite3_open(source, &handle) == SQLITE_OK else { return false }
            if srcKey.count > 0 {
                guard sqlite3_key(handle, srcKey, Int32(srcKey.count)) == SQLITE_OK else { return false }
            }

            let attach = "ATTACH DATABASE '\(xTarget)' AS tardb KEY '\(tarKey)'"
            let export = "BEGIN IMMEDIATE; SELECT sqlcipher_export('tardb'); COMMIT;"
            let detach = "DETACH DATABASE tardb;"
            let xSrcOpts = pretreat(srcOpts, db: "main")
            let xTarOpts = pretreat(tarOpts, db: "tardb")

            var sqls: [String] = []
            sqls.append(contentsOf: xSrcOpts)
            sqls.append(attach)
            sqls.append(contentsOf: xTarOpts)
            sqls.append(export)
            sqls.append(detach)

            var rc = SQLITE_OK
            for sql in sqls {
                rc = sqlite3_exec(handle, sql, nil, nil, nil)
                #if DEBUG
                    if rc == SQLITE_OK {
                        print("[Cipher][DEBUG] code: \(rc), sql: \(sql)")
                    } else {
                        print("[Cipher][Error] code: \(rc), sql: \(sql), error: \(String(describing: sqlite3_errmsg(handle)))")
                    }
                #endif
                if rc != SQLITE_OK { break }
            }
            sqlite3_close(handle)
            
            if rc == SQLITE_OK && target.count == 0 {
                do {
                    try fm.removeItem(atPath: source)
                    try fm.moveItem(atPath: xTarget, toPath: source)
                } catch {
                    return false
                }
            }
            return rc == SQLITE_OK
        }

        class func remove(dbfile: String) {
            let fm = FileManager.default
            let shm = dbfile + "-shm"
            let wal = dbfile + "-wal"
            try? fm.removeItem(atPath: dbfile)
            try? fm.removeItem(atPath: shm)
            try? fm.removeItem(atPath: wal)
        }

        class func move(dbfile srcPath: String, to dstPath: String, force: Bool = false) {
            guard srcPath.count > 0, dstPath.count > 0, srcPath != dstPath else { return }
            let fm = FileManager.default
            let dstDir = (dstPath as NSString).deletingLastPathComponent
            var isDir: ObjCBool = false
            let exist = fm.fileExists(atPath: dstPath, isDirectory: &isDir)
            if !exist || !isDir.boolValue {
                try? fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true, attributes: nil)
            }
            let srcshm = srcPath + "-shm"
            let srcwal = srcPath + "-wal"
            let dstshm = dstPath + "-shm"
            let dstwal = dstPath + "-wal"
            if force {
                try? fm.removeItem(atPath: dstPath)
                try? fm.removeItem(atPath: dstshm)
                try? fm.removeItem(atPath: dstwal)
            }
            try? fm.moveItem(atPath: srcPath, toPath: dstPath)
            try? fm.moveItem(atPath: srcshm, toPath: dstshm)
            try? fm.moveItem(atPath: srcwal, toPath: dstshm)
        }

        class func copy(dbfile srcPath: String, to dstPath: String, force: Bool = false) {
            guard srcPath.count > 0, dstPath.count > 0, srcPath != dstPath else { return }
            let fm = FileManager.default
            let dstDir = (dstPath as NSString).deletingLastPathComponent
            var isDir: ObjCBool = false
            let exist = fm.fileExists(atPath: dstPath, isDirectory: &isDir)
            if !exist || !isDir.boolValue {
                try? fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true, attributes: nil)
            }
            let srcshm = srcPath + "-shm"
            let srcwal = srcPath + "-wal"
            let dstshm = dstPath + "-shm"
            let dstwal = dstPath + "-wal"
            if force {
                try? fm.removeItem(atPath: dstPath)
                try? fm.removeItem(atPath: dstshm)
                try? fm.removeItem(atPath: dstwal)
            }
            try? fm.copyItem(atPath: srcPath, toPath: dstPath)
            try? fm.copyItem(atPath: srcshm, toPath: dstshm)
            try? fm.copyItem(atPath: srcwal, toPath: dstshm)
        }

        private class func crypt(_ path: String, key: String, encrypt flag: Bool) -> Bool {
            guard key.count > 0 else { return false }

            let target = path + "-tmpcipher"
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

            remove(dbfile: path)
            move(dbfile: target, to: path, force: true)
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

        private class func pretreat(_ options: [String], db: String = "") -> [String] {
            guard db.count > 0 else { return options }
            var results: [String] = []
            for option in options {
                let subopts = option.split(separator: ";")
                for subopt in subopts {
                    var valid = false
                    if let r0 = subopt.range(of: "pragma ", options: .caseInsensitive) {
                        if let r1 = subopt.range(of: "[a-z]|[A-Z]", options: .regularExpression, range: r0.upperBound ..< subopt.endIndex) {
                            var opt = String(subopt)
                            opt.insert(contentsOf: db + ".", at: r1.lowerBound)
                            opt += ";"
                            results.append(opt)
                            valid = true
                        }
                    }
                    if !valid {
                        #if DEBUG
                            print("[Cipher][DEBUG] invalid option: " + subopt)
                        #endif
                    }
                }
            }
            return results
        }
    }
#endif
