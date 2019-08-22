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
#define TOKEN_PINYIN_MAX_LENGTH  15
#endif

typedef struct sqlite3 sqlite3;

//MARK: - 分词器参数
#define EMFtsTokenParamNumber    (1 << 16)
#define EMFtsTokenParamTransform (1 << 17)
#define EMFtsTokenParamPinyin    0xFFFF

NS_ASSUME_NONNULL_BEGIN

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
