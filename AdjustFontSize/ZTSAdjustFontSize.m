//
//  ZTSAdjustFontSize.m
//  ZTSAdjustFontSize
//
//  Created by Sasha Zats on 4/8/14.
//    Copyright (c) 2014 Sasha Zats. All rights reserved.
//

#import "ZTSAdjustFontSize.h"

@interface DVTSourceNodeTypes : NSObject
+ (instancetype)nodeTypeNameForId:(NSString *)nodeId;
+ (NSInteger)nodeTypesCount;
@end

@interface DVTFontAndColorTheme : NSObject
+ (instancetype)currentTheme;
- (void)setFont:(NSFont *)font forNodeTypes:(NSIndexSet *)nodeTypes;
- (NSFont *)fontForNodeType:(NSInteger)nodeType;
@end

static NSMutableDictionary *ZTSIdentifiersToModify;

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
        [self _setupSourceNodeTypesIdentifiersMapping];
        [self _setupMenu];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Handlers

- (void)_increaseFontSizeHandler {
    __weak DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSInteger nodeTypeID, BOOL *stop) {
        NSFont *newFont = [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize + 1];
        [currentTheme setFont:newFont
                 forNodeTypes:[NSIndexSet indexSetWithIndex:nodeTypeID]];
    }];
}

- (void)_decreaseFontSizeHandler {
    __weak DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSInteger nodeTypeID, BOOL *stop) {
        NSFont *newFont = [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize - 1];
        [currentTheme setFont:newFont
                 forNodeTypes:[NSIndexSet indexSetWithIndex:nodeTypeID]];
    }];
}

#pragma mark - Private

- (void)_setupSourceNodeTypesIdentifiersMapping {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ZTSIdentifiersToModify = [@{
            @"xcode.syntax.attribute" : @(NSNotFound),
            @"xcode.syntax.character" : @(NSNotFound),
            @"xcode.syntax.comment" : @(NSNotFound),
            @"xcode.syntax.comment.doc" : @(NSNotFound),
            @"xcode.syntax.comment.doc.keyword" : @(NSNotFound),
            @"xcode.syntax.identifier.class" : @(NSNotFound),
            @"xcode.syntax.identifier.class.system" : @(NSNotFound),
            @"xcode.syntax.identifier.constant" : @(NSNotFound),
            @"xcode.syntax.identifier.constant.system" : @(NSNotFound),
            @"xcode.syntax.identifier.function" : @(NSNotFound),
            @"xcode.syntax.identifier.function.system" : @(NSNotFound),
            @"xcode.syntax.identifier.macro" : @(NSNotFound),
            @"xcode.syntax.identifier.macro.system" : @(NSNotFound),
            @"xcode.syntax.identifier.type" : @(NSNotFound),
            @"xcode.syntax.identifier.type.system" : @(NSNotFound),
            @"xcode.syntax.identifier.variable" : @(NSNotFound),
            @"xcode.syntax.identifier.variable.system" : @(NSNotFound),
            @"xcode.syntax.keyword" : @(NSNotFound),
            @"xcode.syntax.number" : @(NSNotFound),
            @"xcode.syntax.plain" : @(NSNotFound),
            @"xcode.syntax.preprocessor" : @(NSNotFound),
            @"xcode.syntax.string" : @(NSNotFound),
            @"xcode.syntax.url" : @(NSNotFound),
        } mutableCopy];
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

- (void)_enumerateFontsForTheme:(DVTFontAndColorTheme *)theme usingBlock:(void (^)(NSFont *font, NSInteger nodeTypeID, BOOL *stop))block {
    [self _initializeMappingIfNeeded];
    __weak id weakTheme = theme;
    [ZTSIdentifiersToModify enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSNumber *nodeId, BOOL *stop) {
        NSFont *font = [weakTheme fontForNodeType:[nodeId integerValue]];
        block(font, [nodeId integerValue], stop);
    }];
}

- (void)_initializeMappingIfNeeded {
    NSInteger anyValue = [[[ZTSIdentifiersToModify allValues] firstObject] integerValue];
    if (anyValue != NSNotFound) {
        return;
    }

    id sourceNodeTypesClass = NSClassFromString(@"DVTSourceNodeTypes");
    for (NSInteger i = 0; i < [sourceNodeTypesClass nodeTypesCount]; ++i) {
        NSString *identifier = [sourceNodeTypesClass nodeTypeNameForId:i];
        if (ZTSIdentifiersToModify[identifier]) {
            // map only known identifiers so we won't change other node types
            ZTSIdentifiersToModify[identifier] = @(i);
        }
    }
}

@end
