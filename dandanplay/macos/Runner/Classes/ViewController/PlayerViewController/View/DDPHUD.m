//
//  DDPHUD.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/13.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPHUD.h"
#import <Masonry/Masonry.h>
#import <DDPCategory/DDPCategory.h>
#import "NSView+DDPTools.h"
#import "DDPCategoriesMacro.h"

@interface DDPHUD ()
@property (weak) IBOutlet NSTextField *label;
@property (strong, nonatomic) NSTimer *timer;
@property (assign, nonatomic) BOOL showing;

@property (weak) IBOutlet NSLayoutConstraint *topConstraint;
@property (weak) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (weak) IBOutlet NSLayoutConstraint *leftConstraint;
@property (weak) IBOutlet NSLayoutConstraint *rightConstraint;

@end

@implementation DDPHUD

- (instancetype)initWithStyle:(DDPHUDStyle)style {
    self = [DDPHUD loadFromNib];
    if (self) {
        [self setupInit];
        
        switch (style) {
            case DDPHUDStyleNormal: {
                self.topConstraint.constant = 12;
                self.bottomConstraint.constant = 12;
                self.leftConstraint.constant = 20;
                self.rightConstraint.constant = 20;
            }
                break;
            case DDPHUDStyleCompact:
                self.topConstraint.constant = 5;
                self.bottomConstraint.constant = 5;
                self.leftConstraint.constant = 5;
                self.rightConstraint.constant = 5;
                break;
            default:
                break;
        }
        
        _autoHidden = YES;
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    _title = title;
    self.label.stringValue = title;
}

- (void)showAtView:(NSView *)view {
    [self showAtView:view position:DDPHUDPositionTopRight];
}

- (void)showAtView:(NSView *)view position:(DDPHUDPosition)position {
    if (_autoHidden) {
        [self startTimer];
    }
    
    if (_showing == NO) {
        self.alphaValue = 0;
        [view addSubview:self];
        
        switch (position) {
            case DDPHUDPositionTopRight: {
                [self mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.trailing.mas_equalTo(-10);
                    make.top.mas_equalTo(10);
                }];
            }
                break;
            case DDPHUDPositionCenter: {
                [self mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.center.mas_equalTo(view);
                }];
            }
                break;
            default:
                break;
        }
        
        _showing = YES;
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            context.duration = 0.2;
            self.animator.alphaValue = 1;
        } completionHandler:^{
            
        }];
    }
    
}

- (void)dismiss {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.2;
        self.animator.alphaValue = 0;
    } completionHandler:^{
        [self removeFromSuperview];
        self.showing = NO;
    }];
}

#pragma mark - Private
- (void)setupInit {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 8;
    self.layer.allowsGroupOpacity = YES;
    
    [self addSubview:self.label];
}

#pragma mark - 懒加载
- (void)startTimer {
    @weakify(self)
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2 block:^(NSTimer * _Nonnull timer) {
        @strongify(self)
        if (!self) {
            return;
        }
        
        [self dismiss];
    } repeats:NO];
}

@end
