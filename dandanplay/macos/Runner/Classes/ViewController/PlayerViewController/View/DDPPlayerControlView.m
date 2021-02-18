//
//  DDPPlayerControlView.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/27.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPPlayerControlView.h"
#import <Carbon/Carbon.h>
#import <DDPCategory/DDPCategory.h>
#import "DDPDanmakuColorMenuItem.h"
#import "DDPDanmakuModeMenuItem.h"
#import "NSColor+DDPTools.h"
#import "DDPProgressIndicator.h"
#import <Masonry/Masonry.h>
#import "NSControl+DDPTools.h"
#import "DDPMacroDefinition.h"

@interface DDPPlayerControlView ()<DDPPlayerSliderDelegate>
@property (strong, nonatomic) DDPProgressIndicator *topProgressIndicator;
@property (assign, nonatomic) NSTimeInterval currentTime;
@property (assign, nonatomic) NSTimeInterval totalTime;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@end

@implementation DDPPlayerControlView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.wantsLayer = YES;
    self.layer.masksToBounds = NO;
    self.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:0.8].CGColor;
    
    self.progressSlider.delegate = self;
    
    [self.playButton addTarget:self action:@selector(onPlayButtonDidClick:)];
    [self.danmakuButton addTarget:self action:@selector(onDanmakuButtonDidClick:)];
    
    @weakify(self)
    self.inputTextField.keyUpCallBack = ^(NSEvent * _Nonnull event) {
        @strongify(self)
        if (!self.sendDanmakuCallBack) {
            return;
        }
        
        if (event.keyCode == kVK_Return) {
            self.sendDanmakuCallBack(self.inputTextField.stringValue);
            self.inputTextField.stringValue = @"";
        }
    };
    
    //弹幕颜色、样式按钮
    NSString *path = [[NSBundle mainBundle] pathForResource:@"danmaku_color" ofType:@"plist"];
    NSArray *colorArr = [NSArray arrayWithContentsOfFile:path];
    for (NSDictionary *dic in colorArr) {
        DDPDanmakuColorMenuItem *item = [[DDPDanmakuColorMenuItem alloc] initWithTitle:dic[@"name"] color:[NSColor colorWithRGB:(uint32_t)[dic[@"value"] integerValue]]];
        [self.danmakuColorPopUpButton.menu addItem:item];
    }
    
    [self.danmakuStylePopUpButton.menu addItem:[[DDPDanmakuModeMenuItem alloc] initWithMode:DDPDanmakuModeNormal title:@"滚动弹幕"]];
    [self.danmakuStylePopUpButton.menu addItem:[[DDPDanmakuModeMenuItem alloc] initWithMode:DDPDanmakuModeTop title:@"顶部弹幕"]];
    [self.danmakuStylePopUpButton.menu addItem:[[DDPDanmakuModeMenuItem alloc] initWithMode:DDPDanmakuModeBottom title:@"底部弹幕"]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeDanmakuColor:) name:NSColorPanelColorDidChangeNotification object:nil];
    
    [self addSubview:self.topProgressIndicator];
    [self.topProgressIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.trailing.equalTo(self);
        make.bottom.equalTo(self.mas_top);
        make.height.mas_equalTo(2);
    }];
    
    [self.progressSlider addObserver:self forKeyPath:DDP_KEYPATH(self.progressSlider, currentProgress) options:NSKeyValueObservingOptionNew context:nil];
    self.topProgressAlpha = 0;
}

- (void)setTopProgressAlpha:(float)topProgressAlpha {
    _topProgressAlpha = topProgressAlpha;
    self.topProgressIndicator.alphaValue = _topProgressAlpha;
}

- (void)dealloc {
    [self.progressSlider removeObserver:self forKeyPath:DDP_KEYPATH(self.progressSlider, currentProgress)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:DDP_KEYPATH(self.progressSlider, currentProgress)]) {
        NSNumber *value = change[NSKeyValueChangeNewKey];
        self.topProgressIndicator.progress = value.doubleValue;
    }
}

- (void)updateCurrentTime:(NSTimeInterval)currentTime totalTime:(NSTimeInterval)totalTime {
    if (self.progressSlider.isTracking) {
        return;
    }
    
    //更新当前时间
    [self updateLabelWithCurrentTime:currentTime totalTime:totalTime];
    CGFloat progress = totalTime == 0 ? 0 : currentTime / totalTime;
    self.progressSlider.currentProgress = progress;
}

- (NSColor *)sendanmakuColor {
    let item = (DDPDanmakuColorMenuItem *)self.danmakuColorPopUpButton.selectedItem;
    if ([item isKindOfClass:[DDPDanmakuColorMenuItem class]]) {
        return item.itemColor;
    }
    
    let color = [NSColor colorWithRed:1 green:1 blue:1 alpha:1];
    return color;
}

- (DDPDanmakuMode)sendanmakuStyle {
    let item = (DDPDanmakuModeMenuItem *)self.danmakuStylePopUpButton.selectedItem;
    if ([item isKindOfClass:[DDPDanmakuModeMenuItem class]]) {
        return item.mode;
    }
    
    return DDPDanmakuModeNormal;
}

#pragma mark - DDPPlayerSliderDelegate
- (void)playerSliderView:(DDPPlayerSlider *)playerSliderView didClickProgress:(float)progress {
    if (self.sliderDidChangeCallBack) {
        self.sliderDidChangeCallBack(progress);
    }
}

- (void)playerSliderView:(DDPPlayerSlider *)playerSliderView didDragProgress:(float)progress {
    [self updateLabelWithCurrentTime:_totalTime * progress totalTime:_totalTime];
}

- (NSString *)playerSliderView:(DDPPlayerSlider *)sliderView didShowTipsAtProgress:(CGFloat)progress {
    let currentTime = self.totalTime * progress;
    let currentTimeStr = [self.timeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:currentTime]];
    let totalTimeStr = [self.timeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:self.totalTime]];
    return [NSString stringWithFormat:@"%@/%@", currentTimeStr, totalTimeStr];
}

- (BOOL)playerSliderViewShouldShowTips {
    return self.totalTime != 0;
}

#pragma mark - 私有方法
- (void)updateLabelWithCurrentTime:(NSTimeInterval)currentTime totalTime:(NSTimeInterval)totalTime {
    _currentTime = currentTime;
    _totalTime = totalTime;
    
    let currentTimeStr = [self.timeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_currentTime]];
    let totalTimeStr = [self.timeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_totalTime]];
    
    //更新当前时间
    self.timeLabel.stringValue = [NSString stringWithFormat:@"%@/%@", currentTimeStr, totalTimeStr];
}

- (void)onPlayButtonDidClick:(NSButton *)button {
    if (self.playButtonDidClickCallBack) {
        self.playButtonDidClickCallBack(button.state == NSControlStateValueOn);
    }
}

- (void)onDanmakuButtonDidClick:(NSButton *)button {
    if (self.danmakuButtonDidClickCallBack) {
        self.danmakuButtonDidClickCallBack(button.state == NSControlStateValueOn);
    }
}



- (IBAction)onClickColorButton:(NSPopUpButton *)sender {
    if ([sender.selectedItem.title isEqualToString:@"其它"]) {
        NSColorPanel *panel = [NSColorPanel sharedColorPanel];
        [panel setTarget:self];
        [panel orderFront:self];
    }
}

- (IBAction)onClickPlayListButton:(NSButton *)sender {
    if (self.onClickPlayListButtonCallBack) {
        self.onClickPlayListButtonCallBack();
    }
}

- (IBAction)onClickNextButton:(NSButton *)sender {
    if (self.onClickPlayNextButtonCallBack) {
        self.onClickPlayNextButtonCallBack();
    }
}

- (IBAction)onClickSettingButton:(NSButton *)sender {
    if (self.onClickSettingButtonCallBack) {
        self.onClickSettingButtonCallBack();
    }
}


- (void)changeDanmakuColor:(NSNotification *)sender {
    NSColorPanel *panel = sender.object;
    DDPDanmakuColorMenuItem *item = (DDPDanmakuColorMenuItem *)[self.danmakuColorPopUpButton itemWithTitle:@"其它"];
    [item setItemColor:panel.color];
}

#pragma mark - 懒加载
- (DDPProgressIndicator *)topProgressIndicator {
    if (_topProgressIndicator == nil) {
        _topProgressIndicator = [[DDPProgressIndicator alloc] initWithFrame:CGRectZero];
    }
    return _topProgressIndicator;
}

- (NSDateFormatter *)timeFormatter {
    if (_timeFormatter == nil) {
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateFormat = @"mm:ss";
    }
    return _timeFormatter;
}

@end
