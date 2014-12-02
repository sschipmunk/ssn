//
//  SSNLogger.m
//  ssn
//
//  Created by lingminjun on 14/12/2.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import "SSNLogger.h"
#import "SSNRigidCache.h"
#import "NSFileManager+SSN.h"
#import <stdio.h>
#import "ssnlog.h"

NSString *const SSNDefaultLoggerDir = @"log";

NSString *const SSNDefaultLoggerScope = @"SSNDefaultLoggerScope";

#define SSN_LOGGER_PUTS_LINES       (1024)

@interface SSNFileHandler : NSObject
{
    NSString *_path;
    FILE *_fp;
    BOOL _isRead;
}

@property (nonatomic,readonly) BOOL isRead;

- (FILE *)getFile;

- (instancetype)initWithPath:(NSString *)path readonly:(BOOL)readonly;//只读打开
+ (instancetype)handlerWithPath:(NSString *)path readonly:(BOOL)readonly;//只读打开

@end

@implementation SSNFileHandler

- (instancetype)initWithPath:(NSString *)path readonly:(BOOL)readonly {
    NSAssert(path, @"请输入合理的path");
    self = [super init];
    if (self) {
        _path = path;
        _isRead = readonly;
        
        if (_isRead) {
            _fp = fopen([_path UTF8String], "rb");
        }
        else {
            _fp = fopen([_path UTF8String], "at+");
        }
        
        if (_fp == NULL)
        {
            //NSAssert(NO, @"未见打开失败");
        }
    }
    return self;
}

+ (instancetype)handlerWithPath:(NSString *)path readonly:(BOOL)readonly {
    return [[[self class] alloc] initWithPath:path readonly:readonly];
}

- (void)dealloc {
    if (_fp) {
        fclose(_fp);
        _fp = NULL;
    }
}

- (FILE *)getFile {
    if (_fp) {
        return _fp;
    }
    if (_isRead) {
        _fp = fopen([_path UTF8String], "rb");
    }
    else {
        _fp = fopen([_path UTF8String], "at+");
    }
    return _fp;
}

@end


@interface SSNLogger ()
@property (nonatomic,strong) SSNFileHandler *file;
@property (nonatomic,strong) NSString *scope;
@property (nonatomic) NSUInteger lines;//记录输入次数，防止文件过大

- (SSNFileHandler *)checkFileHandler;//返回一个可用的文件系统

- (instancetype)initWithScope:(NSString *)scope;

- (void)log:(SSNLoggerLevel)level string:(NSString *)string;

@end

@implementation SSNLogger

/**
 *  在Library/Caches/log下写日志，
 *  @param scope 日志级别
 *  @retaurn 对应Library/Caches/log下的日志目录
 */
+ (instancetype)sharedInstance {
    static SSNLogger *logger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[SSNLogger alloc] initWithScope:SSNDefaultLoggerScope];
    });
    return logger;
}

/**
 *  在Library/Caches/log/[scope]下写日志，不建议使用此方法
 *  @param scope 日志级别
 *  @retaurn 对应Library/Caches/log/[scope]下的日志目录
 */
+ (instancetype)loggerWithScope:(NSString *)scope {
    if ([scope length] == 0) {
        return nil;
    }
    
    static SSNRigidCache *logger_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger_cache = [[SSNRigidCache alloc] initWithConstructor:^id(id key, NSDictionary *userInfo) {
            return [[SSNLogger alloc] initWithScope:scope];
        }];
    });
    
    return [logger_cache objectForKey:scope];
}

#pragma mark init
- (instancetype)initWithScope:(NSString *)scope {
    NSAssert(scope, @"请传入正确的scope");
    self = [super init];
    if (self) {
        _scope = [scope copy];
    }
    return self;
}

#pragma mark 文件目录和大小控制，按照日期建目录
- (SSNFileHandler *)checkFileHandler {
    //需要加锁控制下
    @synchronized(self) { @autoreleasepool {
        
        _lines++;
        
        if (_lines > SSN_LOGGER_PUTS_LINES) {//需要重新生产一个file
            _file = nil;
        }
        
        if (_file) {
            return _file;
        }
        
        //新生产file
        char now_str[25] = {'\0'};
        char day_str[12] = {'\0'};
        ssn_log_get_file_name(now_str);
        strncpy(day_str, now_str, 10/* = strlen("yyyy-MM-dddd") */);
        
        NSString *day_dir = [NSString stringWithCString:day_str encoding:NSUTF8StringEncoding];
        NSString *file_name = [NSString stringWithCString:now_str encoding:NSUTF8StringEncoding];
        NSString *comp = SSNDefaultLoggerDir;
        if (_scope != SSNDefaultLoggerScope) {
            comp = [comp stringByAppendingPathComponent:_scope];
        }
        comp = [SSNDefaultLoggerDir stringByAppendingPathComponent:day_dir];
        
        NSString *path = [[NSFileManager defaultManager] pathCachesDirectoryWithPathComponents:comp];
        
        path = [path stringByAppendingPathComponent:file_name];
        
        printf("\n[log_path=%s]\n",[path UTF8String]);
        
        _file = [SSNFileHandler handlerWithPath:path readonly:NO];
        
        return _file;
    }}
    return nil;
}

#pragma mark log操作

/**
 *  Library/Caches/log目录scope目录中写日志，scope传入nil时默认在Library/Caches/log下写日志
 *  @param level 日志级别
 *  @param scope 日志目录
 *  @param format 日志format
 */
- (void)log:(SSNLoggerLevel)level format:(NSString *)format, ... {
    @autoreleasepool {
        va_list args;
        va_start(args, format);
        NSString *log = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        [self log:level string:log];
    }
}

/**
 *  Documents/log目录scope目录中写日志，scope传入nil时默认在Documents/log下写日志，不建议使用此方法
 *  @param level 日志级别
 *  @param scope 日志目录
 *  @param format 日志format
 */
- (void)focuslog:(SSNLoggerLevel)level format:(NSString *)format, ... {
    @autoreleasepool {
        va_list args;
        va_start(args, format);
        NSString *log = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        [self log:level string:log];
    }
}

- (void)log:(SSNLoggerLevel)level string:(NSString *)string {
    if (level == SSNErrorLogger || level == SSNVerboseLogger) {
        FILE *fp = [[self checkFileHandler] getFile];
        ssn_log_level lv = ssn_disk_log;
        if (level == SSNVerboseLogger) {
            lv = ssn_verbose_log;
        }
        ssn_file_puts_line(fp, lv, [string UTF8String]);
    }
    else {
        ssn_file_puts_line(NULL, ssn_console_log, [string UTF8String]);
    }
}

@end
