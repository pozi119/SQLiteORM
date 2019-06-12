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

static const char *kPinYinArg = "pinyin";

/**
 分词对象
 */
@interface SQLiteORMToken : NSObject
@property (nonatomic, assign) const char *token;  ///< 分词
@property (nonatomic, assign) int len;  ///< 分词长度
@property (nonatomic, assign) int start; ///< 分词对应原始字符串的起始位置
@property (nonatomic, assign) int end; ///< 分词对应原始字符串的结束位置
@end

@implementation SQLiteORMToken

- (void)dealloc
{
    free((void *)_token);
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
    SQLiteORMXEnumerator xEnumerator;
};

struct sqlite3_tokenizer {
    const sqlite3_tokenizer_module *pModule;  /* The module for this tokenizer */
};

struct sqlite3_tokenizer_cursor {
    sqlite3_tokenizer *pTokenizer;            /* Tokenizer for this cursor. */
};

typedef struct vv_fts3_tokenizer {
    sqlite3_tokenizer base;
    char locale[16];
    bool pinyin;
    int pinyinMaxLen;
} vv_fts3_tokenizer;

typedef struct vv_fts3_tokenizer_cursor {
    sqlite3_tokenizer_cursor base;  /* base cursor */
    const char *pInput;             /* input we are tokenizing */
    int nBytes;                     /* size of the input */
    int iToken;                     /* index of current token*/
    int nToken;                     /* count of token */
    CFArrayRef tokens;
} vv_fts3_tokenizer_cursor;

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

static int vv_fts3_create(
    int argc, const char *const *argv,
    sqlite3_tokenizer **ppTokenizer
    )
{
    vv_fts3_tokenizer *tok;
    UNUSED_PARAM(argc);
    UNUSED_PARAM(argv);

    tok = (vv_fts3_tokenizer *)sqlite3_malloc(sizeof(*tok));
    if (tok == NULL) return SQLITE_NOMEM;
    memset(tok, 0, sizeof(*tok));

    memset(tok->locale, 0x0, 16);
    tok->pinyin = false;
    tok->pinyinMaxLen = 0;

    int idx = -1;
    for (int i = 0; i < MIN(3, argc); i++) {
        const char *arg = argv[i];
        if (strcmp(arg, kPinYinArg) == 0) {
            idx = i;
            tok->pinyin = true;
        } else {
            if (tok->pinyin && i == idx + 1) {
                tok->pinyinMaxLen = atoi(arg);
            } else if (i == 0) {
                strncpy(tok->locale, arg, 15);
            }
        }
    }
    if (tok->pinyin && tok->pinyinMaxLen <= 0) {
        tok->pinyinMaxLen = TOKEN_PINYIN_MAX_LENGTH;
    }

    *ppTokenizer = &tok->base;
    return SQLITE_OK;
}

static int vv_fts3_destroy(sqlite3_tokenizer *pTokenizer)
{
    sqlite3_free(pTokenizer);
    return SQLITE_OK;
}

static int vv_fts3_open(
    sqlite3_tokenizer *pTokenizer,                                                  /* The tokenizer */
    const char *pInput, int nBytes,                                                 /* String to be tokenized */
    sqlite3_tokenizer_cursor **ppCursor                                             /* OUT: Tokenization cursor */
    )
{
    UNUSED_PARAM(pTokenizer);
    if (pInput == 0) return SQLITE_ERROR;

    vv_fts3_tokenizer_cursor *c;
    c = (vv_fts3_tokenizer_cursor *)sqlite3_malloc(sizeof(*c));
    if (c == NULL) return SQLITE_NOMEM;

    const sqlite3_tokenizer_module *module = pTokenizer->pModule;
    SQLiteORMXEnumerator enumerator = module->xEnumerator;
    if (!enumerator) {
        return SQLITE_ERROR;
    }

    int nInput = (pInput == 0) ? 0 : (nBytes < 0 ? (int)strlen(pInput) : nBytes);

    vv_fts3_tokenizer *tok = (vv_fts3_tokenizer *)pTokenizer;
    BOOL tokenPinyin = tok->pinyin && (nInput <= tok->pinyinMaxLen);
    __block NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];

    SQLiteORMXTokenHandler handler = ^(const char *token, int len, int start, int end) {
        char *_token = (char *)malloc(len + 1);
        memcpy(_token, token, len);
        _token[len] = 0;
        SQLiteORMToken *t = [SQLiteORMToken new];
        t.token = _token;
        t.len = len;
        t.start = start;
        t.end = end;
        [array addObject:t];
        return YES;
    };

    enumerator(pInput, nBytes, tok->locale, tokenPinyin, handler);

    c->pInput = pInput;
    c->nBytes = nInput;
    c->iToken = 0;
    c->nToken = (int)array.count;
    c->tokens = (__bridge_retained CFArrayRef)array;

    *ppCursor = &c->base;
    return SQLITE_OK;
}

static int vv_fts3_close(sqlite3_tokenizer_cursor *pCursor)
{
    vv_fts3_tokenizer_cursor *c = (vv_fts3_tokenizer_cursor *)pCursor;
    CFRelease(c->tokens);
    sqlite3_free(c);
    return SQLITE_OK;
}

static int vv_fts3_next(
    sqlite3_tokenizer_cursor *pCursor,                                                  /* Cursor returned by vv_fts3_open */
    const char               **ppToken,                                                 /* OUT: *ppToken is the token text */
    int                      *pnBytes,                                                  /* OUT: Number of bytes in token */
    int                      *piStartOffset,                                            /* OUT: Starting offset of token */
    int                      *piEndOffset,                                              /* OUT: Ending offset of token */
    int                      *piPosition                                                /* OUT: Position integer of token */
    )
{
    vv_fts3_tokenizer_cursor *c = (vv_fts3_tokenizer_cursor *)pCursor;
    NSArray *array = (__bridge NSArray *)(c->tokens);
    if (array.count == 0 || c->iToken == array.count) return SQLITE_DONE;
    SQLiteORMToken *t = array[c->iToken];
    *ppToken = t.token;
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
        if (@available(iOS 12.0, *)) {
            sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
            sqlite3_step(pStmt);
        }
#endif
    }
    sqlite3_finalize(pStmt);
    return pRet;
}

typedef struct Fts5VVTokenizer Fts5VVTokenizer;
struct Fts5VVTokenizer {
    char locale[16];
    bool pinyin;
    int pinyinMaxLen;
    SQLiteORMXEnumerator enumerator;
};

static void vv_fts5_xDelete(Fts5Tokenizer *p)
{
    sqlite3_free(p);
}

static int vv_fts5_xCreate(
    void *pUnused,
    const char **azArg, int nArg,
    Fts5Tokenizer **ppOut
    )
{
    Fts5VVTokenizer *tok = sqlite3_malloc(sizeof(Fts5VVTokenizer));
    if (!tok) return SQLITE_NOMEM;
    memset(tok->locale, 0x0, 16);
    tok->pinyin = false;
    tok->pinyinMaxLen = 0;

    int idx = -1;
    for (int i = 0; i < MIN(3, nArg); i++) {
        const char *arg = azArg[i];
        if (strcmp(arg, kPinYinArg) == 0) {
            idx = i;
            tok->pinyin = true;
        } else {
            if (tok->pinyin && i == idx + 1) {
                tok->pinyinMaxLen = atoi(arg);
            } else if (i == 0) {
                strncpy(tok->locale, arg, 15);
            }
        }
    }
    if (tok->pinyin && tok->pinyinMaxLen <= 0) {
        tok->pinyinMaxLen = TOKEN_PINYIN_MAX_LENGTH;
    }

    SQLiteORMXEnumerator enumerator = (SQLiteORMXEnumerator)pUnused;
    if (!enumerator) return SQLITE_ERROR;

    tok->enumerator = enumerator;
    *ppOut = (Fts5Tokenizer *)tok;
    return SQLITE_OK;
}

static int vv_fts5_xTokenize(
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

    __block int rc = SQLITE_OK;
    Fts5VVTokenizer *tok = (Fts5VVTokenizer *)pTokenizer;
    int nInput = (pText == 0) ? 0 : (nText < 0 ? (int)strlen(pText) : nText);
    BOOL tokenPinyin = tok->pinyin && (nInput <= tok->pinyinMaxLen) && (iUnused & FTS5_TOKENIZE_DOCUMENT);

    SQLiteORMXEnumerator enumerator = tok->enumerator;
    SQLiteORMXTokenHandler handler = ^(const char *token, int len, int start, int end) {
        rc = xToken(pCtx, iUnused, token, len, start, end);
        return (BOOL)(rc == SQLITE_OK || rc == SQLITE_ROW || rc == SQLITE_DONE);
    };

    enumerator(pText, nText, tok->locale, tokenPinyin, handler);

    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

// MAKR: -
static inline BOOL check(int resultCode)
{
    switch (resultCode) {
        case SQLITE_OK:
        case SQLITE_ROW:
        case SQLITE_DONE:
            return YES;

        default:
            return NO;
    }
}

static NSMutableDictionary * enumerators()
{
    static NSMutableDictionary *_enumerators;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _enumerators = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    return _enumerators;
}

BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, SQLiteORMXEnumerator enumerator, NSString *tokenizerName)
{
    char *name = (char *)tokenizerName.UTF8String;

    sqlite3_tokenizer_module *module;
    module = (sqlite3_tokenizer_module *)sqlite3_malloc(sizeof(*module));
    module->iVersion = 0;
    module->xCreate = vv_fts3_create;
    module->xDestroy = vv_fts3_destroy;
    module->xOpen = vv_fts3_open;
    module->xClose = vv_fts3_close;
    module->xNext = vv_fts3_next;
    module->xName = name;
    module->xEnumerator = enumerator;
    int rc = fts3_register_tokenizer(db, name, module);

    BOOL ret =  check(rc);
    if (!ret) return ret;

    fts5_api *pApi = fts5_api_from_db(db);
    if (!pApi) return NO;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    tokenizer->xCreate = vv_fts5_xCreate;
    tokenizer->xDelete = vv_fts5_xDelete;
    tokenizer->xTokenize = vv_fts5_xTokenize;

    rc = pApi->xCreateTokenizer(pApi,
                                name,
                                (void *)enumerator,
                                tokenizer,
                                0);
    ret = check(rc);
    if (ret) {
        NSMutableDictionary *dic = enumerators();
        dic[tokenizerName] = [NSString stringWithFormat:@"%p", enumerator];
    }
    return ret;
}

SQLiteORMXEnumerator SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName)
{
    fts5_api *pApi = fts5_api_from_db(db);
    if (!pApi) return nil;

    void *pUserdata = 0;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    int rc = pApi->xFindTokenizer(pApi, tokenizerName.UTF8String, &pUserdata, tokenizer);
    if (rc != SQLITE_OK) return nil;

    NSMutableDictionary *dic = enumerators();
    NSString *addr = [NSString stringWithFormat:@"%p", pUserdata];
    NSString *mapped = dic[tokenizerName];
    if (![addr isEqualToString:mapped]) return nil;

    return (SQLiteORMXEnumerator)pUserdata;
}

// MARK: -
static NSArray<SQLiteORMToken *> * tokenize(NSString *source, BOOL pinyin, SQLiteORMXEnumerator enumerator);

static NSAttributedString * highlightOne(NSString *source,
                                         int pyMaxLen,
                                         SQLiteORMXEnumerator enumerator,
                                         NSArray<SQLiteORMToken *> *keywordTokens,
                                         NSDictionary<NSAttributedStringKey, id> *attributes);

NSArray<NSAttributedString *> * SQLiteORMHighlight(NSArray *objects,
                                                   NSString *field,
                                                   NSString *keyword,
                                                   int pinyinMaxLen,
                                                   SQLiteORMXEnumerator enumerator,
                                                   NSDictionary<NSAttributedStringKey, id> *attributes)
{
    NSArray *keywordTokens = tokenize(keyword, NO, enumerator);
    int pymlen = pinyinMaxLen >= 0 ? : TOKEN_PINYIN_MAX_LENGTH;

    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *obj in objects) {
        NSString *source = [obj valueForKey:field];
        NSAttributedString *attrText = highlightOne(source, pymlen, enumerator, keywordTokens, attributes);
        [results addObject:attrText];
    }
    return results;
}

static NSArray<SQLiteORMToken *> * tokenize(NSString *source, BOOL pinyin, SQLiteORMXEnumerator enumerator)
{
    const char *pText = source.UTF8String;
    int nText = (int)strlen(pText);
    
    if (nText == 0) {
        return @[];
    }
    
    if (!enumerator) {
        SQLiteORMToken *ormToken = [SQLiteORMToken new];
        ormToken.token = pText;
        ormToken.len = nText;
        ormToken.start = 0;
        ormToken.end = nText;
        return @[ormToken];
    }

    __block NSMutableArray<SQLiteORMToken *> *results = [NSMutableArray arrayWithCapacity:0];

    SQLiteORMXTokenHandler handler = ^(const char *token, int len, int start, int end) {
        char *_token = (char *)malloc(len + 1);
        memcpy(_token, token, len);
        _token[len] = 0;
        SQLiteORMToken *ormToken = [SQLiteORMToken new];
        ormToken.token = _token;
        ormToken.len = len;
        ormToken.start = start;
        ormToken.end = end;
        [results addObject:ormToken];
        return YES;
    };
    enumerator(pText, nText, "", pinyin, handler);
    return results;
}

static NSAttributedString * highlightOne(NSString *source,
                                         int pyMaxLen,
                                         SQLiteORMXEnumerator enumerator,
                                         NSArray<SQLiteORMToken *> *keywordTokens,
                                         NSDictionary<NSAttributedStringKey, id> *attributes)
{
    const char *pText = source.UTF8String;
    int nText = (int)strlen(pText);

    if (nText == 0) {
        return [[NSAttributedString alloc] init];
    }

    if (!enumerator) {
        return [[NSAttributedString alloc] initWithString:source];
    }

    __block char *tokenized = (char *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    SQLiteORMXTokenHandler handler = ^(const char *token, int len, int start, int end) {
        for (SQLiteORMToken *kwToken in keywordTokens) {
            if (strncmp(token, kwToken.token, kwToken.len) != 0) continue;
            memcpy(tokenized + start, pText + start, end - start);
        }
        return YES;
    };

    enumerator(pText, nText, "", nText < pyMaxLen, handler);

    char *remained = (char *)malloc(nText + 1);
    strncpy(remained, pText, nText);
    remained[nText] = 0x0;
    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] != 0) {
            memset(remained + i, 0x0, 1);
        }
    }
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    int pos = 0;
    while (pos < nText) {
        if (remained[pos] != 0x0) {
            NSString *str = [NSString stringWithUTF8String:(remained + pos)];
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str]];
            pos += strlen(remained + pos);
        } else {
            NSString *str = [NSString stringWithUTF8String:(tokenized + pos)];
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attributes]];
            pos += strlen(tokenized + pos);
        }
    }
    free(remained);

    return attrText;
}
