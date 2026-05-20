//
//  ANXLogHelper.m
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/11.
//

#import "ANXLogHelper.h"
#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import "mars/xlog/xloggerbase.h"
#import "mars/xlog/xlogger.h"
#import "mars/xlog/appender.h"
#else
#import <os/log.h>
#endif
#import <sys/xattr.h>

ANXLogHelperModule ANXLogHelperModuleWebDav = @"WebDav";
ANXLogHelperModule ANXLogHelperModuleHTTP = @"HTTP";
ANXLogHelperModule ANXLogHelperModuleSubtitle = @"Subtitle";
ANXLogHelperModule ANXLogHelperModuleSMB = @"SMB";
ANXLogHelperModule ANXLogHelperModuleUI = @"UI";
ANXLogHelperModule ANXLogHelperModulePlayer = @"Player";

static NSUInteger g_processID = 0;

@implementation ANXLogHelper

+ (void)logWithLevel:(ANXLogLevel)logLevel moduleName:(NSString *)moduleName fileName:(const char *)fileName lineNumber:(int)lineNumber funcName:(const char *)funcName message:(NSString *)message {
#if TARGET_OS_TV
    os_log_t log = os_log_create("com.dandanplay.anixplayer", moduleName.UTF8String);
    os_log_type_t type = OS_LOG_TYPE_DEFAULT;
    switch (logLevel) {
        case ANXLogLevelDebug: type = OS_LOG_TYPE_DEBUG; break;
        case ANXLogLevelInfo:  type = OS_LOG_TYPE_INFO; break;
        case ANXLogLevelError: type = OS_LOG_TYPE_ERROR; break;
        case ANXLogLevelFatal: type = OS_LOG_TYPE_FAULT; break;
        default: type = OS_LOG_TYPE_DEFAULT; break;
    }
    os_log_with_type(log, type, "%{public}s", message.UTF8String);
#else
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
#endif
}

+ (void)logWithLevel:(ANXLogLevel)logLevel moduleName:(NSString *)moduleName fileName:(const char *)fileName lineNumber:(int)lineNumber funcName:(const char *)funcName format:(NSString *)format, ... {

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
#if !TARGET_OS_TV
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
#endif
}

+ (void)close {
#if !TARGET_OS_TV
    mars::xlog::appender_close();
#endif
}

+ (void)flush {
#if !TARGET_OS_TV
    mars::xlog::appender_flush();
#endif
}

+ (BOOL)shouldLog:(ANXLogLevel)level {
#if TARGET_OS_TV
    return YES;
#else
    BOOL showLog = (TLogLevel)level >= xlogger_Level();
    return showLog;
#endif
}

@end
