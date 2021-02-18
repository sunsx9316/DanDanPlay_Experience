//
//  NSColor+DDPTools.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/18.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (DDPTools)
@property (assign, nonatomic, readonly) NSInteger colorValue;
+ (NSColor *)colorWithRGB:(uint32_t)rgbValue alpha:(CGFloat)alpha;
+ (NSColor *)colorWithRGB:(uint32_t)rgbValue;
+ (NSColor *)colorWithRGBA:(uint32_t)rgbaValue;
- (uint32_t)rgbaValue;
@end

NS_ASSUME_NONNULL_END
