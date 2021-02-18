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

- (uint32_t)rgbaValue {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [self getRed:&r green:&g blue:&b alpha:&a];
    int8_t red = r * 255;
    uint8_t green = g * 255;
    uint8_t blue = b * 255;
    uint8_t alpha = a * 255;
    return (red << 24) + (green << 16) + (blue << 8) + alpha;
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

+ (NSColor *)colorWithRGBA:(uint32_t)rgbaValue {
    return [NSColor colorWithRed:((rgbaValue & 0xFF000000) >> 24) / 255.0f
                           green:((rgbaValue & 0xFF0000) >> 16) / 255.0f
                            blue:((rgbaValue & 0xFF00) >> 8) / 255.0f
                           alpha:(rgbaValue & 0xFF) / 255.0f];
}

@end
