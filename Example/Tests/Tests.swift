@testable import SQLiteORM
import XCTest

final class SQLiteORMTests: XCTestCase {
    fileprivate lazy var db: Database = {
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let url = URL(fileURLWithPath: dir).appendingPathComponent("test.db")
        return Database(with: url.path)
    }()

    fileprivate lazy var orm: Orm<Person> = {
        let config = PlainConfig(Person.self)
        config.primaries = ["id"]
        let orm = Orm<Person>(config: config, db: db, table: "person")
        return orm
    }()

    fileprivate lazy var view: View<Person> = {
        let config = PlainConfig(Person.self)
        config.primaries = ["id"]
        let view = View<Person>("xx", condition: "age > 20", orm: self.orm)
        return view
    }()

    fileprivate lazy var ftsDb: Database = {
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let url = URL(fileURLWithPath: dir).appendingPathComponent("testFts.db")
        let _db = Database(with: url.path)
        _db.register(OrmEnumerator.self, for: "sqliteorm")
        return _db
    }()

    fileprivate lazy var ftsOrm: Orm<Person> = {
        let config = FtsConfig(Person.self)
        config.module = "fts5"
        config.tokenizer = "sqliteorm"
        config.indexes = ["name", "intro"]

        let orm = Orm<Person>(config: config, db: ftsDb, table: "person")
        return orm
    }()

    fileprivate lazy var infos: [String] = {
        var _infos = [String]()
        autoreleasepool(invoking: { () in
            let path = Bundle.main.path(forResource: "神话纪元", ofType: "txt")!
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let set1: CharacterSet = .whitespacesAndNewlines
            let set2: CharacterSet = .punctuationCharacters
            let set = set1.union(set2)
            _infos = text.components(separatedBy: set).filter { $0.count > 0 }
        })
        return _infos
    }()

    static var allTests = [
        ("testConnection", testConnection),
    ]
}

// MARK: - Expression

extension SQLiteORMTests {
    func testWhereLogic() {
        let w1 = "name" |== "zhangsan"
        let w2 = "age" |== 22
        let w3 = w1 |&& w2
        let w4 = w3 ||| "age" |== 21
        let w5 = w4 |&& "name" |== "lisi"
        let w6 = w5 ||| "age" |== 20
        XCTAssertEqual(w1, "\"name\" == \"zhangsan\"")
        XCTAssertEqual(w2, "\"age\" == 22")
        XCTAssertEqual(w3, "(\"name\" == \"zhangsan\") AND (\"age\" == 22)")
        XCTAssertEqual(w4, "((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)")
        XCTAssertEqual(w5, "(((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)) AND (\"name\" == \"lisi\")")
        XCTAssertEqual(w6, "((((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)) AND (\"name\" == \"lisi\")) OR (\"age\" == 20)")
    }

    func testWhereOpreator() {
        let x1 = "age" |!= 22
        let x2 = "age" |<> 22
        let x3 = "age" |> 22
        let x4 = "age" |>= 22
        let x5 = "age" |!> 22
        let x6 = "age" |< 22
        let x7 = "age" |<= 22
        let x8 = "age" |!< 22
        XCTAssertEqual(x1, "\"age\" != 22")
        XCTAssertEqual(x2, "\"age\" <> 22")
        XCTAssertEqual(x3, "\"age\" > 22")
        XCTAssertEqual(x4, "\"age\" >= 22")
        XCTAssertEqual(x5, "\"age\" !> 22")
        XCTAssertEqual(x6, "\"age\" < 22")
        XCTAssertEqual(x7, "\"age\" <= 22")
        XCTAssertEqual(x8, "\"age\" !< 22")
    }

    func testWhereExp() {
        let v1 = "age".like(22)
        let v2 = "age".notLike(22)
        let v3 = "age".match(22)
        let v4 = "age".glob(22)
        let v5 = "age".notGlob(22)
        let v6 = "age".is(22)
        let v7 = "age".isNot(22)
        let v8 = "age".exists(22)
        let v9 = "age".notExists(22)
        let v10 = "age".isNull()
        let v11 = "age".between((20, 30))
        let v12 = "age".notBetween((20, 30))
        let v13 = "age".in([21, 22, 25, 28])
        let v14 = "age".notIn([21, 22, 25, 28])
        XCTAssertEqual(v1, "\"age\" LIKE \"%22%\"")
        XCTAssertEqual(v2, "\"age\" NOT LIKE \"%22%\"")
        XCTAssertEqual(v3, "\"age\" MATCH 22")
        XCTAssertEqual(v4, "\"age\" GLOB \"*22*\"")
        XCTAssertEqual(v5, "\"age\" NOT GLOB \"*22*\"")
        XCTAssertEqual(v6, "\"age\" IS 22")
        XCTAssertEqual(v7, "\"age\" IS NOT 22")
        XCTAssertEqual(v8, "\"age\" EXISTS 22")
        XCTAssertEqual(v9, "\"age\" NOT EXISTS 22")
        XCTAssertEqual(v10, "\"age\" IS NULL")
        XCTAssertEqual(v11, "\"age\" BETWEEN 20 AND 30")
        XCTAssertEqual(v12, "\"age\" NOT BETWEEN 20 AND 30")
        XCTAssertEqual(v13, "\"age\" IN (21,22,25,28)")
        XCTAssertEqual(v14, "\"age\" NOT IN (21,22,25,28)")
    }

    func testWhereArrayOrDictionary() {
        let w1 = ["age": 22, "name": "lisi"].toWhere()
        let w2 = [["age": 22], ["name": "lisi"]].toWhere()
        XCTAssert(w1 == "(\"age\" == 22) AND (\"name\" == \"lisi\")" || w1 == "(\"name\" == \"lisi\") AND (\"age\" == 22)")
        XCTAssert(w2 == "((\"age\" == 22)) OR ((\"name\" == \"lisi\"))")
    }

    func testOrderBy() {
        let o2 = ["age", "name"].joined
        let o3 = ["age"↓, "name"].joined
        let o4 = ["age"↓, "name"↑].joined
        XCTAssertEqual(o2, "age,name")
        XCTAssertEqual(o3, "age DESC,name")
        XCTAssertEqual(o4, "age DESC,name ASC")
    }

    func testGroupBy() {
        let g1 = "age"
        let g2 = ["age", "name"].joined
        let g3 = ["\"age\"", "\"name\""].joined
        XCTAssertEqual(g1, "age")
        XCTAssertEqual(g2, "age,name")
        XCTAssertEqual(g3, "\"age\",\"name\"")
    }

    func testFields() {
        let f2 = ["age", "name"].joined
        let f3 = "count(*)"
        XCTAssertEqual(f2, "age,name")
        XCTAssertEqual(f3, "count(*)")
    }
}

// MARK: - ORM

extension SQLiteORMTests {
    func testConnection() {
        let count = orm.count()
        XCTAssertGreaterThan(count, 0)
    }

    func testInsertDelete() {
        let r = orm.delete()
        XCTAssert(r)

        let p1 = Person(name: "张三", age: 22, id: 1, sex: .male, intro: "哈哈哈哈")
        let p2 = Person(name: "李四", age: 23, id: 2, sex: .female, intro: "嘿嘿嘿")
        let p3 = Person(name: "王五", age: 21, id: 3, sex: .male, intro: "呵呵呵")
        let r1 = orm.insert(p1)
        let r2 = orm.insert(multi: [p2, p3])
        let s1 = orm.find().one()
        XCTAssert(r1)
        XCTAssert(r2 > 0)
        XCTAssert(p1 == s1!)
    }

    func testUpsert() {
        let p1 = Person(name: "张三", age: 24, id: 1, sex: .male, intro: "我是张三")
        let p2 = Person(name: "李四", age: 25, id: 2, sex: .female, intro: "我是李四")
        let p3 = Person(name: "王五", age: 26, id: 3, sex: .male, intro: "我是王五")
        let r1 = orm.upsert(p1)
        let r2 = orm.upsert(multi: [p2, p3])
        XCTAssert(r1)
        XCTAssert(r2 > 0)
    }

    func testUpdate() {
        let p1 = Person(name: "张三", age: 21, id: 1, sex: .male, intro: "我是张三")
        let p2 = Person(name: "李四", age: 22, id: 2, sex: .female, intro: "我是李四")
        let p3 = Person(name: "王五", age: 23, id: 3, sex: .male, intro: "我是王五")
        let r1 = orm.update(p1)
        let r2 = orm.update(multi: [p2, p3])
        XCTAssert(r1)
        XCTAssert(r2 > 0)
    }

    func testSelect() {
        let one = orm.find().one()
        let all = orm.find().allKeyValues()
        let p1 = orm.find().where { "name" |== "王五" }.one()
        let all2 = orm.find().allItems()
        XCTAssert(one != nil)
        XCTAssert(all.count > 0)
        XCTAssert(p1 != nil)
        XCTAssert(all2.count > 0)
    }

    func testRelativeOrm() {
        let config = PlainConfig(Person.self)
        config.primaries = ["id"]
        let ftsconfig = FtsConfig(Person.self)
        ftsconfig.blacks = ["id"]
        ftsconfig.indexes = ["name", "intro"]
        let orm = Orm<Person>(config: config, db: db, table: "relative_person")
        let ftsorm = Orm<Person>(config: ftsconfig, relative: orm, content_rowid: "id")
        orm.delete()
        let p1 = Person(name: "张三", age: 21, id: 1, sex: .male, intro: "我是张三")
        let p2 = Person(name: "李四", age: 22, id: 2, sex: .female, intro: "我是李四")
        var p3 = Person(name: "王五", age: 23, id: 3, sex: .male, intro: "我是王五")
        orm.insert(multi: [p1, p2, p3])
        let r1 = ftsorm.find().allItems()
        orm.delete(p2)
        let r2 = ftsorm.find().fields { "rowid as id, *" }.allItems()
        p3.name = "王六"
        orm.update(p3)
        let r3 = ftsorm.find().allItems()
        if r1.count + r2.count + r3.count > 0 {}
    }
}

// MARK: - FTS

extension SQLiteORMTests {
    func testToken() {
        let sources = [
            "乘肥",
            "乘员",
            "乘警",
//            "dierzhang",
//            "dez",
//            "中国移动",
//            "会计",
//            "体育运动",
//            "保健",
//            "保险业",
//            "健康",
//            "公益组织",
        ]
        let mask: TokenMask = .init(rawValue: 3)
        for source in sources {
            let tokens = OrmEnumerator.enumerate(source, mask: mask)
            let sorted = tokens.sorted()
            print("-> \(source) :")
            for token in sorted {
                print(token)
            }
        }
    }

    func testToken1() {
        let sources = [
            "第二章",
            "dez",
            "234",
            "1,234,567,890",
            "12,345,678,901",
            "一1,234,567,890二12,345,678,901",
        ]
        for source in sources {
            let tokens = TestEnumerator.enumerate(source, mask: .all)
            print(tokens)
        }
    }

    func testRegisterTokenizer() {
        ftsDb.register(NaturalEnumerator.self, for: "nl")
        let x = ftsDb.enumerator(for: "nl")
        XCTAssert(x == NaturalEnumerator.self)
    }

    func testFtsDeleteInsert() {
        let r0 = ftsOrm.delete()
        XCTAssert(r0)

        let p1 = Person(name: "张三", age: 21, id: 1, sex: .male, intro: "我是张三")
        let p2 = Person(name: "李四", age: 22, id: 2, sex: .female, intro: "我是李四")
        let p3 = Person(name: "王五", age: 23, id: 3, sex: .male, intro: "我是王五")
        let r1 = ftsOrm.insert(p1)
        let r2 = ftsOrm.insert(multi: [p2, p3])

        XCTAssert(r1)
        XCTAssert(r2 > 0)
    }

    func testBigBatch() {
        var r = orm.delete()
        XCTAssert(r)

        r = ftsOrm.delete()
        XCTAssert(r)

        var mockTime: CFAbsoluteTime = 0
        var normalTime: CFAbsoluteTime = 0
        var ftsTime: CFAbsoluteTime = 0

        let loop = 100
        let batch = 1000
        let total = loop * batch

        for i in 0 ..< loop {
            autoreleasepool(invoking: { () in
                let begin = CFAbsoluteTimeGetCurrent()
                var persons: [Person] = []
                for j in 0 ..< batch {
                    let id = i * batch + j
                    let intro = infos[id % infos.count]
                    let p = Person(name: "张三", age: 21, id: Int64(id), sex: .male, intro: intro)
                    persons.append(p)
                }
                let step1 = CFAbsoluteTimeGetCurrent()
                self.orm.insert(multi: persons)
                let step2 = CFAbsoluteTimeGetCurrent()
                self.ftsOrm.insert(multi: persons)
                let end = CFAbsoluteTimeGetCurrent()

                let mock = step1 - begin
                let normal = step2 - step1
                let fts = end - step2

                mockTime += mock
                normalTime += normal
                ftsTime += fts

                let progress = min(1.0, Float(i + 1) / Float(loop))
                let progressText = String(format: "%.2f%", progress * 100.0)

                print("id: \(i * batch) - \((i + 1) * batch), progress: \(progressText)%, mock: \(mock), normal: \(normal), fts: \(fts)")
            })
        }
        let str = "[insert] \(total), mock: \(mockTime), normal: \(normalTime), fts: \(ftsTime)"
        print(str)
    }

    // MARK: - Utils

    func testTransform() {
        let string = "協力廠商研究公司Strategy Analytic曾於2月發佈數據預測，稱2020年AirPods出貨量有望增長50%，達到9000萬套。" +
            "這也意味著AirPods 2019年銷量達到了6000萬套，但也有分析師認為其2019年實際出貨量並未達到這個水准。" +
            " 蘋果不在財報中公佈AirPods的銷售數位，而是將其歸入“可穿戴設備、家庭用品和配件”類別。" +
            " 上個季度，蘋果該類別創下了新的收入紀錄，蘋果將這歸功於Apple Watch和AirPods的成功。" +
            "同樣在2月，天風國際分析師郭明錤給出了2020年度AirPods系列產品的預估出貨量，因受公共衛生事件影響，郭明錤預估AirPods系列產品在2020年出貨量約8000–9000萬部，其中AirPods Pro將會占到40%或更高的份額。" +
            "稍早前，蘋果中國官網一度對包括iPhone、iPad、Airpods Pro在內的產品進行限購，但3天后又解除了大部分產品的購買限制，只有新款MacBook Air和iPad Pro仍維持限購措施。"
        let simplified = string.simplified
        let traditional = simplified.traditional
        if traditional.count > 0 {}
    }

    func testSyllable() {
        let array = [
            "jintiantianqizhenhaoa",
            "jintiantianqizhenhao",
            "jintiantianqizhenha",
            "jintiantianqizhenh",
            "jintiantianqizhen",
            "helloworld",
            "jin,tian,tian,qi,zhen,hao,a",
            "jin'tian'tian'qi'zhen'hao'a",
        ]
        for string in array {
            let seg = string.pinyinSegmentation
            print(seg)
        }
    }

    func testNumber() {
        let numbers = [
            "1,234,567.89",
            "-1,234,567.89",
            "1,234,567.89.123",
            "1234567.89",
            "-1234567.89",
            "123,4567",
            ".1234567",
            ",1234567",
            "123456E7",
            "123456E-7",
            "1,234,567.89哈-1,234,567.89哈",
        ]
        for source in numbers {
            let tokens = OrmEnumerator.enumerate(source, mask: .all)
            let sorted = tokens.sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }
            print("-> \(source) :")
            for token in sorted {
                print(token)
            }
        }
    }
}

// MARK: - View

extension SQLiteORMTests {
    func testView() {
        if !view.exist {
            XCTAssert(view.create())
        }
        let p1 = view.find().oneKeyValue()
        XCTAssert(p1 != nil)
    }
}

// MARK: Utils

extension SQLiteORMTests {
    func testUpgrade() {
        let upgrader = Upgrader()
        UserDefaults.standard.set("0.1.0", forKey: upgrader.versionKey)
        let handler: ((Upgrader.Item) -> Bool) = { item -> Bool in
            print(item)
            for i in 1 ... 10 {
                item.progress = Float(i) * 0.1
                Thread.sleep(forTimeInterval: 0.1)
            }
            return true
        }
        let item1 = Upgrader.Item(id: "1", version: "0.1.1", stage: 0, handler: handler)
        item1.weight = 5.0
        let item2 = Upgrader.Item(id: "2", version: "0.1.4", stage: 0, handler: handler)
        item2.weight = 2.0
        let item3 = Upgrader.Item(id: "3", version: "0.1.1", stage: 1, handler: handler)
        item3.weight = 3.0
        let item4 = Upgrader.Item(id: "4", version: "0.1.3", stage: 1, handler: handler)
        item4.weight = 10.0
        let item5 = Upgrader.Item(id: "5", version: "0.1.2", stage: 0, handler: handler)
        item5.weight = 7.0
        upgrader.add([item1, item2, item3, item4, item5])
        upgrader.progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
        upgrader.upgrade()

        print("\n===============\n")

        let progress = Progress(totalUnitCount: 100)
        progress.addObserver(self, forKeyPath: "fractionCompleted", options: .new, context: nil)
        upgrader.debug(upgrade: [item3, item4, item5], progress: progress)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "fractionCompleted", let progress = object as? Progress else { return }
        print(String(format: "progress: %.2f%%", progress.fractionCompleted * 100.0))
    }
}
