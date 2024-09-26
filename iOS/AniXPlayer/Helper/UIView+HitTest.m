//
//  UIView+HitTest.m
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/12.
//

#import "UIView+HitTest.h"
#import <objc/runtime.h>
#import <YYCategories.h>

@implementation UIView (HitTest)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleInstanceMethod:@selector(ddp_pointInside:withEvent:) with:@selector(pointInside:withEvent:)];
    });
}

- (void)setHitTestSlop:(UIEdgeInsets)hitTestSlop {
    objc_setAssociatedObject(self, @selector(hitTestSlop), [NSValue valueWithUIEdgeInsets:hitTestSlop], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)hitTestSlop {
    NSValue *value = objc_getAssociatedObject(self, _cmd);
    return [value UIEdgeInsetsValue];
}

- (BOOL)ddp_pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIEdgeInsets slop = self.hitTestSlop;
    if (UIEdgeInsetsEqualToEdgeInsets(slop, UIEdgeInsetsZero)) {
        return [self ddp_pointInside:point withEvent:event];
    }
    else {
        return CGRectContainsPoint(UIEdgeInsetsInsetRect(self.bounds, slop), point);
    }
}

@end
