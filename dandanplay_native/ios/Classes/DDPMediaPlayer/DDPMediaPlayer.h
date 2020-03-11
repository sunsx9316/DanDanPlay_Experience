//
//  DDPMediaPlayer.h
//  test
//
//  Created by JimHuang on 16/3/4.
//  Copyright © 2016年 JimHuang. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "DDPMediaItemProtocal.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, DDPMediaPlayerStatus) {
    DDPMediaPlayerStatusPlaying,
    DDPMediaPlayerStatusPause,
    DDPMediaPlayerStatusStop,
    DDPMediaPlayerStatusNextEpisode,
//    DDPMediaPlayerStatusBuffering
};

typedef NS_ENUM(NSUInteger, DDPMediaType) {
    DDPMediaTypeLocaleMedia,
    DDPMediaTypeNetMedia,
};

typedef NS_ENUM(NSUInteger, DDPSnapshotType) {
    DDPSnapshotTypeJPG,
    DDPSnapshotTypePNG,
    DDPSnapshotTypeBMP,
    DDPSnapshotTypeTIFF
};


typedef void(^SnapshotCompleteBlock)(UIImage * _Nullable image, NSError * _Nullable error);

@class DDPMediaPlayer;
@protocol DDPMediaPlayerDelegate <NSObject>
@optional
/**
 *  监听时间变化
 *
 *  @param player    Player
 *  @param progress  当前进度
 */
- (void)mediaPlayer:(DDPMediaPlayer *)player progress:(float)progress;

- (void)mediaPlayer:(DDPMediaPlayer *)player statusChange:(DDPMediaPlayerStatus)status;

- (void)mediaPlayer:(DDPMediaPlayer *)player rateChange:(float)rate;

- (void)mediaPlayer:(DDPMediaPlayer *)player userJumpWithTime:(NSTimeInterval)time;
@end

@interface DDPMediaPlayer : NSObject
@property (strong, nonatomic) UIView *mediaView;
@property (strong, nonatomic) id<DDPMediaItemProtocol> _Nullable media;
@property (assign, nonatomic) CGFloat volume;
@property (assign, nonatomic) NSInteger subtitleDelay;

/**
 字幕索引
 */
@property (strong, nonatomic, readonly) NSArray <NSNumber *>*subtitleIndexs;

/**
 字幕名称
 */
@property (strong, nonatomic, readonly) NSArray <NSString *>*subtitleTitles;

/**
 当前字幕索引
 */
@property (assign, nonatomic) int currentSubtitleIndex;


/**
 音频索引
 */
@property (strong, nonatomic, readonly) NSArray <NSNumber *>*audioChannelIndexs;

/**
 音频名称
 */
@property (strong, nonatomic, readonly) NSArray <NSString *>*audioChannelTitles;

/**
 当前音频索引
 */
@property (assign, nonatomic) int currentAudioChannelIndex;




@property (assign, nonatomic) float speed;

/**
 宽高比
 */
@property (assign, nonatomic) CGSize videoAspectRatio;

/**
 *  位置 0 ~ 1
 */
@property (nonatomic, assign, readonly) CGFloat position;

@property (nonatomic, assign, readonly) DDPMediaPlayerStatus status;

@property (nonatomic, assign, readonly) NSTimeInterval length;

@property (nonatomic, assign, readonly) NSTimeInterval currentTime;

@property (nonatomic, assign, readonly) DDPMediaType mediaType;

@property (nonatomic, assign, readonly) BOOL isPlaying;

@property (weak, nonatomic) id <DDPMediaPlayerDelegate> _Nullable delegate;

/**
 *  设置媒体位置
 *
 *  @param position          位置 0 ~ 1
 *  @param completionHandler 完成之后的回调
 */
- (void)setPosition:(CGFloat)position completionHandler:(void(^ _Nullable)(NSTimeInterval time))completionHandler;
/**
 *  协议返回的时间格式 默认"mm:ss"
 */

/**
 *  基于当前时间跳转
 *
 *  @param value 增加的值
 */
- (void)jump:(int)value completionHandler:(void(^ _Nullable)(NSTimeInterval time))completionHandler;

/**
 设置播放时间

 @param time 播放时间
 @param completionHandler 完成回调
 */
- (void)setCurrentTime:(int)time completionHandler:(void(^ _Nullable)(NSTimeInterval time))completionHandler;

/**
 *  音量增加
 *
 *  @param value 增加的值
 */
- (void)volumeJump:(CGFloat)value;
- (void)play;
- (void)pause;
- (void)stop;
/**
 *  保存截图
 *
 *  @param size  宽 如果为 CGSizeZero则为原视频的宽高
 *  @param completion 完成回调
 */
- (void)saveVideoSnapshotwithSize:(CGSize)size completionHandler:(SnapshotCompleteBlock _Nullable)completion;
/**
 *  加载字幕文件
 *
 *  @param path 字幕路径
 *
 *  @return 是否成功 0失败 1成功
 */
- (BOOL)openVideoSubTitlesFromFile:(NSURL *)path;
/**
 *  初始化
 *
 *  @param media 媒体路径 可以为本地视频或者网络视频
 *
 *  @return self
 */
- (instancetype)initWithMedia:(id<DDPMediaItemProtocol>)media;


/**
 解析
 */
- (void)parseWithCompletion:(void(^ _Nullable)(void))completion;

@end
NS_ASSUME_NONNULL_END
