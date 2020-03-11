//
//  DDPDanmakuModeMenuItem.m
//  DanDanPlayForMac
//
//  Created by JimHuang on 16/3/3.
//  Copyright © 2016年 JimHuang. All rights reserved.
//

#import "DDPDanmakuModeMenuItem.h"

@implementation DDPDanmakuModeMenuItem

- (instancetype)initWithMode:(DDPDanmakuMode)mode title:(NSString *)title{
    if (self = [super initWithTitle:title action:nil keyEquivalent:@""]) {
        _mode = mode;
    }
    return self;
}

@end
