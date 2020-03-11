//
//  JHBaseDanmaku+DDPTools.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/8.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <JHDanmakuRender/JHBaseDanmaku.h>

NS_ASSUME_NONNULL_BEGIN

@interface JHBaseDanmaku (DDPTools)
/**
 是否过滤
 */
@property (assign, nonatomic) BOOL filter;

/**
 由用户发送时需要指定一个id
 */
@property (assign, nonatomic) NSUInteger sendByUserId;
@end

NS_ASSUME_NONNULL_END
