//
//  ANXLogHelper.m
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/11.
//

#import "ANXLogHelper.h"
#import "mars/xlog/xloggerbase.h"
#import "mars/xlog/xlogger.h"
#import "mars/xlog/appender.h"
#import <sys/xattr.h>

ANXLogHelperModule ANXLogHelperModuleWebDav = @"WebDav";



static NSUInteger g_processID = 0;

@implementation ANXLogHelper

+ (void)logWithLevel:(ANXLogLevel)logLevel moduleName:(nonnull ANXLogHelperModule)moduleName fileName:(nonnull const char *)fileName lineNumber:(int)lineNumber funcName:(nonnull const char *)funcName message:(nonnull NSString *)message {
    XLoggerInfo info;
    info.level = (TLogLevel)logLevel;
    info.tag = moduleName.UTF8String;
    info.filename = fileName;
    info.func_name = funcName;
    info.line = lineNumber;
    gettimeofday(&info.timeval, NULL);
    info.tid = (uintptr_t)[NSThread currentThread];
    info.maintid = (uintptr_t)[NSThread mainThread];
    info.pid = g_processID;
    xlogger_Write(&info, message.UTF8String);
}

+ (void)logWithLevel:(ANXLogLevel)logLevel moduleName:(nonnull ANXLogHelperModule)moduleName fileName:(nonnull const char *)fileName lineNumber:(int)lineNumber funcName:(nonnull const char *)funcName format:(nonnull NSString *)format, ... {
    
    va_list argList;
    va_start(argList, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:argList];
    [self logWithLevel:logLevel moduleName:moduleName fileName:fileName lineNumber:lineNumber funcName:funcName message:message];
    va_end(argList);
}

+ (NSString *)logPath {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"log"];
    return documentsPath;
}

+ (void)setup {
    NSString *logPath = [self logPath];
    NSString *attrName = @"com.apple.MobileBackup";
    size_t attrValue = 1;
    setxattr(logPath.UTF8String, attrName.UTF8String, &attrValue, sizeof(attrValue), 0, 0);
    
#if DEBUG
    xlogger_SetLevel(kLevelDebug);
    mars::xlog::appender_set_console_log(true);
#else
    xlogger_SetLevel(kLevelInfo);
    mars::xlog::appender_set_console_log(false);
#endif
    
    mars::xlog::XLogConfig config;
    config.mode_ = mars::xlog::kAppenderAsync;
    config.logdir_ = [logPath UTF8String];
    config.nameprefix_ = "AniX";
    config.pub_key_ = "";
    config.compress_mode_ = mars::xlog::kZlib;
    config.compress_level_ = 0;
    config.cachedir_ = "";
    config.cache_days_ = 20;
    appender_open(config);
}

+ (void)close {
    mars::xlog::appender_close();
}

+ (void)flush {
    mars::xlog::appender_flush();
}

+ (BOOL)shouldLog:(ANXLogLevel)level {
    BOOL showLog = (TLogLevel)level >= xlogger_Level();
    return showLog;
}

@end
