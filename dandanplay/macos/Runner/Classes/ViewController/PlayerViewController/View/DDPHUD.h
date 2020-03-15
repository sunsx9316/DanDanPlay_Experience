//
//  DDPHUD.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/13.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DDPHUDPosition) {
    DDPHUDPositionTopRight,
    DDPHUDPositionCenter,
    DDPHUDPositionCustom,
};

typedef NS_ENUM(NSUInteger, DDPHUDStyle) {
    DDPHUDStyleNormal,
    DDPHUDStyleCompact,
};

@interface DDPHUD : NSView
@property (copy, nonatomic) NSString *title;
@property (assign, nonatomic) BOOL autoHidden;

- (instancetype)initWithStyle:(DDPHUDStyle)style;

- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)showAtView:(NSView *)view;

- (void)showAtView:(NSView *)view
          position:(DDPHUDPosition)position;

- (void)dismiss;
@end

NS_ASSUME_NONNULL_END
