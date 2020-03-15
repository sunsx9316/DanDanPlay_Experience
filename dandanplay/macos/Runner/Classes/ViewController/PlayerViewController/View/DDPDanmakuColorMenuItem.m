//
//  DDPDanmakuColorMenuItem.m
//  DanDanPlayForMac
//
//  Created by JimHuang on 16/3/3.
//  Copyright © 2016年 JimHuang. All rights reserved.
//

#import "DDPDanmakuColorMenuItem.h"
#import "NSColor+DDPTools.h"

@implementation DDPDanmakuColorMenuItem
{
    NSColor *_itemColor;
}

- (instancetype)initWithTitle:(NSString *)aString color:(NSColor *)color{
    if (self = [super initWithTitle:aString action:nil keyEquivalent:@""]) {
        _itemColor = color;
        [self setItemColor:color];
    }
    return self;
}

- (void)setItemColor:(NSColor *)color{
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(30, 10)];
    [image lockFocus];
    [color setFill];
    [NSBezierPath fillRect:NSMakeRect(0, 0, 30, 10)];
    [image unlockFocus];
    self.image = image;
}

- (NSUInteger)itemColor {
    return _itemColor.colorValue;
}
@end
