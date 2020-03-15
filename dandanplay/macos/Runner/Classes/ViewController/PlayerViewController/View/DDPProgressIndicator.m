//
//  DDPProgressIndicator.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/21.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPProgressIndicator.h"

@interface DDPProgressIndicator ()
@property (strong, nonatomic) NSView *progressView;
@end

@implementation DDPProgressIndicator

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.progressView.wantsLayer = YES;
        [self addSubview:self.progressView];
        self.progressColor = NSColor.systemBlueColor;
        self.bgColor = NSColor.controlBackgroundColor;
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    [self layoutSubViews];
}

- (void)setProgress:(CGFloat)progress {
    if (isnan(progress) || progress < 0) {
        progress = 0;
    }
    
    _progress = progress;
    [self layoutSubViews];
}

- (void)setBgColor:(NSColor *)bgColor {
    _bgColor = bgColor;
    self.layer.backgroundColor = _bgColor.CGColor;
}

- (void)setProgressColor:(NSColor *)progressColor {
    _progressColor = progressColor;
    self.progressView.layer.backgroundColor = _progressColor.CGColor;
}

- (void)layoutSubViews {
    CGRect frame = self.bounds;
    self.progressView.frame = CGRectMake(0, 0, CGRectGetWidth(frame) * _progress, CGRectGetHeight(frame));
}

- (BOOL)isFlipped {
    return YES;
}

#pragma mark - 懒加载
- (NSView *)progressView {
    if (_progressView == nil) {
        _progressView = [[NSView alloc] init];
    }
    return _progressView;
}
@end
