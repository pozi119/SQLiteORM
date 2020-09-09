//
//  FTS3.h
//  SQLiteORM
//
//  Created by Valo on 2020/9/9.
//

#ifdef SQLITE_HAS_CODEC
#import <SQLCipher/sqlite3.h>
#else
#import <sqlite3.h>
#endif

static inline int SQLiteORMEnableFts3Module(sqlite3 *db) {
    return sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 1, 0);
}

