//
//  SQLiteORMJieba.m
//  EnigmaDatabase
//
//  Created by Valo on 2019/3/19.
//

#import "SQLiteORMJieba.h"
#include <string>
#include <vector>
#include "core/Jieba.hpp"

using namespace cppjieba;

@implementation SQLiteORMJieba

+ (cppjieba::Jieba *)tokenizer {
    static cppjieba::Jieba *_tokenizer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *currentBundle = [NSBundle bundleForClass:self];
        NSString *jiebaBundlePath = [currentBundle pathForResource:@"Jieba" ofType:@"bundle"];
        NSBundle *jiebaBundle = [NSBundle bundleWithPath:jiebaBundlePath];
        const char *dictPath = [jiebaBundle pathForResource:@"jieba.dict" ofType:@"utf8"].UTF8String;
        const char *hmmPath = [jiebaBundle pathForResource:@"hmm_model" ofType:@"utf8"].UTF8String;
        const char *userPath = [jiebaBundle pathForResource:@"user.dict" ofType:@"utf8"].UTF8String;
        const char *idfPath = [jiebaBundle pathForResource:@"idf" ofType:@"utf8"].UTF8String;
        const char *stopPath = [jiebaBundle pathForResource:@"stop_words" ofType:@"utf8"].UTF8String;

        _tokenizer = new Jieba(dictPath, hmmPath, userPath, idfPath, stopPath);
    });
    return _tokenizer;
}

+ (void)enumerateTokens:(const char *)string usingBlock:(BOOL (^)(const char *token, uint32_t offset, uint32_t len))block
{
    vector<Word> words;
    [SQLiteORMJieba tokenizer]->CutForSearch(string, words);
    unsigned long count = words.size();
    for (unsigned long i = 0; i < count; i++) {
        Word word = words[i];
        BOOL con = block(word.word.c_str(), word.offset, (uint32_t)word.word.size());
        if (!con) break;
    }
}

+ (void)preloading
{
    [SQLiteORMJieba enumerateTokens:"中文" usingBlock:^BOOL (const char *_Nonnull token, uint32_t offset, uint32_t len) {
        return YES;
    }];
}

@end
