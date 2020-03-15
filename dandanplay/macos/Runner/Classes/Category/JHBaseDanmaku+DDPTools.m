//
//  JHBaseDanmaku+DDPTools.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/8.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "JHBaseDanmaku+DDPTools.h"
#import <objc/message.h>

@implementation JHBaseDanmaku (DDPTools)
- (void)setFilter:(BOOL)filter {
    objc_setAssociatedObject(self, @selector(filter), @(filter), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)filter {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setSendByUserId:(NSUInteger)sendByUserId {
    objc_setAssociatedObject(self, @selector(sendByUserId), @(sendByUserId), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)sendByUserId {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}
@end
