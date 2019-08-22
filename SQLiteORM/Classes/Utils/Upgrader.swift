//
//  Upgrader.swift
//  SQLiteORM
//
//  Created by Valo on 2019/7/2.
//

import Foundation

fileprivate extension String {
    private static let delimiterSet = CharacterSet(charactersIn: ".-_")

    func versionCompare(_ other: String) -> ComparisonResult {
        let array1 = components(separatedBy: String.delimiterSet)
        let array2 = other.components(separatedBy: String.delimiterSet)
        let count = min(array1.count, array2.count)
        for i in 0 ..< count {
            let str1 = array1[i]
            let str2 = array2[i]
            let ret = str1.versionCompare(str2)
            guard ret == .orderedSame else { return ret }
        }

        return array1.count < array2.count ? .orderedAscending : array1.count == array2.count ? .orderedSame : .orderedDescending
    }
}

public final class Upgrader {
    struct Item {
        var target: NSObjectProtocol?
        var action: Selector?
        var handler: ((Progress) -> Void)?
        var version: String = ""
        var stage: UInt = 0
        var progress: Progress = Progress(totalUnitCount: 100)

        init() {}

        func compare(_ other: Item) -> ComparisonResult {
            let result = version.versionCompare(other.version)
            guard result != .orderedSame else { return result }
            return stage < other.stage ? .orderedAscending : (stage == other.stage ? .orderedSame : .orderedDescending)
        }

        static func < (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) == .orderedAscending
        }

        static func > (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) == .orderedDescending
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) == .orderedSame
        }

        static func <= (lhs: Item, rhs: Item) -> Bool {
            let result = lhs.compare(rhs)
            return result == .orderedAscending || result == .orderedSame
        }

        static func >= (lhs: Item, rhs: Item) -> Bool {
            let result = lhs.compare(rhs)
            return result == .orderedDescending || result == .orderedSame
        }
    }

    var versionKey = "sqliteorm.upgrader.lastversion"
    var progress = Progress(totalUnitCount: 100)

    private var items: [Item] = []
    private var stagesItems: [UInt: [Item]] = [:]
    private var stages: [UInt] = []
    private var pretreated = false

    var needUpgrade: Bool {
        pretreat()
        return stagesItems.count > 0
    }

    init(versionKey: String) {
        self.versionKey = versionKey
    }

    func add(target: NSObjectProtocol, action: Selector, for stage: UInt, version: String) {
        var item = Item()
        item.target = target
        item.action = action
        item.stage = stage
        item.version = version
        items.append(item)
    }

    func add(handler: @escaping (Progress) -> Void, for stage: UInt, version: String) {
        var item = Item()
        item.handler = handler
        item.stage = stage
        item.version = version
        items.append(item)
    }

    func upgradeAll() {
        pretreat()
        for stage in stages {
            upgrade(stage: stage)
        }
    }

    func upgrade(stage: UInt, from fromVersion: String = "", to toVersion: String = "") {
        pretreat()

        let subItems = stagesItems[stage] ?? []
        var todos: [Item] = []
        for item in subItems {
            if (fromVersion.count > 0 && item.version.compare(fromVersion).rawValue < ComparisonResult.orderedSame.rawValue)
                || (toVersion.count > 0 && item.version.compare(toVersion).rawValue > ComparisonResult.orderedSame.rawValue) {
                continue
            }
            todos.append(item)
        }

        guard todos.count > 0 else { return }

        for item in todos {
            if item.target != nil && item.action != nil {
                if item.target!.responds(to: item.action!) {
                    item.target!.perform(item.action!, with: item.progress)
                }
            } else if item.handler != nil {
                item.handler!(item.progress)
            }
            item.progress.completedUnitCount = item.progress.totalUnitCount
        }

        // record last version
        if stage == stages.last! {
            let last = stagesItems[stage]!.last!
            if last == todos.last! {
                progress.completedUnitCount = progress.totalUnitCount
                UserDefaults.standard.set(last.version, forKey: versionKey)
            }
        }
    }

    private func pretreat() {
        guard pretreated == false else { return }

        let defaults = UserDefaults.standard
        let lastVersion = defaults.object(forKey: versionKey) as? String ?? ""

        items.sort { $0 < $1 }

        var dic: [UInt: [Item]] = [:]
        for item in items {
            let result = item.version.versionCompare(lastVersion)
            if result.rawValue <= ComparisonResult.orderedSame.rawValue { continue }
            var sub = dic[item.stage] ?? [Item]()
            sub.append(item)
            dic[item.stage] = sub
        }

        stagesItems = dic
        stages = dic.keys.sorted { $0 < $1 }

        for stage in stages {
            let stageProgress = Progress(totalUnitCount: 100)
            progress.addChild(stageProgress, withPendingUnitCount: Int64(100 / stages.count))
            let subItems = dic[stage]!
            for item in subItems {
                stageProgress.addChild(item.progress, withPendingUnitCount: Int64(100 / subItems.count))
            }
        }

        pretreated = true
    }
}
