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

// MARK: - FTS3

struct Fts3TokenizeModule {
    var iVersion: Int32
    var xCreate: @convention(c) (Int32, UnsafeMutablePointer<UnsafePointer<Int8>?>?, UnsafeMutablePointer<OpaquePointer?>?) -> Int32
    var xDestroy: @convention(c) (OpaquePointer?) -> Int32
    var xOpen: @convention(c) (OpaquePointer?, UnsafePointer<Int8>?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Int32
    var xClose: @convention(c) (OpaquePointer?) -> Int32
    var xNext: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UnsafePointer<Int8>?>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<Int32>?) -> Int32
    var xLanguageid: @convention(c) (OpaquePointer?, Int32) -> Int32
    var xName: UnsafePointer<Int8>?
    var xEnumerator: UnsafeMutableRawPointer?
}

struct Fts3Tokenizer {
    var base: OpaquePointer?
    var locale: String?
    var mask: UInt64 = 0
}

struct Fts3Cursor {
    var base: OpaquePointer?
    var pInput: UnsafePointer<Int8>?
    var nBytes: Int32 = 0
    var iToken: Int32 = 0
    var nToken: Int32 = 0
    var tokens: [Token] = []
}

func fts3_create(_ argc: Int32,
                 _ argv: UnsafeMutablePointer<UnsafePointer<Int8>?>?,
                 _ ppTokenizer: UnsafeMutablePointer<OpaquePointer?>?) -> Int32 {
    let tok = UnsafeMutablePointer<Fts3Tokenizer>.allocate(capacity: 1)
    if let azArg = argv {
        for i in 0 ..< Int(argc) {
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
    ppTokenizer?.pointee = OpaquePointer(tok)
    return SQLITE_OK
}

func fts3_destroy(_ pTokenizer: OpaquePointer?) -> Int32 {
    let pointer = UnsafeMutableRawPointer(pTokenizer)
    pointer?.deallocate()
    return SQLITE_OK
}

func fts3_open(_ pTokenizer: OpaquePointer?,
               _ pInput: UnsafePointer<Int8>?,
               _ nBytes: Int32,
               _ ppCursor: UnsafeMutablePointer<OpaquePointer?>?) -> Int32 {
    guard let xTokenizer = pTokenizer, let xInput = UnsafePointer<CChar>.init(pInput) else { return SQLITE_ERROR }
    let cursor = UnsafeMutablePointer<Fts3Cursor>.allocate(capacity: 1)
    let xTok = UnsafeMutablePointer<Fts3Tokenizer>.init(xTokenizer)
    let tok = xTok.pointee
    guard let pModule = UnsafeMutablePointer<Fts3TokenizeModule>.init(tok.base) else { return SQLITE_ERROR }
    let module = pModule.pointee
    guard let pEnum = module.xEnumerator else { return SQLITE_ERROR }
    let enumerator = pEnum.assumingMemoryBound(to: Enumerator.Type.self).pointee

    let text = String(cString: xInput)
    let array = enumerator.enumerate(text, mask: TokenMask(rawValue: tok.mask))

    cursor.pointee.pInput = pInput
    cursor.pointee.nBytes = nBytes
    cursor.pointee.iToken = 0
    cursor.pointee.nToken = Int32(array.count)
    cursor.pointee.tokens = array
    ppCursor?.pointee = OpaquePointer(cursor)
    return SQLITE_OK
}

func fts3_close(_ pCursor: OpaquePointer?) -> Int32 {
    let pointer = UnsafeMutableRawPointer(pCursor)
    pointer?.deallocate()
    return SQLITE_OK
}

func fts3_next(_ pCursor: OpaquePointer?,
               _ ppToken: UnsafeMutablePointer<UnsafePointer<Int8>?>?,
               _ pnBytes: UnsafeMutablePointer<Int32>?,
               _ piStartOffset: UnsafeMutablePointer<Int32>?,
               _ piEndOffset: UnsafeMutablePointer<Int32>?,
               _ piPosition: UnsafeMutablePointer<Int32>?) -> Int32 {
    guard let cursor = UnsafeMutablePointer<Fts3Cursor>(pCursor) else { return SQLITE_ERROR }
    let tokens = cursor.pointee.tokens
    let iToken = Int(cursor.pointee.iToken)
    guard tokens.count > 0 && iToken < tokens.count else { return SQLITE_DONE }
    let token = tokens[iToken]
    ppToken?.pointee = (token.word as NSString).utf8String
    pnBytes?.pointee = Int32(token.len)
    piStartOffset?.pointee = Int32(token.start)
    piEndOffset?.pointee = Int32(token.end)
    piPosition?.pointee = Int32(iToken)
    cursor.pointee.iToken += 1
    return SQLITE_OK
}

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
        xmask.subtract(.syllable)
    } else if iUnused & FTS5_TOKENIZE_QUERY > 0 && xmask.hasPinyin() {
        xmask.subtract(.allPinYin)
        xmask.formUnion(.syllable)
    }

    let enumerator = pEnum.assumingMemoryBound(to: Enumerator.Type.self).pointee
    let tks = enumerator.enumerate(source, mask: xmask)

    var rc = SQLITE_OK
    for tk in tks {
        rc = xxToken(pCtx, tk.colocated > TOKEN_FULLWIDTH ? 1 : 0, tk.word, Int32(tk.len), Int32(tk.start), Int32(tk.end))
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

            // fts3,4 register custom tokenizer
            var pStmt: OpaquePointer?
            var pModule = UnsafeMutablePointer<Fts3TokenizeModule>.allocate(capacity: 1)
            pModule.pointee.iVersion = 0
            pModule.pointee.xCreate = fts3_create(_:_:_:)
            pModule.pointee.xDestroy = fts3_destroy(_:)
            pModule.pointee.xOpen = fts3_open(_:_:_:_:)
            pModule.pointee.xClose = fts3_close(_:)
            pModule.pointee.xNext = fts3_next(_:_:_:_:_:_:)
            pModule.pointee.xName = (name as NSString).utf8String
            pModule.pointee.xEnumerator = pEnumerator

            try check(SQLiteORMEnableFts3Module(db))
            try check(sqlite3_prepare_v2(db, "SELECT fts3_tokenizer(?,?)", -1, &pStmt, nil))
            let size = MemoryLayout<UnsafeMutablePointer<Fts3TokenizeModule>>.size
            try check(sqlite3_bind_text(pStmt, 1, name, -1, SQLITE_STATIC))
            try check(sqlite3_bind_blob(pStmt, 2, &pModule, Int32(size), SQLITE_STATIC))
            try check(sqlite3_step(pStmt))
            try check(sqlite3_finalize(pStmt))

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
