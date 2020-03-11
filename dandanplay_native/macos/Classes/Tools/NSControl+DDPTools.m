//
//  NSControl+DDPTools.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/29.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "NSControl+DDPTools.h"
#import "DDPCategory.h"

@implementation NSControl (DDPTools)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleInstanceMethod:@selector(setStringValue:) with:@selector(ddp_setStringValue:)];
    });
}

- (void)addTarget:(id)target action:(SEL)action {
    self.target = target;
    self.action = action;
}

- (void)ddp_setStringValue:(NSString *)stringValue {
    if (stringValue == nil) {
        stringValue = @"";
    }
    
    [self ddp_setStringValue:stringValue];
}

@end
