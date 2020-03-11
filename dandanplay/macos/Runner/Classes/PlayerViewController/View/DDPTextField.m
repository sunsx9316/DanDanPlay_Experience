//
//  DDPTextField.m
//  DDPlayMacPlayer
//
//  Created by JimHuang on 2019/9/13.
//  Copyright © 2019 JimHuang. All rights reserved.
//

#import "DDPTextField.h"

@implementation DDPTextField

- (void)keyUp:(NSEvent *)theEvent{
    if (self.keyUpCallBack) {
        self.keyUpCallBack(theEvent);
    }
}

@end
