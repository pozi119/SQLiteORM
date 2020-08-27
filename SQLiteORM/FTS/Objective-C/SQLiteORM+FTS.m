//
//  SQLiteORM+FTS.m
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

#import <Foundation/Foundation.h>
#import "SQLiteORM+FTS.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

extern NSArray * swift_tokenize(NSString *, int, uint32_t);

@interface NSString (SQLiteORM)

+ (instancetype)stringWithCString:(const char *)cString;

@end

@implementation NSString (SQLiteORM)

+ (instancetype)stringWithCString:(const char *)cString
{
    NSString *string = [NSString stringWithUTF8String:cString];
    if (string) return string;
    string = [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
    if (string) return string;
    return @"";
}

@end

@implementation SQLiteORMToken
@synthesize token = _token;
+ (instancetype)token:(const char *)word len:(int)len start:(int)start end:(int)end
{
    SQLiteORMToken *tk = [SQLiteORMToken new];
    char *temp = (char *)malloc(len + 1);
    memcpy(temp, word, len);
    temp[len] = '\0';
    tk.word = temp;
    tk.start = start;
    tk.len = len;
    tk.end = end;
    return tk;
}

- (NSString *)token
{
    if (!_token) {
        _token = _word ? [NSString stringWithUTF8String:_word] : nil;
    }
    return _token;
}

+ (NSArray<SQLiteORMToken *> *)sortedTokens:(NSArray<SQLiteORMToken *> *)tokens
{
    return [tokens sortedArrayUsingComparator:^NSComparisonResult (SQLiteORMToken *tk1, SQLiteORMToken *tk2) {
        uint64_t h1 = ((uint64_t)tk1.start) << 32 | ((uint64_t)tk1.end) | ((uint64_t)tk1.len);
        uint64_t h2 = ((uint64_t)tk2.start) << 32 | ((uint64_t)tk2.end) | ((uint64_t)tk2.len);
        return h1 == h2 ? [tk1.token compare:tk2.token] : (h1 < h2 ? NSOrderedAscending : NSOrderedDescending);
    }];
}

- (BOOL)isEqual:(id)object
{
    return object != nil && [object isKindOfClass:SQLiteORMToken.class] && [(SQLiteORMToken *)object hash] == self.hash;
}

- (NSUInteger)hash {
    return self.token.hash ^ @(_start).hash ^ @(_len).hash ^ @(_end).hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%2i-%2i|%2i|%i|0x%09lx]: %@ ", _start, _end, _len, (int)_colocated, (unsigned long)self.hash, self.token];
}

- (void)dealloc
{
    free(_word);
    _word = NULL;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    SQLiteORMToken *token = [[[self class] allocWithZone:zone] init];
    char *temp = (char *)malloc(_len + 1);
    memcpy(temp, _word, _len);
    temp[_len] = '\0';
    token.word = temp;
    token.start = _start;
    token.end = _end;
    token.len = _len;
    return token;
}

@end

//MARK: - FTS3
typedef struct sqlite3_tokenizer_module   sqlite3_tokenizer_module;
typedef struct sqlite3_tokenizer          sqlite3_tokenizer;
typedef struct sqlite3_tokenizer_cursor   sqlite3_tokenizer_cursor;

struct sqlite3_tokenizer_module {
    int iVersion;
    int (*xCreate)(
        int               argc,                                  /* Size of argv array */
        const char *const *argv,                                 /* Tokenizer argument strings */
        sqlite3_tokenizer **ppTokenizer                          /* OUT: Created tokenizer */
        );
    int (*xDestroy)(sqlite3_tokenizer *pTokenizer);
    int (*xOpen)(
        sqlite3_tokenizer *pTokenizer,                           /* Tokenizer object */
        const char *pInput, int nBytes,                          /* Input buffer */
        sqlite3_tokenizer_cursor **ppCursor                      /* OUT: Created tokenizer cursor */
        );
    int (*xClose)(sqlite3_tokenizer_cursor *pCursor);
    int (*xNext)(
        sqlite3_tokenizer_cursor *pCursor,                       /* Tokenizer cursor */
        const char **ppToken, int *pnBytes,                      /* OUT: Normalized text for token */
        int *piStartOffset,                                      /* OUT: Byte offset of token in input buffer */
        int *piEndOffset,                                        /* OUT: Byte offset of end of token in input buffer */
        int *piPosition                                          /* OUT: Number of tokens returned before this one */
        );
    int (*xLanguageid)(sqlite3_tokenizer_cursor *pCsr, int iLangid);
    const char *xName;
    const void *xClass;
};

struct sqlite3_tokenizer {
    const sqlite3_tokenizer_module *pModule;  /* The module for this tokenizer */
};

struct sqlite3_tokenizer_cursor {
    sqlite3_tokenizer *pTokenizer;            /* Tokenizer for this cursor. */
};

typedef struct so_fts3_tokenizer {
    sqlite3_tokenizer base;
    char locale[16];
    uint32_t mask;
} so_fts3_tokenizer;

typedef struct so_fts3_tokenizer_cursor {
    sqlite3_tokenizer_cursor base;  /* base cursor */
    const char *pInput;             /* input we are tokenizing */
    int nBytes;                     /* size of the input */
    int iToken;                     /* index of current token*/
    int nToken;                     /* count of token */
    CFArrayRef tokens;
} so_fts3_tokenizer_cursor;

static int fts3_register_tokenizer(
    sqlite3                        *db,
    char                           *zName,
    const sqlite3_tokenizer_module *p
    )
{
    int rc;
    sqlite3_stmt *pStmt;
    const char *zSql = "SELECT fts3_tokenizer(?, ?)";

    sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 1, 0);

    rc = sqlite3_prepare_v2(db, zSql, -1, &pStmt, 0);
    if (rc != SQLITE_OK) {
        return rc;
    }

    sqlite3_bind_text(pStmt, 1, zName, -1, SQLITE_STATIC);
    sqlite3_bind_blob(pStmt, 2, &p, sizeof(p), SQLITE_STATIC);
    sqlite3_step(pStmt);

    return sqlite3_finalize(pStmt);
}

static int so_fts3_create(
    int argc, const char *const *argv,
    sqlite3_tokenizer **ppTokenizer
    )
{
    so_fts3_tokenizer *tok;
    UNUSED_PARAM(argc);
    UNUSED_PARAM(argv);

    tok = (so_fts3_tokenizer *)sqlite3_malloc(sizeof(*tok));
    if (tok == NULL) return SQLITE_NOMEM;
    memset(tok, 0, sizeof(*tok));

    memset(tok->locale, 0x0, 16);
    tok->mask = 0;

    for (int i = 0; i < MIN(2, argc); i++) {
        const char *arg = argv[i];
        uint32_t mask = (uint32_t)atol(arg);
        if (mask > 0) {
            tok->mask = mask;
        } else {
            strncpy(tok->locale, arg, 15);
        }
    }

    *ppTokenizer = &tok->base;
    return SQLITE_OK;
}

static int so_fts3_destroy(sqlite3_tokenizer *pTokenizer)
{
    sqlite3_free(pTokenizer);
    return SQLITE_OK;
}

static int so_fts3_open(
    sqlite3_tokenizer *pTokenizer,                                                  /* The tokenizer */
    const char *pInput, int nBytes,                                                 /* String to be tokenized */
    sqlite3_tokenizer_cursor **ppCursor                                             /* OUT: Tokenization cursor */
    )
{
    UNUSED_PARAM(pTokenizer);
    if (pInput == 0) return SQLITE_ERROR;

    so_fts3_tokenizer_cursor *c;
    c = (so_fts3_tokenizer_cursor *)sqlite3_malloc(sizeof(*c));
    if (c == NULL) return SQLITE_NOMEM;

    const sqlite3_tokenizer_module *module = pTokenizer->pModule;
    Class<SQLiteORMEnumerator> clazz = (__bridge Class)(module->xClass);
    if (!clazz || ![clazz conformsToProtocol:@protocol(SQLiteORMEnumerator)]) {
        return SQLITE_ERROR;
    }
    int nInput = (pInput == 0) ? 0 : (nBytes < 0 ? (int)strlen(pInput) : nBytes);
    so_fts3_tokenizer *tok = (so_fts3_tokenizer *)pTokenizer;
    NSString *source = [NSString stringWithCString:pInput];
    NSArray *array = [clazz enumerate:source mask:tok->mask];
    c->pInput = pInput;
    c->nBytes = nInput;
    c->iToken = 0;
    c->nToken = (int)array.count;
    c->tokens = (__bridge_retained CFArrayRef)array;

    *ppCursor = &c->base;
    return SQLITE_OK;
}

static int so_fts3_close(sqlite3_tokenizer_cursor *pCursor)
{
    so_fts3_tokenizer_cursor *c = (so_fts3_tokenizer_cursor *)pCursor;
    CFRelease(c->tokens);
    sqlite3_free(c);
    return SQLITE_OK;
}

static int so_fts3_next(
    sqlite3_tokenizer_cursor *pCursor,                                                  /* Cursor returned by so_fts3_open */
    const char               **ppToken,                                                 /* OUT: *ppToken is the token text */
    int                      *pnBytes,                                                  /* OUT: Number of bytes in token */
    int                      *piStartOffset,                                            /* OUT: Starting offset of token */
    int                      *piEndOffset,                                              /* OUT: Ending offset of token */
    int                      *piPosition                                                /* OUT: Position integer of token */
    )
{
    so_fts3_tokenizer_cursor *c = (so_fts3_tokenizer_cursor *)pCursor;
    NSArray *array = (__bridge NSArray *)(c->tokens);
    if (array.count == 0 || c->iToken == array.count) return SQLITE_DONE;
    SQLiteORMToken *t = array[c->iToken];
    *ppToken = t.token.UTF8String;
    *pnBytes = t.len;
    *piStartOffset = t.start;
    *piEndOffset = t.end;
    *piPosition = c->iToken++;
    return SQLITE_OK;
}

//MARK: - FTS5

static fts5_api * fts5_api_from_db(sqlite3 *db)
{
    fts5_api *pRet = 0;
    sqlite3_stmt *pStmt = 0;

    if (SQLITE_OK == sqlite3_prepare(db, "SELECT fts5(?1)", -1, &pStmt, 0) ) {
#ifdef SQLITE_HAS_CODEC
        sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
        sqlite3_step(pStmt);
#else
        if (@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)) {
            sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
            sqlite3_step(pStmt);
        }
#endif
    }
    sqlite3_finalize(pStmt);
    return pRet;
}

typedef struct Fts5SOTokenizer Fts5SOTokenizer;
struct Fts5SOTokenizer {
    char locale[16];
    uint64_t mask;
    void *clazz;
};

static void so_fts5_xDelete(Fts5Tokenizer *p)
{
    sqlite3_free(p);
}

static int so_fts5_xCreate(
    void *pUnused,
    const char **azArg, int nArg,
    Fts5Tokenizer **ppOut
    )
{
    Fts5SOTokenizer *tok = sqlite3_malloc(sizeof(Fts5SOTokenizer));
    if (!tok) return SQLITE_NOMEM;

    memset(tok->locale, 0x0, 16);
    tok->mask = 0;

    for (int i = 0; i < MIN(2, nArg); i++) {
        const char *arg = azArg[i];
        uint32_t mask = (uint32_t)atol(arg);
        if (mask > 0) {
            tok->mask = mask;
        } else {
            strncpy(tok->locale, arg, 15);
        }
    }

    tok->clazz = pUnused;
    *ppOut = (Fts5Tokenizer *)tok;
    return SQLITE_OK;
}

static int so_fts5_xTokenize(
    Fts5Tokenizer *pTokenizer,
    void *pCtx,
    int iUnused,
    const char *pText, int nText,
    int (*xToken)(void *, int, const char *, int nToken, int iStart, int iEnd)
    )
{
    UNUSED_PARAM(iUnused);
    UNUSED_PARAM(pText);
    if (pText == 0) return SQLITE_OK;

    int rc = SQLITE_OK;
    Fts5SOTokenizer *tok = (Fts5SOTokenizer *)pTokenizer;
    Class<SQLiteORMEnumerator> clazz = (__bridge Class)(tok->clazz);
    if (!clazz || ![clazz conformsToProtocol:@protocol(SQLiteORMEnumerator)]) {
        return SQLITE_ERROR;
    }
    uint64_t mask = tok->mask;
    if ((mask & (1 << 1)) > 0) {
        if (iUnused & FTS5_TOKENIZE_QUERY) {
            mask = (mask & ~(1 << 1 | 1 << 2)) | (1 << 3);
        } else if (iUnused & FTS5_TOKENIZE_DOCUMENT) {
            mask = mask & ~(1 << 3);
        }
    }
    NSString *source = [NSString stringWithCString:pText];
    NSArray *array = [clazz enumerate:source mask:mask];

    for (SQLiteORMToken *tk in array) {
        rc = xToken(pCtx, tk.colocated <= 0 ? 0 : 1, tk.word, tk.len, tk.start, tk.end);
        if (rc != SQLITE_OK) break;
    }

    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

// MAKR: -
BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, Class<SQLiteORMEnumerator> enumerator, NSString *tokenizerName)
{
    sqlite3_tokenizer_module *module;
    module = (sqlite3_tokenizer_module *)sqlite3_malloc(sizeof(*module));
    module->iVersion = 0;
    module->xCreate = so_fts3_create;
    module->xDestroy = so_fts3_destroy;
    module->xOpen = so_fts3_open;
    module->xClose = so_fts3_close;
    module->xNext = so_fts3_next;
    module->xName = tokenizerName.UTF8String;
    module->xClass = (__bridge void *)enumerator;
    int rc = fts3_register_tokenizer(db, (char *)tokenizerName.UTF8String, module);

    BOOL ret =  (rc == SQLITE_OK) || (rc == SQLITE_ROW) || (rc == SQLITE_DONE);
#if DEBUG
    if (!ret) {
        printf("[SODB][Debug] fts3 register tokenizer `%s` failure.", tokenizerName.UTF8String);
    }
#endif
    fts5_api *pApi = fts5_api_from_db(db);
    if (!pApi) {
#if DEBUG
        printf("[SODB][Debug] fts5 is not supported\n");
#endif
        return ret;
    }
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    tokenizer->xCreate = so_fts5_xCreate;
    tokenizer->xDelete = so_fts5_xDelete;
    tokenizer->xTokenize = so_fts5_xTokenize;

    rc = pApi->xCreateTokenizer(pApi, tokenizerName.UTF8String, (__bridge void *)enumerator, tokenizer, NULL);
    BOOL ret1 = (rc == SQLITE_OK) || (rc == SQLITE_ROW) || (rc == SQLITE_DONE);
#if DEBUG
    if (!ret1) {
        printf("[SODB][Debug] fts5 register tokenizer `%s` failure.", tokenizerName.UTF8String);
    }
#endif
    return ret && ret1;
}

_Nullable Class<SQLiteORMEnumerator> SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName)
{
    fts5_api *pApi = fts5_api_from_db(db);
    if (!pApi) return nil;

    void *pUserdata = 0;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    int rc = pApi->xFindTokenizer(pApi, tokenizerName.UTF8String, &pUserdata, tokenizer);
    if (rc != SQLITE_OK) return nil;
    Class<SQLiteORMEnumerator> clazz = (__bridge Class)pUserdata;
    if (!clazz || ![clazz conformsToProtocol:@protocol(SQLiteORMEnumerator)]) {
        return nil;
    }
    return clazz;
}
