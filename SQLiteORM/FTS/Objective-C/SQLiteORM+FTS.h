//
//  SQLiteORM+FTS.h
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

typedef struct sqlite3 sqlite3;

NS_ASSUME_NONNULL_BEGIN

/// token
@interface SQLiteORMToken : NSObject
@property (nonatomic, copy) NSString *token;  ///< token word
@property (nonatomic, assign) int len;  ///<  token length ( c language length)
@property (nonatomic, assign) int start; ///<  starting position of original string
@property (nonatomic, assign) int end; ///< end position of original string

+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end;

+ (NSArray<SQLiteORMToken *> *)sortedTokens:(NSArray<SQLiteORMToken *> *)tokens;

@end

/// register tokenizer
/// @param method tokenize method, 1-apple, 2-natural, 4-sqliteorm
BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, int method, NSString *tokenizerName);

/// get tokenize method
int SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName);

NS_ASSUME_NONNULL_END
