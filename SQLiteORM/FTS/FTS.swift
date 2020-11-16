//
//  FTS.swift
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

import Foundation

#if SQLITE_HAS_CODEC
    import SQLCipher
#elseif os(Linux)
    import CSQLite
#else
    import SQLite3
#endif

// MARK: - FTS5

struct Fts5Tokenizer {
    var locale: String?
    var mask: UInt64 = 0
    var enumerator: UnsafeMutableRawPointer?
}

func fts5_xCreate(_ pUnused: UnsafeMutableRawPointer?,
                  _ azArg: UnsafeMutablePointer<UnsafePointer<Int8>?>?,
                  _ nArg: Int32,
                  _ pTokenizer: UnsafeMutablePointer<OpaquePointer?>?) -> Int32 {
    let tok = UnsafeMutablePointer<Fts5Tokenizer>.allocate(capacity: 1)
    if let azArg = azArg {
        for i in 0 ..< Int(nArg) {
            if let cstr = azArg[i] {
                let mask = UInt64(atoll(cstr))
                if mask > 0 {
                    tok.pointee.mask = mask
                } else {
                    tok.pointee.locale = String(cString: cstr)
                }
            }
        }
    }

    tok.pointee.enumerator = pUnused
    pTokenizer?.pointee = OpaquePointer(tok)
    return SQLITE_OK
}

func fts5_xDelete(_ pTokenizer: OpaquePointer?) {
    if let p = pTokenizer { UnsafeMutableRawPointer(p).deallocate() }
}

func fts5_xTokenize(_ pTokenizer: OpaquePointer?,
                    _ pCtx: UnsafeMutableRawPointer?,
                    _ iUnused: Int32,
                    _ pText: UnsafePointer<Int8>?,
                    _ nText: Int32,
                    _ xToken: (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<Int8>?, Int32, Int32, Int32) -> Int32)?) -> Int32 {
    guard nText > 0,
        let text = pText,
        let source = String(utf8String: text)
    else { return SQLITE_OK }
    guard let xxToken = xToken,
        let pTok = UnsafeMutablePointer<Fts5Tokenizer>.init(pTokenizer)
    else { return SQLITE_NOMEM }
    guard let pEnum = pTok.pointee.enumerator
    else { return SQLITE_ERROR }

    var xmask = TokenMask(rawValue: pTok.pointee.mask)
    if iUnused & FTS5_TOKENIZE_DOCUMENT > 0 {
        xmask.subtract(.query)
    } else if iUnused & FTS5_TOKENIZE_QUERY > 0 {
        xmask.formUnion(.query)
    }

    let enumerator = pEnum.assumingMemoryBound(to: Enumerator.Type.self).pointee
    let tks = enumerator.enumerate(source, mask: xmask)

    var rc = SQLITE_OK
    for tk in tks {
        rc = xxToken(pCtx, Int32(tk.colocated), tk.word, Int32(tk.len), Int32(tk.start), Int32(tk.end))
        if rc != SQLITE_OK { break }
    }
    if rc == SQLITE_DONE { rc = SQLITE_OK }
    return rc
}

extension Database {
    /// register tokenizer
    ///
    /// - Parameters:
    ///   - type: tokenize method
    public func register(_ enumerator: Enumerator.Type, for tokenizer: String) {
        enumerators[tokenizer] = enumerator
    }

    /// get tokenize method
    public func enumerator(for tokenizer: String) -> Enumerator.Type? {
        return enumerators[tokenizer]
    }

    /// register tokenizer
    ///
    /// - Parameters:
    ///   - type: tokenize method
    func registerEnumerators(_ db: OpaquePointer!) throws {
        guard enumerators.count > 0 else { return }

        let pApi = UnsafeMutablePointer<fts5_api>(mutating: try get_fts5_api(db))
        for (name, enumerator) in enumerators {
            let pointer = UnsafeMutablePointer<Enumerator.Type>.allocate(capacity: 1)
            pointer.pointee = enumerator
            let pEnumerator = UnsafeMutableRawPointer(pointer)

            // fts5 register custom tokenizer
            let pTokenizer = UnsafeMutablePointer<fts5_tokenizer>.allocate(capacity: 1)
            pTokenizer.pointee.xCreate = fts5_xCreate(_:_:_:_:)
            pTokenizer.pointee.xDelete = fts5_xDelete(_:)
            pTokenizer.pointee.xTokenize = fts5_xTokenize(_:_:_:_:_:_:)
            try check(pApi.pointee.xCreateTokenizer(pApi, name, pEnumerator, pTokenizer, nil))
        }
    }

    func get_fts5_api(_ db: OpaquePointer!) throws -> UnsafePointer<fts5_api> {
        var pApi: UnsafePointer<fts5_api>?
        var stmt: OpaquePointer?
        try check(sqlite3_prepare_v2(db, "SELECT fts5(?1)", -1, &stmt, nil))
        #if SQLITE_HAS_CODEC
            sqlite3_bind_pointer(stmt!, 1, &pApi, "fts5_api_ptr", nil)
            sqlite3_step(stmt!)
        #else
            if #available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *) {
                sqlite3_bind_pointer(stmt!, 1, &pApi, "fts5_api_ptr", nil)
                sqlite3_step(stmt!)
            }
        #endif
        sqlite3_finalize(stmt)
        guard let result = pApi else {
            throw Result.error(message: "fts5_api_ptr", code: -1, statement: nil)
        }
        return result
    }
}
