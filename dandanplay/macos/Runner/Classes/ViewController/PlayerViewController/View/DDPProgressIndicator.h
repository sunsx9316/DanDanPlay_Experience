//
//  DDPProgressIndicator.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/21.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDPProgressIndicator : NSView
@property (assign, nonatomic) CGFloat progress;
@property (strong, nonatomic) NSColor *bgColor;
@property (strong, nonatomic) NSColor *progressColor;
@end

NS_ASSUME_NONNULL_END
