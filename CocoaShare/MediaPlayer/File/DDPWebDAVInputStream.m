//
//  DDPWebDAVInputStream.m
//  DDPlay
//
//  Created by JimHuang on 2020/5/30.
//  Copyright © 2020 JimHuang. All rights reserved.
//

#import "DDPWebDAVInputStream.h"
#import <YYCategories/YYCategories.h>

static NSUInteger kDefaultDownloadSize = 20 * 1024 * 1024;

#ifdef DEBUG
#define TestLog(...) NSLog(__VA_ARGS__)
#else
#define TestLog(...)
#endif

@interface DDPPartTask : NSObject
@property (nonatomic, assign, readonly) NSRange range;
@property (nonatomic, assign, readonly) NSInteger index;
@property (atomic, assign) BOOL cached;
@property (atomic, assign, getter=isRequesting) BOOL requesting;

- (instancetype)initWithRange:(NSRange)range index:(NSInteger)index;
@end

@implementation DDPPartTask

- (instancetype)initWithRange:(NSRange)range index:(NSInteger)index {
    self = [super init];
    if (self) {
        _range = range;
        _index = index;
    }
    return self;
}

- (NSString *)description {
    NSString* rangeString = [NSString stringWithFormat:@"bytes=%@-%@", @(_range.location), @(NSMaxRange(_range))];
    return [NSString stringWithFormat:@"range: %@, index: %@", rangeString, @(_index)];
}

@end

@interface DDPWebDAVInputStream ()
@property (weak, nonatomic) id<DDPWebDAVInputStreamFile> file;
@property (nonatomic, assign) NSUInteger readOffset;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSUInteger fileLength;
@property (nonatomic, strong) NSDictionary <NSNumber *, DDPPartTask *>*cacheRangeDic;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSString *cachePath;
@property (assign, atomic) NSStreamStatus _streamStatus;
@property (weak, nonatomic) id<NSStreamDelegate> _delegate;
@end

@implementation DDPWebDAVInputStream

@synthesize streamError = _streamError;

- (instancetype)initWithFile:(id<DDPWebDAVInputStreamFile>)file {
    self = [super initWithURL:file.url];
    if (self) {
        _file = file;
        _url = file.url;
        [self setupInit];
        [self generateTasksWithFileLength:file.fileSize];
    }
    return self;
}

- (void)setupInit {
    _cachePath = UIApplication.sharedApplication.cachesPath;
    _cachePath = [_cachePath stringByAppendingPathComponent:self.url.lastPathComponent];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_cachePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_cachePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:_cachePath contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:_cachePath];
    self.inputStream = [NSInputStream inputStreamWithFileAtPath:_cachePath];
}

- (NSStreamStatus)streamStatus {
    return self._streamStatus;
}

- (void)open {
    self._streamStatus = NSStreamStatusOpen;
    [self.inputStream open];
}

- (BOOL)hasBytesAvailable {
    if (self.fileLength > 0) {
        return self.fileLength - _readOffset > 0;
    }
    return YES;
}

- (id)propertyForKey:(NSString *)key {
    if (![key isEqualToString:NSStreamFileCurrentOffsetKey]) {
        return nil;
    }
    return @(_readOffset);
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    if (![key isEqualToString:NSStreamFileCurrentOffsetKey]) {
        return NO;
    }
    
    if (![property isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    
    NSUInteger requestedOffest = [property unsignedIntegerValue];
    self.readOffset = requestedOffest;
    return YES;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)bufferLength {
    return NO;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)maxLength {
    
    NSRange dataRange = NSMakeRange(_readOffset, MIN(maxLength, MAX(self.fileLength - _readOffset, 0)));
    //    TestLog(@"读取 %@", [NSValue valueWithRange:dataRange]);
    
    if (self.fileLength > 0 && _readOffset >= self.fileLength) {
        self._streamStatus = NSStreamStatusAtEnd;
        return 0;
    }
    
    
    NSInteger lower = dataRange.location / kDefaultDownloadSize;
    NSInteger upper = NSMaxRange(dataRange) / kDefaultDownloadSize;
    
    //    TestLog(@"lower %ld, upper %ld", lower, upper);
    NSMutableArray <DDPPartTask *>*shouldDownloadTasks = [NSMutableArray array];
    for (NSInteger i = lower; i <= upper; ++i) {
        NSNumber *key = @(i);
        DDPPartTask *aTask = self.cacheRangeDic[key];
        
        if (!aTask.cached && !aTask.isRequesting) {
            [shouldDownloadTasks addObject:aTask];
        }
    }
    
    if (shouldDownloadTasks.count > 0) {
        
        __block NSInteger totalCount = (NSInteger)shouldDownloadTasks.count;
        
        [shouldDownloadTasks enumerateObjectsUsingBlock:^(DDPPartTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self getPartOfFileWithTask:obj progressHandler:^(CGFloat progress) {
            } completion:^(DDPPartTask *task) {
                totalCount--;
            }];
        }];
        
        while (totalCount > 0 && self.streamStatus != NSStreamStatusClosed) {}
        
        if (self._streamStatus == NSStreamStatusClosed) {
            return 0;
        }
    }
    
    
    __unused NSInteger result = [self.inputStream read:buffer maxLength:dataRange.length];
//    TestLog(@"read result %ld", result);
    self.readOffset += dataRange.length;
    return dataRange.length;
}

- (void)setReadOffset:(NSUInteger)readOffset {
    _readOffset = readOffset;
    [self.inputStream setProperty:@(_readOffset) forKey:NSStreamFileCurrentOffsetKey];
}

- (void)dealloc {
    TestLog(@"dealloc stream");
    self._streamStatus = NSStreamStatusClosed;
    [self.inputStream close];
    [self.fileHandle closeFile];
}

- (void)close {
    TestLog(@"close stream");
    self._streamStatus = NSStreamStatusClosed;
    [self.inputStream close];
    [self.fileHandle closeFile];
    if ([self._delegate respondsToSelector:@selector(stream:handleEvent:)]) {
        [self._delegate stream:self handleEvent:NSStreamEventEndEncountered];
    }
    
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
    self._delegate = delegate;
}

- (id<NSStreamDelegate>)delegate {
    return self._delegate;
}

#pragma mark - Private Method
- (void)generateTasksWithFileLength:(NSInteger)fileLength {
    
    if (fileLength == 0) {
        self.cacheRangeDic = @{};
        return;
    }
    
    self.fileLength = fileLength;
    
    NSInteger taskCount = ceil(fileLength * 1.0 / kDefaultDownloadSize);
    NSMutableDictionary<NSNumber *,DDPPartTask *> *taskDic = [NSMutableDictionary dictionaryWithCapacity:taskCount];
    
    if (taskCount == 0) {
        NSRange tmpRange = NSMakeRange(0, fileLength - 1);
        taskDic[@(0)] = [[DDPPartTask alloc] initWithRange:tmpRange index:0];
    } else {
        for (NSInteger i = 0; i < taskCount; ++i) {
            NSRange tmpRange = NSMakeRange(i * kDefaultDownloadSize, kDefaultDownloadSize - 1);
            //最后一个range.length不一定是kDefaultDownloadSize的整数倍，需要根据文件实际长度处理
            if (i == taskCount - 1) {
                tmpRange.length = fileLength - tmpRange.location - 1;
            }
            
            taskDic[@(i)] = [[DDPPartTask alloc] initWithRange:tmpRange index:i];
        }
    }
    
    self.cacheRangeDic = taskDic;
}

- (void)getPartOfFileWithTask:(DDPPartTask *)task
              progressHandler:(void(^)(CGFloat progress))progressHandler
                   completion:(void(^)(DDPPartTask *task))completion {
    
    if (task.cached) {
        
        if (progressHandler) {
            progressHandler(1);
        }
        
        if (completion) {
            completion(task);
        }
        return;
    }
    
    //当前正在下载
    if (task.isRequesting) {
        return;
    }
    
    task.requesting = YES;
    
    TestLog(@"=== 开始下载 %@", task);
    @weakify(self)
    
    [self.file requestDataWithRange:task.range progressHandle:^(double progress) {
        if (progressHandler) {
            progressHandler(progress);
        }
    } completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        @strongify(self)
        if (!self) {
            if (completion) {
                completion(task);
            }
            return;
        }
        
        task.requesting = NO;
        
        if (data.length > 0) {
            task.cached = YES;
            
            [self.fileHandle seekToFileOffset:task.range.location];
            [self.fileHandle writeData:data];
            [self.fileHandle synchronizeFile];
        }
        
        if (completion) {
            completion(task);
        }
        
        TestLog(@"=== 下载完成 %@, data: %ld", task, data.length);
    }];
}

@end
