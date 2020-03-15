//
//  DDPPlayTopBar.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/13.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPPlayTopBar.h"

@implementation DDPPlayTopBar

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:0.8].CGColor;
    
    self.titleLabel.stringValue = @"";
    self.titleLabel.maximumNumberOfLines = 2;
}

@end
