//
//  SQLiteORM+FTS.h
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

typedef struct sqlite3 sqlite3;

NS_ASSUME_NONNULL_BEGIN

/**
 分词对象
 */
@interface SQLiteORMToken : NSObject
@property (nonatomic, copy) NSString *token;  ///< 分词
@property (nonatomic, assign) int len;  ///< 分词长度
@property (nonatomic, assign) int start; ///< 分词对应原始字符串的起始位置
@property (nonatomic, assign) int end; ///< 分词对应原始字符串的结束位置

+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end;
@end

/**
 注册分词器,fts3/4/5

 @param method 分词方法
 @param tokenizerName 分词器名称
 @return 是否注册成功
 */
BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, int method, NSString *tokenizerName);

/**
 枚举函数

 @param tokenizerName 分词器名称
 @return 分词方法
 */
int SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName);

NS_ASSUME_NONNULL_END
