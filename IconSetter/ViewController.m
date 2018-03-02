//
//  ViewController.m
//  IconSetter
//
//  Created by Keith Ellis on 16/5/21.
//  Copyright © 2016年 Keith Ellis. All rights reserved.
//

#import "ViewController.h"
#import "ZipZap.h"

@interface ViewController ()

@property (nonatomic, strong) NSOperationQueue* queue;
@property (atomic, assign) NSUInteger complete;
@property (atomic, assign) NSUInteger total;

@end

@implementation ViewController

- (id)initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
        self.total = 0;
        self.complete = 0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)findFiles:(NSArray *)files
{
    for (NSString *path in files) {
        NSString *filename = [path lastPathComponent];
        NSString* extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"zip"]) {
            [self addToQueue:path];
        }
    }
}

-(void)findFolders:(NSArray *)folders
{
    for (NSString *path in folders) {
        [self findFolder:path];
    }
}

- (void)findFolder:(NSString*)path
{
    if (path) {
        NSError* error;
        NSArray* items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
        if (error) {
            NSLog(@"List folder contens failed.");
            return;
        }

        [items enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL* _Nonnull stop) {
            NSString* filename = (NSString*)obj;
            NSString* extension = [[filename pathExtension] lowercaseString];
            if ([extension isEqualToString:@"zip"]) {
                NSString* fullPath = [NSString stringWithFormat:@"%@/%@", path, filename];
                [self addToQueue:fullPath];
            }
        }];
    }
}

- (void)addToQueue:(NSString*)zipFilePath
{
    NSBlockOperation* operation = [NSBlockOperation blockOperationWithBlock:^{
        [self processZipArchive:zipFilePath];
    }];
    [operation setCompletionBlock:^{
        
    }];
    [_queue addOperation:operation];
}

- (void)processZipArchive:(NSString*)filePath
{
    NSError* error;
    ZZArchive* archive = [ZZArchive archiveWithURL:[NSURL fileURLWithPath:filePath] error:&error];
    if (error) {
        NSLog(@"Open zip archive failed");
        return;
    }

    NSArray<ZZArchiveEntry*>* entries = archive.entries;

    NSArray<ZZArchiveEntry*>* sortedEntries = [entries sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        ZZArchiveEntry* entry1 = (ZZArchiveEntry*)obj1;
        ZZArchiveEntry* entry2 = (ZZArchiveEntry*)obj2;

        NSString* fileName1 = [[NSString alloc] initWithData:entry1.rawFileName encoding:NSUTF8StringEncoding];
        NSString* fileName2 = [[NSString alloc] initWithData:entry2.rawFileName encoding:NSUTF8StringEncoding];

        return [fileName1 compare:fileName2 options:NSNumericSearch];
    }];

    for (ZZArchiveEntry* entry in sortedEntries) {
        NSString* fileName = [[NSString alloc] initWithData:entry.rawFileName encoding:NSUTF8StringEncoding];
        if (![fileName containsString:@"__MACOSX"]) {
            NSString* extension = [fileName pathExtension];
            if (extension) {
                if ([[extension lowercaseString] isEqualToString:@"jpg"]
                    || [[extension lowercaseString] isEqualToString:@"jpeg"]
                    || [[extension lowercaseString] isEqualToString:@"png"]) {
                    NSData* fileData = [entry newDataWithError:&error];
                    if (!error) {
                        NSLog(@"Image data size: %zd", fileData.length);
                        [self setIcon:filePath imageData:fileData extension:extension];
                        break;
                    }
                    else {
                        NSLog(@"Read image file failed.");
                    }
                }
            }
        }
    }
}

- (void)setIcon:(NSString*)archivePath imageData:(NSData*)imageData extension:(NSString*)extension
{
    NSString* tempDirPath = NSTemporaryDirectory();
    NSString* dirName = [[NSUUID UUID] UUIDString];
    NSString* dirPath = [NSString stringWithFormat:@"%@%@", tempDirPath, dirName];

    NSLog(@"Temp work path: %@", dirPath);

    NSError* error;
    [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        NSLog(@"Create work dir failed.");
        return;
    }

    NSString* iconSetPath = [NSString stringWithFormat:@"%@/%@", dirPath, @"icon.iconset"];
    [[NSFileManager defaultManager] createDirectoryAtPath:iconSetPath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        [self deleteQuiet:dirPath];
        NSLog(@"Create icon dir failed.");
        return;
    }

    NSString* imagePath = [NSString stringWithFormat:@"%@/%@.%@", dirPath, @"original", extension];
    BOOL result = [imageData writeToFile:imagePath atomically:YES];
    if (!result) {
        [self deleteQuiet:dirPath];
        NSLog(@"Write image data to file failed.");
        return;
    }
    
//    NSString* imagePath = [NSString stringWithFormat:@"%@/%@.%@", dirPath, @"original", extension];
//    NSTask* task = [[NSTask alloc] init];
//    [task setLaunchPath:@"/bin/zsh"];
//    NSString* fix = [NSString stringWithFormat:@"/usr/local/bin/convert %@ -set colorspace RGB -type truecolor %@", imageInputPath, imagePath];
//    [task setArguments:@[ @"-c", fix ]];
//    
//    [task launch];
//    [task waitUntilExit];
//    
//    if ([task terminationStatus] != 0) {
//        [self deleteQuiet:dirPath];
//        NSLog(@"Fix image failed.");
//        return;
//    }
    
    // TODO Convert original bad input image

    NSString* icnsPath = [NSString stringWithFormat:@"%@/%@", dirPath, @"icon.icns"];
    NSString* shell = [self createCommand:imagePath workDir:iconSetPath];

    NSString* shellPath = [NSString stringWithFormat:@"%@/%@", dirPath, @"shell"];
    result = [shell writeToFile:shellPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!result || error) {
        [self deleteQuiet:dirPath];
        NSLog(@"Write shell command to file failed.");
        return;
    }

    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] init];
    [attributes setValue:[NSNumber numberWithShort:0777] forKey:NSFilePosixPermissions];
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:shellPath error:&error];
    if (error) {
        [self deleteQuiet:dirPath];
        NSLog(@"Change shell file permission faield.");
        return;
    }

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/zsh"];
    [task setArguments:@[ @"-c", shellPath ]];

    [task launch];
    [task waitUntilExit];

    if ([task terminationStatus] != 0) {
        [self deleteQuiet:dirPath];
        NSLog(@"Resize image failed.");
        return;
    }

    NSLog(@"Try to check icon png file write finished.");
    NSArray* iconsFiles = @[ @"icon_16x16.png",
        @"icon_16x16@2x.png",
        @"icon_32x32.png",
        @"icon_32x32@2x.png",
        @"icon_128x128.png",
        @"icon_128x128@2x.png",
        @"icon_256x256.png",
        @"icon_256x256@2x.png",
        @"icon_512x512.png",
        @"icon_512x512@2x.png" ];
    while (true) {
        BOOL finished = YES;
        for (NSString* fileName in iconsFiles) {
            NSString* path = [NSString stringWithFormat:@"%@/%@", iconSetPath, fileName];
            BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NO];
            unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error] fileSize];
            if (!exist || fileSize <= 0) {
                finished = NO;
            }
        }
        if (finished) {
            break;
        }
    }

    // FIXME
    [NSThread sleepForTimeInterval:1.0f];

    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/zsh"];
    NSString* convert = [NSString stringWithFormat:@"iconutil -c icns %@ -o %@", iconSetPath, icnsPath];
    [task setArguments:@[ @"-c", convert ]];

    [task launch];
    [task waitUntilExit];

    if ([task terminationStatus] != 0) {
        [self deleteQuiet:dirPath];
        NSLog(@"Convert image to icns failed.");
        return;
    }

    NSImage* icnsImage = [[NSImage alloc] initWithContentsOfFile:icnsPath];
    [[NSWorkspace sharedWorkspace] setIcon:icnsImage forFile:archivePath options:0];

    [self deleteQuiet:dirPath];
}

- (void)deleteQuiet:(NSString*)path
{
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
}

- (NSString*)createCommand:(NSString*)imagePath workDir:(NSString*)workDir
{
    NSString* template = @"/usr/local/bin/convert %@ -set colorspace sRGB -type truecolor -resize %@ -background \"rgba(255,255,255,0)\" -gravity center -extent %@ %@/icon_%@.png";
    NSArray* sets = @[
        @{ @"size" : @"1024x1024",
            @"name" : @"512x512@2x" },
        @{ @"size" : @"512x512",
            @"name" : @"512x512" },
        @{ @"size" : @"512x512",
            @"name" : @"256x256@2x" },
        @{ @"size" : @"256x256",
            @"name" : @"256x256" },
        @{ @"size" : @"256x256",
            @"name" : @"128x128@2x" },
        @{ @"size" : @"128x128",
            @"name" : @"128x128" },
        @{ @"size" : @"64x64",
            @"name" : @"32x32@2x" },
        @{ @"size" : @"32x32",
            @"name" : @"32x32" },
        @{ @"size" : @"32x32",
            @"name" : @"16x16@2x" },
        @{ @"size" : @"16x16",
            @"name" : @"16x16" },
    ];

    NSMutableString* script = [NSMutableString string];
    NSUInteger count = sets.count;
    for (NSUInteger index = 0; index < count; index++) {
        NSDictionary* item = [sets objectAtIndex:index];
        NSString* size = [item objectForKey:@"size"];
        NSString* name = [item objectForKey:@"name"];

        NSString* tmp = [NSString stringWithFormat:template, imagePath, size, size, workDir, name];
        [script appendString:tmp];
        if (index != count - 1) {
            [script appendString:@" & "];
        }
    }

    return script;
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    self.view.window.titlebarAppearsTransparent = YES;
    self.view.window.styleMask |= NSFullSizeContentViewWindowMask;
}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
