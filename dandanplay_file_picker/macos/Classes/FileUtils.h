//
//  FileUtils.h
//  Pods
//
//  Created by Miguel Ruivo on 05/12/2018.
//

#ifdef DEBUG
#define Log(fmt, ...)            NSLog((@"\n\n***** " fmt @"\n* %s [Line %d]\n\n\n"), ##__VA_ARGS__, __PRETTY_FUNCTION__, __LINE__)
#else
#define Log(fmt, ...)
#endif

@interface FileUtils : NSObject 
+ (NSString *)resolveType:(NSString*)type;
+ (NSArray <NSString *>*)resolvePath:(NSArray<NSURL *> *)urls;
@end



