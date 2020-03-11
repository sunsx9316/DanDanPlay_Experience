//
//  NSColor+DDPTools.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/18.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "NSColor+DDPTools.h"

@implementation NSColor (DDPTools)

- (NSInteger)colorValue {
    return self.redComponent * 256 * 256 * 255 + self.greenComponent * 256 * 255 + self.blueComponent * 255;
}

+ (NSColor *)colorWithRGB:(uint32_t)rgbValue alpha:(CGFloat)alpha {
    return [NSColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0f
                           green:((rgbValue & 0xFF00) >> 8) / 255.0f
                            blue:(rgbValue & 0xFF) / 255.0f
                           alpha:alpha];
}

+ (NSColor *)colorWithRGB:(uint32_t)rgbValue {
    return [NSColor colorWithRGB:rgbValue alpha: 1];
}

@end
