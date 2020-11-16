//
//  ViewController.swift
//  SQLiteORM
//
//  Created by Valo on 05/21/2019.
//  Copyright (c) 2019 Valo. All rights reserved.
//

import SQLiteORM
import UIKit

class TableViewController: UITableViewController {
    @IBOutlet var l100kLabel: UILabel!
    @IBOutlet var l1mLabel: UILabel!
    @IBOutlet var l10mLabel: UILabel!
    @IBOutlet var l100mLabel: UILabel!

    @IBOutlet var generateButton: UIButton!
    @IBOutlet var generateResultLabel: UILabel!
    @IBOutlet var generateProgressView: UIProgressView!
    @IBOutlet var generateProgressLabel: UILabel!

    @IBOutlet var keywordTextField: UITextField!
    @IBOutlet var searchButton: UIButton!
    @IBOutlet var searchFtsButton: UIButton!
    @IBOutlet var searchStatusLabel: UILabel!
    @IBOutlet var searchResultLabel: UILabel!
    @IBOutlet var searchIndicator: UIActivityIndicatorView!

    @IBOutlet var logTextView: UITableView!

    var items = [Item]()

    var selectedIndex = 0

    lazy var infos: [String] = {
        var _infos = [String]()
        autoreleasepool(invoking: { () -> Void in
            let path = Bundle.main.path(forResource: "神话纪元", ofType: "txt")!
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let set1: CharacterSet = .whitespacesAndNewlines
            let set2: CharacterSet = .punctuationCharacters
            let set = set1.union(set2)
            _infos = text.components(separatedBy: set).filter { $0.count > 0 }
        })
        return _infos
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        loadDetails()
    }

    func setup() {
        String.preloadingForPinyin()

        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let tableName = "message"

        let item1 = Item(dir: dir, tableName: tableName, dbName: "100k.db", ftsDbName: "f-100k.db", label: l100kLabel, maxCount: 100000)
        let item2 = Item(dir: dir, tableName: tableName, dbName: "1m.db", ftsDbName: "f-1m.db", label: l1mLabel, maxCount: 1000000)
        let item3 = Item(dir: dir, tableName: tableName, dbName: "10m.db", ftsDbName: "f-10m.db", label: l10mLabel, maxCount: 10000000)
        let item4 = Item(dir: dir, tableName: tableName, dbName: "100m.db", ftsDbName: "f-100m.db", label: l100mLabel, maxCount: 100000000)
        items = [item1, item2, item3, item4]

        let indexPath = IndexPath(row: selectedIndex, section: 0)
        tableView(tableView, didSelectRowAt: indexPath)
    }

    func loadDetails() {
        for i in 0 ..< items.count {
            loadDetails(for: i)
        }
    }

    func sizeString(for size: UInt64) -> String {
        let gb: UInt64 = 1 << 30
        let mb: UInt64 = 1 << 20
        let kb: UInt64 = 1 << 10
        switch size {
        case let size where size > gb:
            return String(format: "%.2f GB", Double(size) / Double(gb))
        case let size where size > mb:
            return String(format: "%.2f MB", Double(size) / Double(mb))
        default:
            return String(format: "%.2f KB", Double(size) / Double(kb))
        }
    }

    func loadDetails(for row: Int) {
        guard row >= 0 && row < items.count else { return }

        generateButton.isEnabled = false

        DispatchQueue.global(qos: .background).async {
            var item = self.items[row]

            let fm = FileManager.default
            let suffixes = ["", "-shm", "-wal"]
            var fileSize: UInt64 = 0
            var ftsFileSize: UInt64 = 0

            for suffix in suffixes {
                let path = item.dbPath + suffix
                let ftsPath = item.ftsDbPath + suffix
                let attrs = try? fm.attributesOfItem(atPath: path)
                let ftsAttrs = try? fm.attributesOfItem(atPath: ftsPath)
                fileSize += (attrs?[.size] as? UInt64 ?? 0)
                ftsFileSize += (ftsAttrs?[.size] as? UInt64 ?? 0)
            }
            item.fileSize = fileSize
            item.ftsFileSize = ftsFileSize
            item.count = UInt64(item.orm.count())

            DispatchQueue.main.async {
                let sizeText = self.sizeString(for: item.fileSize)
                let ftsSizeText = self.sizeString(for: item.ftsFileSize)
                item.label?.text = "[R] \(item.count), [N] \(sizeText), [FTS] \(ftsSizeText)"
                if row == self.selectedIndex {
                    let percent = item.maxCount > item.count ? (Double(item.count) / Double(item.maxCount)) : 1.0
                    self.generateProgressLabel.text = String(format: "%.2f%", percent * 100)
                    self.generateButton.isEnabled = item.count < item.maxCount
                }
            }
        }
    }

    @IBAction func reset(_ sender: Any) {
        let fm = FileManager.default
        for item in items {
            item.db.close()
            item.ftsDb.close()
            try? fm.removeItem(atPath: item.dbPath)
            try? fm.removeItem(atPath: item.ftsDbPath)
        }
        setup()
        loadDetails()
    }

    @IBAction func generateMessages(_ sender: Any) {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }

        let item = items[selectedIndex]

        updateUI(action: false, search: false, log: "")

        DispatchQueue.global(qos: .default).async {
            var mockTime: CFAbsoluteTime = 0
            var normalTime: CFAbsoluteTime = 0
            var ftsTime: CFAbsoluteTime = 0

            var startId = item.count
            let thousands = (item.maxCount - startId) / 1000
            let loop = thousands

            for _ in 0 ..< loop {
                autoreleasepool(invoking: { () -> Void in
                    let begin = CFAbsoluteTimeGetCurrent()
                    let messages = Message.mockThousand(with: self.infos, startId: startId)
                    let step1 = CFAbsoluteTimeGetCurrent()
                    item.orm.insert(multi: messages)
                    let step2 = CFAbsoluteTimeGetCurrent()
                    item.ftsOrm.insert(multi: messages)
                    let end = CFAbsoluteTimeGetCurrent()

                    let mock = step1 - begin
                    let normal = step2 - step1
                    let fts = end - step2

                    mockTime += mock
                    normalTime += normal
                    ftsTime += fts
                    startId += 1000

                    let progress = min(1.0, Float(startId) / Float(item.maxCount))
                    let progressText = String(format: "%6.2f%", progress * 100.0)

                    let desc = String(format: "[%6llu-%6llu]:%6.2f%%,mock: %.6f,normal:%.6f,fts:%.6f", startId - 1000, startId, progress * 100.0, mock, normal, fts)
                    print(desc)
                    DispatchQueue.main.async {
                        self.generateProgressView.progress = progress
                        self.generateProgressLabel.text = progressText
                    }
                })
            }
            let str = "[insert] \(thousands * 1000), mock: \(mockTime), normal: \(normalTime), fts: \(ftsTime)"
            print(str)
            DispatchQueue.main.async {
                self.loadDetails(for: self.selectedIndex)
                self.updateUI(action: true, search: false, log: str)
            }
        }
    }

    @IBAction func searchMessages(_ sender: Any) {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }

        let item = items[selectedIndex]
        let text = keywordTextField.text ?? ""
        let keyword = "*" + text + "*"
        guard text.count > 0 else { return }

        updateUI(action: false, search: true, log: "")
        DispatchQueue.global(qos: .background).async {
            let begin = CFAbsoluteTimeGetCurrent()
            let messages = item.orm.find(Where("info").glob(keyword))
            let end = CFAbsoluteTimeGetCurrent()
            let str = "[query] normal: \(keyword), hit: \(messages.count), consumed: \(end - begin)"
            print(str)
            DispatchQueue.main.async {
                self.updateUI(action: true, search: true, log: str)
            }
        }
    }

    @IBAction func searchFtsMessages(_ sender: Any) {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }

        let item = items[selectedIndex]
        let keyword = keywordTextField.text ?? ""

        guard keyword.count > 0 else { return }

        updateUI(action: false, search: true, log: "")
        let fts5keyword = keyword.fts5MatchPattern
        let fields = item.ftsOrm.fts5Highlight(of: ["info"])
        DispatchQueue.global(qos: .background).async {
            let begin = CFAbsoluteTimeGetCurrent()
            let select = Select().orm(item.ftsOrm).fields(Fields(fields)).where(Where(item.ftsOrm.table).match(fts5keyword)).limit(10)
            let messages = select.allItems(item.ftsOrm)
            let end = CFAbsoluteTimeGetCurrent()
            let str = "[query] fts: \(keyword), hit: \(messages.count), consumed: \(end - begin)"
            print(str)
            let highlights = messages.map { NSAttributedString(feature: $0.info, attibutes: [.foregroundColor: UIColor.red]) }
            if highlights.count > 0 {}
            DispatchQueue.main.async {
                self.updateUI(action: true, search: true, log: str)
            }
        }
    }

    func updateUI(action done: Bool, search: Bool, log: String) {
        if search {
            if done {
                searchIndicator.stopAnimating()
            } else {
                searchIndicator.startAnimating()
            }
            searchStatusLabel.text = done ? "搜索结果:" : "搜索中..."
            searchResultLabel.isHidden = !done
            searchResultLabel.text = log
        } else {
            generateProgressView.progress = done ? 1.0 : 0.0
            generateProgressLabel.text = done ? "100%" : ""
            generateProgressView.isHidden = done
            generateProgressLabel.isHidden = done
            generateResultLabel.text = log
        }

        searchButton.isEnabled = done
        searchFtsButton.isEnabled = done
        generateResultLabel.isHidden = !done
        if done {
            if selectedIndex < items.count {
                let item = items[selectedIndex]
                generateButton.isEnabled = item.count < item.maxCount
            }
        } else {
            generateButton.isEnabled = false
        }
    }
}

extension TableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        loadDetails(for: indexPath.row)
        selectedIndex = indexPath.row
        let rows = tableView.numberOfRows(inSection: 0)
        for i in 0 ..< rows {
            let cell = tableView.cellForRow(at: IndexPath(row: i, section: 0))
            cell?.accessoryType = i == selectedIndex ? .checkmark : .none
        }
    }
}
