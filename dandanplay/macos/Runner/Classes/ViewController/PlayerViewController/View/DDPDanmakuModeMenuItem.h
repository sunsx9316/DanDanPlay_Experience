//
//  DDPDanmakuModeMenuItem.h
//  DanDanPlayForMac
//
//  Created by JimHuang on 16/3/3.
//  Copyright © 2016年 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDPPlayerConstant.h"

@interface DDPDanmakuModeMenuItem : NSMenuItem
@property (assign, nonatomic, readonly) DDPDanmakuMode mode;

- (instancetype)initWithMode:(DDPDanmakuMode)mode title:(NSString *)title;
@end
