//
//  DragView.m
//  IconSetter
//
//  Created by Keith Ellis on 16/5/21.
//  Copyright © 2016年 Keith Ellis. All rights reserved.
//

#import "DragView.h"

@interface DragView ()

@property (nonatomic, strong) NSColor* strokeColor;

@end

@implementation DragView

- (id)initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.strokeColor = [NSColor colorWithDeviceRed:0.80 green:0.80 blue:0.80 alpha:1.00];
        [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    self.strokeColor = [NSColor colorWithDeviceRed:0.67 green:0.67 blue:0.67 alpha:1.00];
    [self setNeedsDisplay:YES];
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    self.strokeColor = [NSColor colorWithDeviceRed:0.80 green:0.80 blue:0.80 alpha:1.00];
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSArray* properties = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    NSString* path = [properties objectAtIndex:0];

    NSString* extension = [path pathExtension];
    if ([extension isEqualToString:@"zip"]) {
        return YES;
    }

    if (!extension || [extension isEqualToString:@""]) {
        return YES;
    }

    return NO;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
    NSArray* properties = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];

    NSMutableArray *files =[NSMutableArray array];
    NSMutableArray *folders = [NSMutableArray array];
    
    for (NSString *path in properties) {
        BOOL isDir;
        BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (exist) {
            if (!isDir) {
                [files addObject:path];
            } else{
                [folders addObject:path];
            }
        }
    }
    
    if (files.count > 0 && [_delegate respondsToSelector:@selector(findFiles:)]) {
        [_delegate findFiles:files];
    }
    
    if (folders.count > 0 && [_delegate respondsToSelector:@selector(findFolders:)]) {
        [_delegate findFolders:folders];
    }
    
    self.strokeColor = [NSColor colorWithDeviceRed:0.80 green:0.80 blue:0.80 alpha:1.00];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
    CGFloat padding = 25.f;
    CGRect strokeRect = CGRectZero;
    strokeRect.origin.x = padding;
    strokeRect.origin.y = padding;
    strokeRect.size.width = rect.size.width - padding * 2;
    strokeRect.size.height = rect.size.height - padding * 2 - 10.f;

    CGFloat radius = 10.f;
    NSBezierPath* rectangle = [NSBezierPath bezierPathWithRoundedRect:strokeRect xRadius:radius yRadius:radius];
    [self.strokeColor setStroke];

    CGFloat dashes[] = { 6, 3 };
    [rectangle setLineDash:dashes count:2 phase:0];

    [rectangle setLineWidth:3];
    [rectangle stroke];

    [super drawRect:rect];
}

@end
