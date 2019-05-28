//
//  SQLiteORM+FTS.h
//  SQLiteORM
//
//  Created by Valo on 2019/5/21.
//

#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

#ifndef TOKEN_PINYIN_MAX_LENGTH
#define TOKEN_PINYIN_MAX_LENGTH 15
#endif

typedef struct sqlite3 sqlite3;

NS_ASSUME_NONNULL_BEGIN

/**
 FTS处理分词的函数

 @param token 分词字符串
 @param len 分词字符串的长度
 @param start 源字符串的起始位置
 @param end 源字符串的结束位置
 @return 是否继续分词, YES-继续,NO-终止
 */
typedef BOOL (^SQLiteORMXTokenHandler)(const char *token, int len, int start, int end);

/**
 FTS分词器核心函数

 @param pText 要分词的字符串,c string
 @param nText 要分词字符串的长度
 @param locale 是否需要进行本地化处理
 @param pinyin 是否要进行拼音分词
 @param handler 分词后的回调
 */
typedef void (*SQLiteORMXEnumerator)(const char *pText, int nText, const char *locale, BOOL pinyin, SQLiteORMXTokenHandler handler);

/**
 注册分词器,fts3/4/5

 @param enumerator 分词器的核心枚举函数
 @param tokenizerName 分词器名称
 @return 是否注册成功
 */
BOOL SQLiteORMRegisterEnumerator(sqlite3 *db, SQLiteORMXEnumerator enumerator, NSString *tokenizerName);

/**
 枚举函数

 @param tokenizerName 分词器名称
 @return 分词器的核心枚举函数
 */
SQLiteORMXEnumerator _Nullable SQLiteORMFindEnumerator(sqlite3 *db, NSString *tokenizerName);

/**
 使用分词器高亮搜索结果

 @param objects 搜索结果,[[String:Binding]]数组
 @param field 要高亮的字段
 @param keyword 搜索使用的关键字
 @param pinyinMaxLen 进行拼音分词的最大utf8字符串长度
 @param enumerator 分词器核心枚举方法
 @param attributes 高亮参数
 @return 属性文本数组
 */
NSArray<NSAttributedString *> * SQLiteORMHighlight(NSArray *objects,
                                                   NSString *field,
                                                   NSString *keyword,
                                                   int pinyinMaxLen,
                                                   SQLiteORMXEnumerator enumerator,
                                                   NSDictionary<NSAttributedStringKey, id> *attributes);

NS_ASSUME_NONNULL_END
