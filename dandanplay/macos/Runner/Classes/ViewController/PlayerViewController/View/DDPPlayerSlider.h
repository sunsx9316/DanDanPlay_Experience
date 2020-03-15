//
//  DDPPlayerSlider.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/29.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@class DDPPlayerSlider;

@protocol DDPPlayerSliderDelegate<NSObject>
@optional


/// 拖拽进度条
/// @param playerSliderView playerSliderView
/// @param progress 进度
- (void)playerSliderView:(DDPPlayerSlider *)playerSliderView didDragProgress:(float)progress;

/// 点击控制条事件
/// @param playerSliderView playerSliderView
/// @param progress 进度
- (void)playerSliderView:(DDPPlayerSlider *)playerSliderView didClickProgress:(float)progress;

/// 显示进度提示回调
/// @param sliderView sliderView
/// @param progress 进度
- (NSString *)playerSliderView:(DDPPlayerSlider *)sliderView didShowTipsAtProgress:(CGFloat)progress;

/// 是否应该显示tips
- (BOOL)playerSliderViewShouldShowTips;
@end

@interface DDPPlayerSlider : NSView
@property (weak, nonatomic) id<DDPPlayerSliderDelegate> delegate;
@property (assign, nonatomic) float currentProgress;
@property (assign, nonatomic, readonly, getter=isTracking) BOOL tracking;
@end

NS_ASSUME_NONNULL_END
