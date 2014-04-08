//
//  ZTSAdjustFontSize.m
//  ZTSAdjustFontSize
//
//  Created by Sasha Zats on 4/8/14.
//    Copyright (c) 2014 Sasha Zats. All rights reserved.
//

#import "ZTSAdjustFontSize.h"

static NSArray *ZTSNodeTypes;

@interface DVTSourceNodeTypes : NSObject
+ (instancetype)nodeTypeNameForId:(NSString *)nodeId;
+ (NSInteger)nodeTypesCount;
@end

@interface DVTFontAndColorTheme : NSObject
+ (instancetype)currentTheme;
- (void)setFont:(NSFont *)font forNodeTypes:(NSIndexSet *)nodeTypes;
- (NSFont *)fontForNodeType:(DVTSourceNodeTypes *)nodeType;
@end


static ZTSAdjustFontSize *sharedPlugin;

@interface ZTSAdjustFontSize()
@property (nonatomic, strong) NSBundle *bundle;
@end

@implementation ZTSAdjustFontSize

#pragma mark - Lifecycle

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        self.bundle = plugin;
        [self _setupNodeTypes];
        [self _setupMenu];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Handlers

- (void)_increaseFontSizeHandler {
    DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSString *nodeTypeID, DVTSourceNodeTypes *nodeType, BOOL *stop) {
        NSFont *newFont = [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize + 1];
        [currentTheme setFont:newFont forNodeTypes:[NSIndexSet indexSetWithIndex:[ZTSNodeTypes indexOfObjectIdenticalTo:nodeTypeID]]];
    }];
}

- (void)_decreaseFontSizeHandler {
    DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSString *nodeTypeID, DVTSourceNodeTypes *nodeType, BOOL *stop) {
        NSFont *newFont = [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize - 1];
        [currentTheme setFont:newFont forNodeTypes:[NSIndexSet indexSetWithIndex:[ZTSNodeTypes indexOfObjectIdenticalTo:nodeTypeID]]];
    }];
}

#pragma mark - Private

- (void)_setupNodeTypes {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ZTSNodeTypes = @[
                         @"xcode.syntax.attribute",
                         @"xcode.syntax.character",
                         @"xcode.syntax.comment",
                         @"xcode.syntax.comment.doc",
                         @"xcode.syntax.comment.doc.keyword",
                         @"xcode.syntax.identifier.class",
                         @"xcode.syntax.identifier.class.system",
                         @"xcode.syntax.identifier.constant",
                         @"xcode.syntax.identifier.constant.system",
                         @"xcode.syntax.identifier.function",
                         @"xcode.syntax.identifier.function.system",
                         @"xcode.syntax.identifier.macro",
                         @"xcode.syntax.identifier.macro.system",
                         @"xcode.syntax.identifier.type",
                         @"xcode.syntax.identifier.type.system",
                         @"xcode.syntax.identifier.variable",
                         @"xcode.syntax.identifier.variable.system",
                         @"xcode.syntax.keyword",
                         @"xcode.syntax.number",
                         @"xcode.syntax.plain",
                         @"xcode.syntax.preprocessor",
                         @"xcode.syntax.string",
                         @"xcode.syntax.url",
                         ];
    });
}

- (void)_setupMenu {
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *increaseFontSizeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Increase font size"
                                                                          action:@selector(_increaseFontSizeHandler)
                                                                   keyEquivalent:@"+"];
        increaseFontSizeMenuItem.target = self;
        [[menuItem submenu] addItem:increaseFontSizeMenuItem];
        
        NSMenuItem *decreaseFontSizeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Decrease font size"
                                                                          action:@selector(_decreaseFontSizeHandler)
                                                                   keyEquivalent:@"-"];
        decreaseFontSizeMenuItem.target = self;
        [[menuItem submenu] addItem:decreaseFontSizeMenuItem];
    }
}

- (DVTFontAndColorTheme *)_currentTheme {
    id fontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
    DVTFontAndColorTheme *theme = [fontAndColorThemeClass currentTheme];
    return theme;
}

- (void)_enumerateFontsForTheme:(DVTFontAndColorTheme *)theme usingBlock:(void (^)(NSFont *font, NSString *nodeTypeID, DVTSourceNodeTypes *nodeType, BOOL *stop))block {
    id sourceNodeTypesClass = NSClassFromString(@"DVTSourceNodeTypes");
    BOOL stop = NO;
    for (NSString *nodeNameId in ZTSNodeTypes) {
        DVTSourceNodeTypes *sourceNodeTypes = [sourceNodeTypesClass nodeTypeNameForId:nodeNameId];
        NSFont *font = [theme fontForNodeType:sourceNodeTypes];
        block(font, nodeNameId, sourceNodeTypes, &stop);
        if (stop) {
            break;
        }
    }
    
}

@end
