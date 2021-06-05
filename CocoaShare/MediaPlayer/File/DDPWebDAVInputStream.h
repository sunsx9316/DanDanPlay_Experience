//
//  DDPWebDAVInputStream.h
//  DDPlay
//
//  Created by JimHuang on 2020/5/30.
//  Copyright © 2020 JimHuang. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DDPWebDAVInputStreamFile <NSObject>
@property (strong, nonatomic, readonly) NSURL *url;
@property (assign, nonatomic, readonly) NSInteger fileSize;
- (void)requestDataWithRange:(NSRange)range
              progressHandle:(void(^)(double progress))progress
                  completion:(void(^)(NSData * _Nullable data, NSError * _Nullable error))completion;
@end

@interface DDPWebDAVInputStream : NSInputStream

@property (nonatomic, strong, readonly) NSURL *url;

- (instancetype)initWithFile:(id<DDPWebDAVInputStreamFile>)file;
@end

NS_ASSUME_NONNULL_END
