//
//  Upgrader.swift
//  SQLiteORM
//
//  Created by Valo on 2019/7/2.
//

import Foundation

fileprivate extension String {
    private static let delimiterSet = CharacterSet(charactersIn: ".-_")

    func compare(version other: String) -> Int {
        let array1 = components(separatedBy: String.delimiterSet)
        let array2 = other.components(separatedBy: String.delimiterSet)
        let count = min(array1.count, array2.count)
        for i in 0 ..< count {
            let str1 = array1[i]
            let str2 = array2[i]
            let ret = str1.compare(str2)
            guard ret == .orderedSame else { return ret.rawValue }
        }

        return array1.count < array2.count ? -1 : array1.count == array2.count ? 0 : 1
    }
}

public extension Upgrader {
    class Item: Comparable, CustomStringConvertible {
        public var id: String = ""
        public var version: String = ""
        public var stage: UInt = 0

        public var priority: Float = 0.5
        public var weight: Float = 1.0
        public var progress: Float = 0.0 { didSet { observer?(self) } }
        public var record: Bool = true

        public var reserved: Any?

        public var handler: (Item) -> Bool
        fileprivate var observer: ((Item) -> Void)?

        init(id: String, version: String, stage: UInt = 0, handler: @escaping (Item) -> Bool) {
            self.id = id
            self.version = version
            self.stage = stage
            self.handler = handler
        }

        public func copy() -> Item {
            let item = Item(id: id, version: version, stage: stage, handler: handler)
            item.progress = 0
            item.priority = priority
            item.weight = weight
            item.record = record
            item.reserved = reserved
            return item
        }

        public var description: String {
            return String(format: "id:'%@', stage:%i, version:'%@', priority:%.2f, weight:%.2f, progress:%.2f", id, stage, version, priority, weight, progress)
        }

        // MARK: Comparable

        func compare(_ other: Item) -> Int {
            var result = stage < other.stage ? -1 : (stage == other.stage ? 0 : 1)
            guard result == 0 else { return result }
            result = version.compare(version: other.version)
            guard result == 0 else { return result }
            return priority > other.priority ? -1 : (stage == other.stage ? 0 : 1)
        }

        public static func < (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) < 0
        }

        public static func > (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) > 0
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) == 0
        }

        public static func <= (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) <= 0
        }

        public static func >= (lhs: Item, rhs: Item) -> Bool {
            return lhs.compare(rhs) >= 0
        }
    }
}

public class Upgrader: NSObject {
    private let completeInfoKeySuffix = "-lastCompleted"
    private var completeInfoKey: String = "com.valo.upgrader.lastversion-lastCompleted"
    private var stagesItems: [UInt: [Item]] = [:]
    private var updateItems: [UInt: [Item]] = [:]
    private var completedInfo: [String: Bool] = [:]
    private var versions: Set<String> = Set()
    private var stages: Set<UInt> = Set()
    private var pretreated = false
    private static let accuracy: Float = 100.0

    public var versionKey = "com.valo.upgrader.lastversion" {
        didSet { completeInfoKey = versionKey + completeInfoKeySuffix }
    }

    public let progress = Progress(totalUnitCount: 100)

    private(set) var upgrading = false

    public var needUpgrade: Bool {
        pretreat()
        return stagesItems.count > 0
    }

    override public init() {}

    public init(versionKey: String) {
        self.versionKey = versionKey
    }

    public func reset() {
        pretreated = false
        progress.completedUnitCount = 0
        updateItems.values.forEach { $0.forEach { $0.progress = 0.0 } }
    }

    public func add(_ item: Item) {
        item.observer = { _ in
            let items = self.updateItems.values.reduce([]) { $0 + $1 }
            let completedWeight = items.reduce(0.0) { $0 + $1.weight * $1.progress }
            self.progress.completedUnitCount = Int64(completedWeight * Upgrader.accuracy)
        }
        add(item, to: &stagesItems)
        versions.insert(item.version)
        stages.insert(item.stage)
        pretreated = false
    }

    public func add(_ items: [Item]) {
        items.forEach { add($0) }
    }

    private func add(_ item: Item, to container: inout [UInt: [Item]]) {
        assert(item.version.count > 0, "Invalid upgrade item.")
        if let items = container[item.stage] {
            container[item.stage] = items + [item]
        } else {
            container[item.stage] = [item]
        }
    }

    public func upgrade() {
        pretreat()
        updateItems.keys.sorted().forEach { upgrade(stage: $0) }
    }

    public func upgrade(stage: UInt) {
        pretreat()
        upgrade(items: updateItems[stage] ?? [])
    }

    public func debug(upgrade items: [Item], progress: Progress) {
        guard !upgrading else { return }
        upgrading = true
        let sorted = items.map { $0.copy() }.sorted()
        sorted.forEach { item in
            item.observer = { _ in
                let completedWeight = sorted.reduce(0.0) { $0 + $1.weight * $1.progress }
                progress.completedUnitCount = Int64(completedWeight * Upgrader.accuracy)
            }
        }
        let totalWeight = sorted.reduce(0.0) { $0 + $1.weight }
        progress.totalUnitCount = Int64(totalWeight * Upgrader.accuracy)
        progress.completedUnitCount = 0
        sorted.forEach { _ = upgrade(item: $0) }
        upgrading = false
    }

    // MARK: - private

    private func pretreat() {
        guard !pretreated else { return }

        updateItems.removeAll()
        let defaults = UserDefaults.standard
        let from = defaults.string(forKey: versionKey) ?? ""
        let to = versions.sorted { $0.compare(version: $1) >= 0 }.first ?? ""

        guard from.count > 0, to.count > 0, from.compare(version: to) < 0 else {
            pretreated = true
            return
        }

        completedInfo = (defaults.object(forKey: completeInfoKey) as? [String: Bool]) ?? [:]
        var totalWeight: Float = 0.0
        for (_, items) in stagesItems {
            for item in items {
                if from.compare(version: item.version) >= 0 { continue }
                if item.record {
                    let completed = completedInfo[item.id] ?? false
                    if completed {
                        item.progress = 1.0
                        continue
                    }
                }
                add(item, to: &updateItems)
                totalWeight = totalWeight + item.weight
            }
        }
        progress.totalUnitCount = Int64(totalWeight * Upgrader.accuracy)
        progress.completedUnitCount = 0
        pretreated = true
    }

    private func upgrade(items: [Item]) {
        guard !upgrading else { return }
        upgrading = true
        pretreat()
        let sorted = items.sorted()
        sorted.forEach { if upgrade(item: $0) { complete($0) } }
        upgrading = false
    }

    private func upgrade(item: Item) -> Bool {
        guard item.progress < 1.0 else { return true }
        let ret = item.handler(item)
        if ret { item.progress = 1.0 }
        return ret
    }

    private func complete(_ item: Item) {
        var completedAll = true
        for (_, items) in updateItems {
            for item in items {
                if item.progress < 1.0 {
                    completedAll = false
                    break
                }
            }
        }
        let defaults = UserDefaults.standard
        if completedAll {
            let last = versions.sorted().last ?? ""
            defaults.set(last, forKey: versionKey)
            defaults.removeObject(forKey: completeInfoKey)
            defaults.synchronize()
        } else if item.record {
            completedInfo[item.id] = true
            defaults.set(completedInfo, forKey: completeInfoKey)
            defaults.synchronize()
        }
    }
}
