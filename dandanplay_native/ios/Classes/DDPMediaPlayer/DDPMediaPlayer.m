//
//  DDPMediaPlayer.m
//  test
//
//  Created by JimHuang on 16/3/4.
//  Copyright © 2016年 JimHuang. All rights reserved.
//

#import "DDPMediaPlayer.h"
#import <MobileVLCKit/MobileVLCKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <YYCategories/YYCategories.h>
//#import "NSString+Tools.h"

//最大音量
#define MAX_VOLUME 200.0

static char mediaParsingCompletionKey = '0';

@interface DDPMediaPlayer()<VLCMediaPlayerDelegate, VLCMediaDelegate>
@property (strong, nonatomic) VLCMediaPlayer *localMediaPlayer;
@property (copy, nonatomic) SnapshotCompleteBlock snapshotCompleteBlock;
@end

@implementation DDPMediaPlayer
{
    NSTimeInterval _length;
    NSTimeInterval _currentTime;
    DDPMediaPlayerStatus _status;
}

- (instancetype)initWithMedia:(id<DDPMediaItemProtocol>)media {
    if (self = [self init]) {
        [self setMedia:media];
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterreption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (void)dealloc {
    [_mediaView removeFromSuperview];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
//    free(_localMediaPlayer.videoAspectRatio);
//    _localMediaPlayer.drawable = nil;
//    _localMediaPlayer = nil;
//    _mediaView = nil;
}

- (void)parseWithCompletion:(void(^)(void))completion {
    objc_setAssociatedObject(self.localMediaPlayer.media, &mediaParsingCompletionKey, completion, OBJC_ASSOCIATION_COPY_NONATOMIC);
    VLCMedia *media = self.localMediaPlayer.media;
    int result = [media parseWithOptions:VLCMediaParseLocal | VLCMediaParseNetwork];
    
    if (result != 0) {
        NSLog(@"%@ 解析失败", media.url);
    }
}


#pragma mark 属性
- (DDPMediaType)mediaType {
    return [self.media.url isFileURL] ? DDPMediaTypeLocaleMedia : DDPMediaTypeNetMedia;
}

- (NSTimeInterval)length {
    if (_length > 0) return _length;
    
    _length = _localMediaPlayer.media.length.value.floatValue / 1000.0f;
    return _length;
}

- (NSTimeInterval)currentTime {
    return _localMediaPlayer.time.value.floatValue / 1000.0f;
}

- (DDPMediaPlayerStatus)status {
    switch (_localMediaPlayer.state) {
        case VLCMediaPlayerStateStopped:
            if (self.localMediaPlayer.position >= 0.999) {
                _status = DDPMediaPlayerStatusNextEpisode;
            }
            else {
                _status = DDPMediaPlayerStatusStop;
            }
            break;
        case VLCMediaPlayerStatePaused:
            _status = DDPMediaPlayerStatusPause;
            break;
        case VLCMediaPlayerStatePlaying:
            _status = DDPMediaPlayerStatusPlaying;
            break;
        case VLCMediaPlayerStateBuffering:
            if (self.localMediaPlayer.isPlaying) {
                _status = DDPMediaPlayerStatusPlaying;
            }
            else {
                _status = DDPMediaPlayerStatusPause;
            }
            break;
        default:
            _status = DDPMediaPlayerStatusPause;
            break;
    }
    return _status;
}

#pragma mark 音量
- (void)volumeJump:(CGFloat)value {
    [self setVolume: self.volume + value];
}

- (CGFloat)volume {
    return _localMediaPlayer.audio.volume;
}

- (void)setVolume:(CGFloat)volume {
    if (volume < 0) volume = 0;
    if (volume > MAX_VOLUME) volume = MAX_VOLUME;
    
    _localMediaPlayer.audio.volume = volume;
}

#pragma mark 播放位置
- (void)jump:(int)value completionHandler:(void(^)(NSTimeInterval time))completionHandler {
    [self setPosition:([self currentTime] + value) / [self length] completionHandler:completionHandler];
}

- (void)setCurrentTime:(int)time completionHandler:(void(^)(NSTimeInterval time))completionHandler {
    [self setPosition:time / [self length] completionHandler:completionHandler];
}

- (void)setPosition:(CGFloat)position completionHandler:(void(^)(NSTimeInterval time))completionHandler {
    if (position < 0) position = 0;
    if (position > 1) position = 1;
    
    _localMediaPlayer.position = position;
    NSTimeInterval jumpTime = [self length] * position;
    
    if (completionHandler) completionHandler(jumpTime);
    if ([self.delegate respondsToSelector:@selector(mediaPlayer:userJumpWithTime:)]) {
        [self.delegate mediaPlayer:self userJumpWithTime:jumpTime];
    }
}

- (CGFloat)position {
    return _localMediaPlayer.position;
}

#pragma mark 字幕
- (void)setSubtitleDelay:(NSInteger)subtitleDelay {
    _localMediaPlayer.currentVideoSubTitleDelay = subtitleDelay;
}

- (NSInteger)subtitleDelay {
    return _localMediaPlayer.currentVideoSubTitleDelay;
}

- (NSArray *)subtitleIndexs {
    return _localMediaPlayer.videoSubTitlesIndexes;
}

- (NSArray *)subtitleTitles {
    return _localMediaPlayer.videoSubTitlesNames;
}

- (void)setCurrentSubtitleIndex:(int)currentSubtitleIndex {
    _localMediaPlayer.currentVideoSubTitleIndex = currentSubtitleIndex;
}

- (int)currentSubtitleIndex {
    return _localMediaPlayer.currentVideoSubTitleIndex;
}


- (NSArray<NSNumber *> *)audioChannelIndexs {
    return _localMediaPlayer.audioTrackIndexes;
}

- (NSArray<NSString *> *)audioChannelTitles {
    return _localMediaPlayer.audioTrackNames;
}

- (void)setCurrentAudioChannelIndex:(int)currentAudioChannelIndex {
    _localMediaPlayer.currentAudioTrackIndex = currentAudioChannelIndex;
}

- (int)currentAudioChannelIndex {
    return _localMediaPlayer.currentAudioTrackIndex;
}


- (void)setSpeed:(float)speed {
    _localMediaPlayer.rate = speed;
    if ([self.delegate respondsToSelector:@selector(mediaPlayer:rateChange:)]) {
        [self.delegate mediaPlayer:self rateChange:_localMediaPlayer.rate];
    }
}

- (float)speed {
    return _localMediaPlayer.rate;
}

- (void)setVideoAspectRatio:(CGSize)videoAspectRatio {
    if (CGSizeEqualToSize(videoAspectRatio, CGSizeZero)) {
        self.localMediaPlayer.videoAspectRatio = nil;
    }
    else {
        self.localMediaPlayer.videoAspectRatio = (char *)[NSString stringWithFormat:@"%ld:%ld", (long)videoAspectRatio.width, (long)videoAspectRatio.height].UTF8String;
    }
}

#pragma mark 播放器控制
- (BOOL)isPlaying {
    return [_localMediaPlayer isPlaying];
}

- (void)play {
    [_localMediaPlayer play];
}

- (void)pause {
    [_localMediaPlayer pause];
}

- (void)stop {
    [_localMediaPlayer stop];
}


#pragma mark 功能
- (void)saveVideoSnapshotwithSize:(CGSize)size completionHandler:(SnapshotCompleteBlock)completion {
    //vlc截图方式
    NSError *error = nil;
    NSString *directoryPath = [NSString stringWithFormat:@"%@/VLC_snapshot", NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject];
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    //创建文件错误
    if (error) {
        if (completion) {
            completion(nil, error);
        }
        return;
    }
    
    self.snapshotCompleteBlock = completion;
    
    NSString *aPath = [directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu", (unsigned long)[NSDate date].hash]];
    if ([self.media.url.absoluteString containsString:@"smb"]) {
        UIView *aView = self.localMediaPlayer.drawable;
        UIImage *tempImage = [aView snapshotImageAfterScreenUpdates:YES];
        [self saveImage:tempImage];
    }
    else {
        [self.localMediaPlayer saveVideoSnapshotAt:aPath withWidth:size.width andHeight:size.height];
    }
}

- (BOOL)openVideoSubTitlesFromFile:(NSURL *)path {
    //    if (self.mediaType == DDPMediaTypeLocaleMedia) {
    return !![_localMediaPlayer addPlaybackSlave:path type:VLCMediaPlaybackSlaveTypeSubtitle enforce:YES];
    //    }
    
    //    return [_localMediaPlayer openVideoSubTitlesFromFile:a];
}

- (void)setMedia:(id<DDPMediaItemProtocol>)media {
    if (!media) return;
    
    _media = media;
    VLCMedia *vlcMedia = [[VLCMedia alloc] initWithURL:_media.url];
    vlcMedia.delegate = self;
    if (media.mediaOptions) {
        [vlcMedia addOptions:media.mediaOptions];
    }
    self.localMediaPlayer.media = vlcMedia;
    
    NSLog(@"设置播放路径：%@", _media.url);
    
    _length = -1;
}

#pragma mark - VLCMediaPlayerDelegate
- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification {
    if ([self.delegate respondsToSelector:@selector(mediaPlayer:progress:)]) {
        NSTimeInterval nowTime = [self currentTime];
        NSTimeInterval videoTime = [self length];
        
        if (videoTime > 0) {
            CGFloat progress = videoTime == 0 ? 0.0 : nowTime / videoTime;
            [self.delegate mediaPlayer:self progress:progress];
        }
    }
}

- (void)mediaPlayerSnapshot:(NSNotification *)aNotification {
    UIImage *tempImage = self.localMediaPlayer.lastSnapshot;
    [self saveImage:tempImage];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification {
    NSLog(@"播放器状态 %@", VLCMediaPlayerStateToString(self.localMediaPlayer.state));
    
    if ([self.delegate respondsToSelector:@selector(mediaPlayer:statusChange:)]) {
        DDPMediaPlayerStatus status = [self status];
        [self.delegate mediaPlayer:self statusChange:status];
    }
}

- (void)mediaDidFinishParsing:(VLCMedia *)aMedia {
    void(^action)(void) = objc_getAssociatedObject(aMedia, &mediaParsingCompletionKey);
    if (action) {
        action();
    }
    
    objc_setAssociatedObject(aMedia, &mediaParsingCompletionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 私有方法
- (void)saveImage:(UIImage *)image {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        //写入图片到相册
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (self.snapshotCompleteBlock) {
                    self.snapshotCompleteBlock(image, nil);
                    self.snapshotCompleteBlock = nil;
                }
            }
            else {
                if (self.snapshotCompleteBlock) {
                    self.snapshotCompleteBlock(nil, error);
                    self.snapshotCompleteBlock = nil;
                }
            }
        });
    }];
}

//电话事件
- (void)handleInterreption:(NSNotification *)aNotification {
    BOOL interruption = [aNotification.userInfo[AVAudioSessionInterruptionTypeKey] boolValue];
    //中断
    if (interruption) {
        if (self.isPlaying) {
            [self pause];
        }
    }
    //恢复
    else {
//        if (self.isPlaying == NO) {
//            [self play];
//        }
    }
}

#pragma mark 播放结束
- (void)playEnd:(NSNotification *)sender {
    if (self.mediaType == DDPMediaTypeNetMedia) {
        _status = DDPMediaPlayerStatusStop;
        if ([self.delegate respondsToSelector:@selector(mediaPlayer:statusChange:)]) {
            [self.delegate mediaPlayer:self statusChange:DDPMediaPlayerStatusStop];
        }
    }
}

#pragma mark - 懒加载
- (VLCMediaPlayer *)localMediaPlayer {
    if(_localMediaPlayer == nil) {
        _localMediaPlayer = [[VLCMediaPlayer alloc] init];
        _localMediaPlayer.drawable = self.mediaView;
        _localMediaPlayer.delegate = self;
    }
    return _localMediaPlayer;
}

- (UIView *)mediaView {
    if (_mediaView == nil) {
        _mediaView = [[UIView alloc] init];
    }
    return _mediaView;
}

@end
