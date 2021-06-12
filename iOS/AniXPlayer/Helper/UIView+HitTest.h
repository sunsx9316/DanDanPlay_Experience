//
//  UIView+HitTest.h
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/12.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (HitTest)

@property (assign, nonatomic) UIEdgeInsets hitTestSlop;

@end

NS_ASSUME_NONNULL_END
