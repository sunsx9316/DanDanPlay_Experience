//
//  VLCMediaPlayer+Private.m
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/27.
//

#import "VLCMediaPlayer+Private.h"

@implementation VLCMediaPlayer (Private)

- (void)anx_setTextRendererFontSize:(NSNumber *)fontSize {
    SEL selector = NSSelectorFromString(@"setTextRendererFontSize:");
    if ([self respondsToSelector:selector]) {
        void (*setter)(id, SEL, NSNumber*) = (void (*)(id, SEL, NSNumber *))[self methodForSelector:selector];
        setter(self, selector, fontSize);
    }
}

- (void)anx_setTextRendererFont:(NSString *)fontname {
    SEL selector = NSSelectorFromString(@"setTextRendererFont:");
    if ([self respondsToSelector:selector]) {
        void (*setter)(id, SEL, NSString*) = (void (*)(id, SEL, NSString *))[self methodForSelector:selector];
        setter(self, selector, fontname);
    }
}

- (void)anx_setTextRendererFontColor:(NSNumber *)fontColor {
    SEL selector = NSSelectorFromString(@"setTextRendererFontColor:");
    if ([self respondsToSelector:selector]) {
        void (*setter)(id, SEL, NSNumber*) = (void (*)(id, SEL, NSNumber *))[self methodForSelector:selector];
        setter(self, selector, fontColor);
    }
}

@end
