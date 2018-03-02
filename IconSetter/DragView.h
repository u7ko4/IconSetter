//
//  DragView.h
//  IconSetter
//
//  Created by Keith Ellis on 16/5/21.
//  Copyright © 2016年 Keith Ellis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol DragViewDelegate <NSObject>

- (void)findFiles:(NSArray*)files;

- (void)findFolders:(NSArray *)folders;

@end

@interface DragView : NSView

@property (nonatomic, weak) IBOutlet id<DragViewDelegate> delegate;

@end
