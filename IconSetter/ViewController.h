//
//  ViewController.h
//  IconSetter
//
//  Created by Keith Ellis on 16/5/21.
//  Copyright © 2016年 Keith Ellis. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DragView.h"

@interface ViewController : NSViewController <DragViewDelegate>

@property (weak) IBOutlet DragView *dragView;

@end

