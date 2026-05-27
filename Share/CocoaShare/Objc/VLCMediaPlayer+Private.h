//
//  VLCPlayer+Private.h
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/27.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_OSX || (TARGET_OS_IOS && !TARGET_OS_TV)

#if TARGET_OS_IOS
#import <MobileVLCKit/MobileVLCKit.h>
#else
#import <VLCKit/VLCKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VLCMediaPlayer (Private)

- (void)anx_setTextRendererFontSize:(NSNumber *)fontSize;

- (void)anx_setTextRendererFont:(NSString *)fontname;

- (void)anx_setTextRendererFontColor:(NSNumber *)fontColor;

@end

NS_ASSUME_NONNULL_END

#endif
