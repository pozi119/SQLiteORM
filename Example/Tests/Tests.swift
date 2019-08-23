@testable import SQLiteORM
import XCTest

fileprivate typealias W = Where

final class SQLiteORMTests: XCTestCase {
    fileprivate lazy var db: Database = {
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let url = URL(fileURLWithPath: dir).appendingPathComponent("test.db")
        return Database(with: url.path)
    }()

    fileprivate lazy var orm: Orm = {
        let config = GeneralConfig(Person.self)
        config.primaries = ["id"]
        let orm = Orm(config: config, db: db, table: "person", setup: true)
        return orm
    }()

    fileprivate lazy var ftsDb: Database = {
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last!
        let url = URL(fileURLWithPath: dir).appendingPathComponent("testFts.db")
        let _db = Database(with: url.path)
        _db.register(.sqliteorm, for: "sqliteorm")
        return _db
    }()

    fileprivate lazy var ftsOrm: Orm = {
        let config = FtsConfig(Person.self)
        config.module = "fts5"
        config.tokenizer = "sqliteorm"
        config.indexes = ["name", "intro"]

        let orm = Orm(config: config, db: ftsDb, table: "person", setup: true)
        return orm
    }()

    static var allTests = [
        ("testConnection", testConnection),
        ("testCoder", testCoder),
    ]
}

// MARK: - Coder

extension SQLiteORMTests {
    func testCoder() {
        let person: Person? = Person(name: "张三", age: 22, id: 1, sex: .male, intro: "哈哈哈哈")
        let user: User? = User(id: 2, name: "zhangsan", person: person)
        user?.list = [1, 2, 3, 4, 5]

        do {
            let dic = try OrmEncoder().encode(person)
            let decoded = try OrmDecoder().decode(type(of: person), from: dic as Any)
            XCTAssertEqual(person, decoded)

            let dic1 = try OrmEncoder().encode(user)
            let decoded1 = try OrmDecoder().decode(type(of: user), from: dic1 as Any)
            XCTAssert(user != nil && decoded1 != nil && user! == decoded1!)

            let array2 = [user, nil]
            let dic2 = try? OrmEncoder().encode(array2)
            let decoded2 = try? OrmDecoder().decode(type(of: array2), from: dic2 as Any)
            let user2 = decoded2?.first!
            XCTAssert(decoded2 != nil && decoded2!.count == 2 && user! == user2!)
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
        XCTAssertEqual(o1.sql, "\"age\" ASC")
        XCTAssertEqual(o2.sql, "\"age\",\"name\" ASC")
        XCTAssertEqual(o3.sql, "age DESC,\"name\" ASC")
        XCTAssertEqual(o4.sql, "age DESC,name ASC")
    }

    func testGroupBy() {
        let g1 = GroupBy("age")
        let g2 = GroupBy(["age", "name"])
        let g3 = GroupBy(["\"age\"", "\"name\""])
        XCTAssertEqual(g1.sql, "\"age\"")
        XCTAssertEqual(g2.sql, "\"age\",\"name\"")
        XCTAssertEqual(g3.sql, "\"age\",\"name\"")
    }

    func testFields() {
        let f1 = Fields("age")
        let f2 = Fields(["age", "name"])
        let f3 = Fields("count(*)")
        XCTAssertEqual(f1.sql, "age")
        XCTAssertEqual(f2.sql, "\"age\",\"name\"")
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
        XCTAssert(r1)
        XCTAssert(r2 > 0)
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
        let one = orm.findOne()?.item(Person.self)
        let all = orm.find().allItems(Person.self)
        let p1 = orm.findOne(W("name") == "王五")?.item(Person.self)
        XCTAssert(one != nil)
        XCTAssert(all.count > 0)
        XCTAssert(p1 != nil)
    }
}

// MARK: - FTS

extension SQLiteORMTests {
    func testPinyin() {
        let tokens = "成都".pinyinTokens
        XCTAssertEqual(Set(tokens), Set(["chengdu", "chengdou", "cd"]))
    }

    func testRegisterTokenizer() {
        let r = ftsDb.register(.natural, for: "nl")
        XCTAssert(r)

        let x = ftsDb.enumerator(for: "nl")
        XCTAssert(x != .natural)
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

    func testFtsMatch() {
        let r = ftsOrm.find(W("intro").match("李四"))
        XCTAssert(r.count > 0)
        let highlighter = Highlighter(orm: ftsOrm, keyword: "李四", highlightAttributes: [.foregroundColor: UIColor.red])
        let sources = r.map { $0["intro"] as? String ?? "" }
        let s = highlighter.highlight(sources)
        XCTAssert(s.count > 0)
    }
}
