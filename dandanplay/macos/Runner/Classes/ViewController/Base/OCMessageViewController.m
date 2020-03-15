//
//  OCMessageViewController.m
//  Runner
//
//  Created by JimHuang on 2020/3/9.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

#import "OCMessageViewController.h"
#import <DDPCategory/DDPCategory.h>

@interface OCMessageViewController ()

@end

@implementation OCMessageViewController

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleInstanceMethod:NSSelectorFromString(@"launchEngine") with:@selector(ddp_launchEngine)];
    });
}

- (void)dealloc {
    [self.engine shutDownEngine];
}

- (void)engineDidLaunch {
    
}

- (BOOL)ddp_launchEngine {
    BOOL flag = [self ddp_launchEngine];
    [self engineDidLaunch];
    return flag;
}

@end
