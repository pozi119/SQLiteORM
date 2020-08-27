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
@property (nonatomic, assign) char *word;     ///< token word
@property (nonatomic, assign) int len;        ///<  token length ( c language length)
@property (nonatomic, assign) int start;      ///<  starting position of original string
@property (nonatomic, assign) int end;        ///< end position of original string
@property (nonatomic, assign) int colocated;  ///< -1:full width, 0:original, 1:full pinyin, 2:abbreviation, 3:syllable

@property (nonatomic, copy, readonly) NSString *token;

+ (instancetype)token:(const char *)token len:(int)len start:(int)start end:(int)end;

+ (NSArray<SQLiteORMToken *> *)sortedTokens:(NSArray<SQLiteORMToken *> *)tokens;

@end

@protocol SQLiteORMEnumerator <NSObject>

+ (NSArray<SQLiteORMToken *> *)enumerate:(const char *)input mask:(uint64_t)mask;

@end

/// register enumerator
BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, Class<SQLiteORMEnumerator> enumerator, NSString *tokenizerName);

/// get enumerator
_Nullable Class<SQLiteORMEnumerator> SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName);

NS_ASSUME_NONNULL_END
