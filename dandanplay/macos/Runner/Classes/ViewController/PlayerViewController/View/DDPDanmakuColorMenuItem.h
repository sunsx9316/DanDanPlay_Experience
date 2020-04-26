//
//  DDPDanmakuColorMenuItem.h
//  DanDanPlayForMac
//
//  Created by JimHuang on 16/3/3.
//  Copyright © 2016年 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DDPDanmakuColorMenuItem : NSMenuItem
@property (nonatomic, strong) NSColor *itemColor;

- (instancetype)initWithTitle:(NSString *)aString color:(NSColor *)color;
@end
