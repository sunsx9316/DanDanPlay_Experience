//
//  ANXLogHelper.h
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ANXLogLevel) {
    ANXLogLevelAll = 0,
    ANXLogLevelVerbose = 0,
    ANXLogLevelDebug,    // Detailed information on the flow through the system.
    ANXLogLevelInfo,     // Interesting runtime events (startup/shutdown), should be conservative and keep to a minimum.
    ANXLogLevelWarn,     // Other runtime situations that are undesirable or unexpected, but not necessarily "wrong".
    ANXLogLevelError,    // Other runtime errors or unexpected conditions.
    ANXLogLevelFatal,    // Severe errors that cause premature termination.
    ANXLogLevelNone,     // Special level used to disable all log messages.
};

typedef NSString const * ANXLogHelperModule NS_TYPED_ENUM;

FOUNDATION_EXPORT ANXLogHelperModule ANXLogHelperModuleWebDav;
FOUNDATION_EXPORT ANXLogHelperModule ANXLogHelperModuleHTTP;

@interface ANXLogHelper : NSObject

+ (void)logWithLevel:(ANXLogLevel)logLevel
          moduleName:(ANXLogHelperModule)moduleName
            fileName:(const char *)fileName
          lineNumber:(int)lineNumber
            funcName:(const char *)funcName
             message:(NSString *)message NS_REFINED_FOR_SWIFT;

+ (void)logWithLevel:(ANXLogLevel)logLevel
          moduleName:(ANXLogHelperModule)moduleName
            fileName:(const char *)fileName
          lineNumber:(int)lineNumber
            funcName:(const char *)funcName
              format:(NSString *)format, ... NS_REFINED_FOR_SWIFT;

+ (NSString *)logPath;

+ (void)setup;
+ (void)close;
+ (void)flush;

@end

#define LogInternal(level, module, file, line, func, prefix, format, ...) \
do { \
    NSString *aMessage = [NSString stringWithFormat:@"%@%@", prefix, [NSString stringWithFormat:format, ##__VA_ARGS__, nil]]; \
    [LogHelper logWithLevel:level moduleName:module fileName:file lineNumber:line funcName:func message:aMessage]; \
} while(0)


#define ANXLogError(module, format, ...) LogInternal(ANXLogLevelError, module, __FILENAME__, __LINE__, __FUNCTION__, @"Error:", format, ##__VA_ARGS__)
#define ANXLogWarning(module, format, ...) LogInternal(ANXLogLevelWarn, module, __FILENAME__, __LINE__, __FUNCTION__, @"Warning:", format, ##__VA_ARGS__)
#define ANXLogInfo(module, format, ...) LogInternal(ANXLogLevelInfo, module, __FILENAME__, __LINE__, __FUNCTION__, @"Info:", format, ##__VA_ARGS__)
#define ANXLogDebug(module, format, ...) LogInternal(ANXLogLevelDebug, module, __FILENAME__, __LINE__, __FUNCTION__, @"Debug:", format, ##__VA_ARGS__)

NS_ASSUME_NONNULL_END
