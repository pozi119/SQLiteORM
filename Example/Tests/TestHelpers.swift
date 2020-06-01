//
//  TestHelpers.swift
//  SQLiteORMTests
//
//  Created by Valo on 2019/5/13.
//

import Foundation
import SQLiteORM

struct Person: Codable, Equatable {
    enum Sex: Int, Codable {
        case male, female
    }

    var name: String
    var age: Int
    var id: Int64
    var sex: Sex
    var intro: String
}

struct Event {
    var name: String
    var id: Int64
}

class User: NSObject, Codable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.password == rhs.password
            && lhs.person == rhs.person
    }

    var id: Int64
    var name: String
    var password: String?
    var person: Person?
    var list: [Int] = []

    init(id: Int64 = 0, name: String = "", password: String? = nil, person: Person? = nil) {
        self.id = id
        self.name = name
        self.password = password
        self.person = person
    }
}

public extension TokenMethod {
    static let test = TokenMethod(rawValue: 1 << 3)
}

struct TestTokenizer: Tokenizer {
    static func tokenize(_ bytes: [UInt8], _ method: TokenMethod, _ mask: TokenMask) -> [Token] {
        let string: NSString = (String(bytes: bytes) as NSString)
        var results: [Token] = []
        let count = string.length
        for i in 0 ..< count {
            let start = Int32(string.substring(to: i).bytes.count)
            let cur = string.substring(with: NSMakeRange(i, 1))
            let cbytes = cur.bytes
            let len = Int32(cbytes.count)
            let token = Token(cur, len: len, start: start, end: start + len)
            results.append(token)
        }
        return results
    }
}
