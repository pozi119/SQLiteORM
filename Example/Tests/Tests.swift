@testable import SQLiteORM
import XCTest

fileprivate typealias W = Where

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

    static var allTests = [
        ("testConnection", testConnection),
        ("testCoder", testCoder),
    ]
}

// MARK: - Coder

extension SQLiteORMTests {
    func testCoder() {
        let data = Data([0x31, 0x32, 0x33, 0x34, 0x35, 0xF, 0x41, 0x42, 0x43])
        var person: Person? = Person(name: "张三", age: 22, id: 1, sex: .female, intro: "哈哈哈哈")
        person?.data = data

        let user: User? = User(id: 2, name: "zhangsan", person: person)
        user?.list = [1, 2, 3, 4, 5]
        user?.data = data

        do {
            let dic0 = try AnyEncoder.encode(user)
            let decoded0 = try AnyDecoder.decode(User?.self, from: dic0)
            XCTAssert(user != nil && decoded0 != nil && user! == decoded0!)

            let dic = try OrmEncoder().encode(person)
            let decoded = try OrmDecoder().decode(type(of: person), from: dic as Any)
            XCTAssertEqual(person, decoded)

            let dic1 = try OrmEncoder().encode(user)
            let decoded1 = try OrmDecoder().decode(type(of: user), from: dic1 as Any)
            XCTAssert(user != nil && decoded1 != nil && user! == decoded1!)

            let dic3 = try JSONEncoder().encode(user)
            let json3 = try JSONSerialization.jsonObject(with: dic3, options: [])
            let decoded3 = try JSONDecoder().decode(type(of: user), from: dic3)
            print(json3)
            XCTAssert(user != nil && decoded3 != nil && user! == decoded3!)

            let array2 = [user, nil]
            let dic2 = OrmEncoder().encode(array2)
            let decoded2 = try OrmDecoder().decode(type(of: array2), from: dic2 as Any)
            let user2 = decoded2.first!
            XCTAssert(decoded2.count == 2 && user! == user2!)
        } catch {
            XCTAssertThrowsError(error)
        }
    }

    func testAnyCoder() {
        do {
            let enuminfo = try typeInfo(of: Person.Sex.self)
            let tuple = (Data([0x1, 0x31, 0x61, 0x91]), 1, 2)
            let tupleinfo = try typeInfo(of: type(of: tuple))
            print(enuminfo)
            print(tupleinfo)
        } catch {
            XCTAssertThrowsError(error)
        }
    }
}

// MARK: - Expression

extension SQLiteORMTests {
    func testWhereLogic() {
        let w1 = W("name") == "zhangsan"
        let w2 = W("age") == 22
        let w3 = w1 && w2
        let w4 = w3 || W("age") == 21
        let w5 = w4 && W("name") == "lisi"
        let w6 = w5 || W("age") == 20
        XCTAssertEqual(w1.sql, "\"name\" == \"zhangsan\"")
        XCTAssertEqual(w2.sql, "\"age\" == 22")
        XCTAssertEqual(w3.sql, "(\"name\" == \"zhangsan\") AND (\"age\" == 22)")
        XCTAssertEqual(w4.sql, "((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)")
        XCTAssertEqual(w5.sql, "(((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)) AND (\"name\" == \"lisi\")")
        XCTAssertEqual(w6.sql, "((((\"name\" == \"zhangsan\") AND (\"age\" == 22)) OR (\"age\" == 21)) AND (\"name\" == \"lisi\")) OR (\"age\" == 20)")
    }

    func testWhereOpreator() {
        let x1 = W("age") != 22
        let x2 = W("age") <> 22
        let x3 = W("age") > 22
        let x4 = W("age") >= 22
        let x5 = W("age") !> 22
        let x6 = W("age") < 22
        let x7 = W("age") <= 22
        let x8 = W("age") !< 22
        XCTAssertEqual(x1.sql, "\"age\" != 22")
        XCTAssertEqual(x2.sql, "\"age\" <> 22")
        XCTAssertEqual(x3.sql, "\"age\" > 22")
        XCTAssertEqual(x4.sql, "\"age\" >= 22")
        XCTAssertEqual(x5.sql, "\"age\" !> 22")
        XCTAssertEqual(x6.sql, "\"age\" < 22")
        XCTAssertEqual(x7.sql, "\"age\" <= 22")
        XCTAssertEqual(x8.sql, "\"age\" !< 22")
    }

    func testWhereExp() {
        let v1 = W("age").like(22)
        let v2 = W("age").notLike(22)
        let v3 = W("age").match(22)
        let v4 = W("age").glob(22)
        let v5 = W("age").notGlob(22)
        let v6 = W("age").is(22)
        let v7 = W("age").isNot(22)
        let v8 = W("age").exists(22)
        let v9 = W("age").notExists(22)
        let v10 = W("age").isNull()
        let v11 = W("age").between((20, 30))
        let v12 = W("age").notBetween((20, 30))
        let v13 = W("age").in([21, 22, 25, 28])
        let v14 = W("age").notIn([21, 22, 25, 28])
        XCTAssertEqual(v1.sql, "\"age\" LIKE 22")
        XCTAssertEqual(v2.sql, "\"age\" NOT LIKE 22")
        XCTAssertEqual(v3.sql, "\"age\" MATCH 22")
        XCTAssertEqual(v4.sql, "\"age\" GLOB 22")
        XCTAssertEqual(v5.sql, "\"age\" NOT GLOB 22")
        XCTAssertEqual(v6.sql, "\"age\" IS 22")
        XCTAssertEqual(v7.sql, "\"age\" IS NOT 22")
        XCTAssertEqual(v8.sql, "\"age\" EXISTS 22")
        XCTAssertEqual(v9.sql, "\"age\" NOT EXISTS 22")
        XCTAssertEqual(v10.sql, "\"age\" IS NULL")
        XCTAssertEqual(v11.sql, "\"age\" BETWEEN 20 AND 30")
        XCTAssertEqual(v12.sql, "\"age\" NOT BETWEEN 20 AND 30")
        XCTAssertEqual(v13.sql, "\"age\" IN (21,22,25,28)")
        XCTAssertEqual(v14.sql, "\"age\" NOT IN (21,22,25,28)")
    }

    func testWhereArrayOrDictionary() {
        let w1 = W(["age": 22, "name": "lisi"])
        let w2 = W([["age": 22], ["name": "lisi"]])
        XCTAssert(w1.sql == "(\"age\" == 22) AND (\"name\" == \"lisi\")" || w1.sql == "(\"name\" == \"lisi\") AND (\"age\" == 22)")
        XCTAssert(w2.sql == "((\"age\" == 22)) OR ((\"name\" == \"lisi\"))")
    }

    func testOrderBy() {
        let o1 = OrderBy("age")
        let o2 = OrderBy(["age", "name"])
        let o3 = OrderBy(["age DESC", "name"])
        let o4 = OrderBy(["age DESC", "name ASC"])
        XCTAssertEqual(o1.sql, "age ASC")
        XCTAssertEqual(o2.sql, "age ASC,name ASC")
        XCTAssertEqual(o3.sql, "age DESC,name ASC")
        XCTAssertEqual(o4.sql, "age DESC,name ASC")
    }

    func testGroupBy() {
        let g1 = GroupBy("age")
        let g2 = GroupBy(["age", "name"])
        let g3 = GroupBy(["\"age\"", "\"name\""])
        XCTAssertEqual(g1.sql, "age")
        XCTAssertEqual(g2.sql, "age,name")
        XCTAssertEqual(g3.sql, "\"age\",\"name\"")
    }

    func testFields() {
        let f1 = Fields("age")
        let f2 = Fields(["age", "name"])
        let f3 = Fields("count(*)")
        XCTAssertEqual(f1.sql, "age")
        XCTAssertEqual(f2.sql, "age,name")
        XCTAssertEqual(f3.sql, "count(*)")
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
        let s1 = orm.xFindOne()
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
        let one = orm.findOne()
        let all = orm.find()
        let p1 = orm.findOne(W("name") == "王五")
        XCTAssert(one != nil)
        XCTAssert(all.count > 0)
        XCTAssert(p1 != nil)
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
        let r1 = ftsorm.xFind()
        orm.delete(p2)
        let r2 = ftsorm.xFind(fields: "rowid as id, *")
        p3.name = "王六"
        orm.update(p3)
        let r3 = ftsorm.xFind()
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
            autoreleasepool(invoking: { () -> Void in
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
        let p1 = view.xFindOne()
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
