//
//  NSControl+DDPTools.h
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/7/29.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSControl (DDPTools)

- (void)addTarget:(id)target action:(SEL)action;

@end

NS_ASSUME_NONNULL_END
