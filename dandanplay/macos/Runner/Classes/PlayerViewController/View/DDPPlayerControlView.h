//
//  DDPPlayerControlView.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/27.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DDPPlayerSlider.h"
#import "DDPTextField.h"
#import "DDPPlayerConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDPPlayerControlView : NSView
@property (unsafe_unretained) IBOutlet NSButton *playButton;
@property (unsafe_unretained) IBOutlet DDPPlayerSlider *progressSlider;
@property (unsafe_unretained) IBOutlet DDPTextField *inputTextField;
@property (unsafe_unretained) IBOutlet NSTextField *timeLabel;
@property (unsafe_unretained) IBOutlet NSButton *danmakuButton;
@property (weak) IBOutlet NSButton *playerListButton;


@property (assign, nonatomic, readonly) uint32_t sendanmakuColor;
@property (assign, nonatomic, readonly) DDPDanmakuMode sendanmakuStyle;

@property (weak) IBOutlet NSPopUpButton *danmakuColorPopUpButton;
@property (weak) IBOutlet NSPopUpButton *danmakuStylePopUpButton;

@property (assign, nonatomic) float topProgressAlpha;

@property (copy, nonatomic) void(^sliderDidChangeCallBack)(CGFloat progress);
@property (copy, nonatomic) void(^playButtonDidClickCallBack)(BOOL selected);
@property (copy, nonatomic) void(^danmakuButtonDidClickCallBack)(BOOL selected);
@property (copy, nonatomic) void(^onClickPlayListButtonCallBack)(void);
@property (copy, nonatomic) void(^onClickPlayNextButtonCallBack)(void);
@property (copy, nonatomic) void(^sendDanmakuCallBack)(NSString *danmaku);

- (void)updateCurrentTime:(NSTimeInterval)currentTime totalTime:(NSTimeInterval)totalTime;
@end

NS_ASSUME_NONNULL_END
