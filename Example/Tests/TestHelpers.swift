//
//  TestHelpers.swift
//  SQLiteORMTests
//
//  Created by Valo on 2019/5/13.
//

import Foundation

struct Person:Codable,Equatable {
    enum Sex:Int,Codable {
        case male,female
    }
    var name:String
    var age:Int
    var id:Int64
    var sex:Sex
    var intro:String
}

struct Event {
    var name:String
    var id:Int64
}

class User: Codable,Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.password == rhs.password && lhs.person == rhs.person
    }
    
    var id:Int64
    var name:String
    var password:String? = nil
    var person:Person? = nil
    var list:[Int] = []
    
    init(id:Int64 = 0, name:String = "", password:String? = nil, person:Person? = nil) {
        self.id = id
        self.name = name
        self.password = password
        self.person = person
    }
}
