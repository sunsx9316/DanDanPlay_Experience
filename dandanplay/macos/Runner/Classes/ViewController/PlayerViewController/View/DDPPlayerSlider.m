//
//  DDPPlayerSlider.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/29.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPPlayerSlider.h"
#import "DDPHUD.h"
#import <Masonry/Masonry.h>

@interface DDPPlayerSlider ()
@property (strong, nonatomic) NSTrackingArea *trackingArea;
@property (weak, nonatomic) DDPHUD *hud;
@property (strong, nonatomic) NSView *slider;
@end

@implementation DDPPlayerSlider

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupInit];
}

- (void)dealloc {
    [self removeTrackingArea:self.trackingArea];
}

- (void)mouseExited:(NSEvent *)event {
    DDPHUD *hud = self.hud;
    if (hud != nil) {
        [hud dismiss];
    }
}

- (void)mouseMoved:(NSEvent *)event {
    id<DDPPlayerSliderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(playerSliderViewShouldShowTips)] && ![delegate playerSliderViewShouldShowTips]) {
        return;
    }
    
    if ([delegate respondsToSelector:@selector(playerSliderView:didShowTipsAtProgress:)]) {
        float progress = [self progressWithEvent:event];
        
        NSString *str = [delegate playerSliderView:self didShowTipsAtProgress:progress];
        DDPHUD *hud = self.hud;
        if (hud == nil) {
            hud = [[DDPHUD alloc] initWithStyle:DDPHUDStyleCompact];
            hud.autoHidden = NO;
            self.hud = hud;
        }
        
        hud.title = str;
        NSView *superview = self.superview;
        [hud showAtView:superview position:DDPHUDPositionCustom];
        
        CGRect frame = CGRectZero;
        frame.size = hud.fittingSize;
        frame.origin.y = frame.size.height * 3 - 2;
        frame.origin.x = event.locationInWindow.x - (frame.size.width / 2);
        
        if (CGRectGetMinX(frame) < 5) {
            frame.origin.x = 5;
        }
        
        CGFloat superviewWidth = CGRectGetWidth(self.superview.frame);
        if (CGRectGetMaxX(frame) > superviewWidth - 5) {
            frame.origin.x = superviewWidth - CGRectGetWidth(frame) - 5;
        }
        
        hud.frame = frame;
    }
}

- (void)setCurrentProgress:(float)currentProgress {
    if (isnan(currentProgress)) currentProgress = 0;
    _currentProgress = currentProgress;
    [self layoutSubView];
}

- (void)mouseDragged:(NSEvent *)event {
    _tracking = YES;
    
    float value = [self progressWithEvent:event];
    self.currentProgress = value;
    id<DDPPlayerSliderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(playerSliderView:didDragProgress:)]) {
        [delegate playerSliderView:self didDragProgress:value];
    }
    
    [self mouseMoved:event];
}

- (void)mouseDown:(NSEvent *)event {
    [self mouseDragged:event];
}

- (void)mouseUp:(NSEvent *)event {
    _tracking = NO;
    float value = [self progressWithEvent:event];
    self.currentProgress = value;
    id<DDPPlayerSliderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(playerSliderView:didClickProgress:)]) {
        [delegate playerSliderView:self didClickProgress:value];
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    [self layoutSubView];
}

- (BOOL)mouseDownCanMoveWindow {
    return NO;
}

#pragma mark - 私有方法
- (void)layoutSubView {
    CGFloat width = CGRectGetWidth(self.frame);
    CGFloat height = 5;
    self.slider.frame = CGRectMake(0, (CGRectGetHeight(self.bounds) - height) / 2, width * _currentProgress, height);
}

- (void)setupInit {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.3].CGColor;
    [self addTrackingArea:self.trackingArea];
    
    [self addSubview:self.slider];
}

- (float)progressWithEvent:(NSEvent *)event {
    CGPoint point = event.locationInWindow;
    CGPoint pointInView = [self convertPoint:point fromView:nil];
    
    CGFloat progress = pointInView.x / CGRectGetWidth(self.frame);
    if (isnan(progress) || progress < 0) {
        progress = 0;
    }
    
    return progress;
}

#pragma mark - 懒加载
- (NSTrackingArea *)trackingArea {
    if(_trackingArea == nil) {
        _trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:NSTrackingActiveInKeyWindow | NSTrackingMouseMoved | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited owner:self userInfo:nil];
    }
    return _trackingArea;
}

- (NSView *)slider {
    if (_slider == nil) {
        _slider = [[NSView alloc] init];
        _slider.wantsLayer = YES;
        _slider.layer.backgroundColor = NSColor.systemBlueColor.CGColor;
    }
    return _slider;
}

@end
