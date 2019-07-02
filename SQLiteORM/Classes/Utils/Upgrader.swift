//
//  Upgrader.swift
//  SQLiteORM
//
//  Created by Valo on 2019/7/2.
//

import Foundation

public final class Upgrader {
    public typealias Upgrade = (Progress?) -> Void

    public var versions: [String] = []
    private var upgrades: [String: Upgrade] = [:]

    public var lastVersionKey: String = "SQLiteORMLastVersionKey"
    public var lastVersionSetter: (String, String) -> Void = { UserDefaults.standard.set($1, forKey: $0) }
    public var lastVersionGetter: (String) -> String = { UserDefaults.standard.object(forKey: $0) as? String ?? "" }

    public func upgrade(_ progress: Progress?) {
        guard versions.count > 0 else { return }

        let last = lastVersionGetter(lastVersionKey)
        upgrade(progress, form: last)
        lastVersionSetter(lastVersionKey, versions.last!)
    }

    public func upgrade(_ progress: Progress?, form version: String) {
        guard versions.count > 0 else { return }

        let ver = Version(version)
        var prev = Version("")
        var idx = 0
        for i in 0 ..< versions.count {
            let cur = Version(versions[i])
            if ver >= prev && ver < cur {
                idx = i
                break
            }
            prev = cur
        }

        var blocks: [Upgrade] = []
        for i in idx ..< versions.count {
            let block = upgrades[versions[i]]
            if block == nil { continue }
            blocks.append(block!)
        }

        for block in blocks {
            var sub: Progress?
            if progress != nil {
                sub = Progress(totalUnitCount: 100, parent: progress!, pendingUnitCount: progress!.totalUnitCount / Int64(blocks.count))
            }
            block(sub)
        }
    }

    private struct Version {
        private var value: String

        init(_ value: String) {
            self.value = value
        }

        private static func compare(_ version1: String, _ version2: String) -> ComparisonResult {
            let charset = CharacterSet(charactersIn: ".-_")
            let array1 = version1.components(separatedBy: charset)
            let array2 = version2.components(separatedBy: charset)
            let count = min(array1.count, array2.count)
            for i in 0 ..< count {
                let str1 = array1[i]
                let str2 = array2[i]
                let ret = str1.compare(str2)
                guard ret == .orderedSame else { return ret }
            }

            return array1.count < array2.count ? .orderedAscending : array1.count == array2.count ? .orderedSame : .orderedDescending
        }

        static func == (lhs: Version, rhs: Version) -> Bool {
            return compare(lhs.value, rhs.value) == .orderedSame
        }

        static func >= (lhs: Version, rhs: Version) -> Bool {
            let ret = compare(lhs.value, rhs.value)
            return ret == .orderedSame || ret == .orderedDescending
        }

        static func <= (lhs: Version, rhs: Version) -> Bool {
            let ret = compare(lhs.value, rhs.value)
            return ret == .orderedSame || ret == .orderedAscending
        }

        static func > (lhs: Version, rhs: Version) -> Bool {
            return compare(lhs.value, rhs.value) == .orderedDescending
        }

        static func < (lhs: Version, rhs: Version) -> Bool {
            return compare(lhs.value, rhs.value) == .orderedAscending
        }
    }
}
