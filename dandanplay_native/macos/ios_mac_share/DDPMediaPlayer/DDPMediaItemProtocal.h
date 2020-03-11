//
//  DDPMediaItemProtocal.h
//  DanDanPlayForiOS
//
//  Created by JimHuang on 2019/10/28.
//  Copyright © 2019 JimHuang. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol DDPMediaItemProtocol <NSObject>

@property (nonatomic, strong, readonly) NSURL * _Nullable url;
@property (nonatomic, strong, readonly) NSDictionary * _Nullable mediaOptions;
@end
NS_ASSUME_NONNULL_END
