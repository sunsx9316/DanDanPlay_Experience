//
//  NSView+DDPTools.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/27.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "NSView+DDPTools.h"

@implementation NSView (DDPTools)

+ (instancetype)loadFromNib {
    NSArray *arr = nil;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
//    NSString *bundlePath = [bundle pathForResource:@"DDPlayModule" ofType:@"bundle"];
//    if (bundlePath.length == 0) {
//        bundle = [NSBundle bundleWithPath:bundlePath];
//    }
    NSString *nibName = NSStringFromClass(self);
    if ([nibName containsString:@"."]) {
        nibName = [nibName componentsSeparatedByString:@"."].lastObject;
    }
    if ([bundle loadNibNamed:nibName owner:nil topLevelObjects:&arr]) {
        for (NSView *view in arr) {
            if ([view isKindOfClass:self]) {
                return view;
            }
        }
    };
    return nil;
}

@end
