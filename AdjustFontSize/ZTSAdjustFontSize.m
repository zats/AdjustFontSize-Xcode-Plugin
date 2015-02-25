//
//  ZTSAdjustFontSize.m
//  ZTSAdjustFontSize
//
//  Created by Sasha Zats on 4/8/14.
//    Copyright (c) 2014 Sasha Zats. All rights reserved.
//

#import "ZTSAdjustFontSize.h"

typedef NSFont *(^ZTSFontModifier)(NSFont *font);

static NSString *const ZTSSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";
static NSString *const ZTSConsoleSettingsChangedNotification = @"DVTFontAndColorConsoleSettingsChangedNotification";
static NSString *const ZTSGeneralUISettingsChangedNotification = @"DVTFontAndColorGeneralUISettingsChangedNotification";

@interface DVTSourceNodeTypes : NSObject
+ (instancetype)nodeTypeNameForId:(NSInteger)nodeId;
+ (NSInteger)nodeTypesCount;
@end

@interface DVTFontAndColorTheme : NSObject
+ (instancetype)currentTheme;
- (void)setFont:(NSFont *)font forNodeTypes:(NSIndexSet *)nodeTypes;
- (NSFont *)fontForNodeType:(NSInteger)nodeType;
@end

static NSDictionary *ZTSIdentifiersToModify;

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
    [self _updateFontsWithModifier:^NSFont *(NSFont *font) {
        return [NSFont fontWithDescriptor:font.fontDescriptor
                                     size:font.pointSize + 1];
    }];
}

- (void)_decreaseFontSizeHandler {
    [self _updateFontsWithModifier:^NSFont *(NSFont *font) {
        return [NSFont fontWithDescriptor:font.fontDescriptor
                                     size:font.pointSize - 1];
    }];
}

- (void)_updateFontsWithModifier:(ZTSFontModifier)modifier {
    __weak DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    NSMutableDictionary *grouppedFonts = [NSMutableDictionary dictionary];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSInteger nodeTypeID, BOOL *stop) {
        if (!grouppedFonts[font]) {
            grouppedFonts[font] = [NSMutableIndexSet indexSetWithIndex:nodeTypeID];
        } else {
            [grouppedFonts[font] addIndex:nodeTypeID];
        }
    }];
    [grouppedFonts enumerateKeysAndObjectsUsingBlock:^(NSFont *font, NSIndexSet *indexSet, BOOL *stop) {
        [currentTheme setFont:modifier(font)
                 forNodeTypes:indexSet];
    }];
    
    [self _updateConsoleFontsWithModifier:modifier];
}

#pragma mark - Private

- (void)_setupSourceNodeTypesIdentifiersMapping {
    NSSet *knownIdentifiers = [NSSet setWithObjects:
        @"xcode.syntax.attribute", @"xcode.syntax.character", @"xcode.syntax.comment", @"xcode.syntax.comment.doc",
        @"xcode.syntax.comment.doc.keyword", @"xcode.syntax.identifier.class", @"xcode.syntax.identifier.class.system",
        @"xcode.syntax.identifier.constant", @"xcode.syntax.identifier.constant.system", @"xcode.syntax.identifier.function",
        @"xcode.syntax.identifier.function.system", @"xcode.syntax.identifier.macro", @"xcode.syntax.identifier.macro.system",
        @"xcode.syntax.identifier.type", @"xcode.syntax.identifier.type.system", @"xcode.syntax.identifier.variable",
        @"xcode.syntax.identifier.variable.system", @"xcode.syntax.keyword", @"xcode.syntax.number",
        @"xcode.syntax.plain", @"xcode.syntax.preprocessor", @"xcode.syntax.string", @"xcode.syntax.url", nil
    ];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    id sourceNodeTypesClass = NSClassFromString(@"DVTSourceNodeTypes");
    for (NSInteger index = 0; index < [sourceNodeTypesClass nodeTypesCount]; ++index) {
        NSString *identifier = [sourceNodeTypesClass nodeTypeNameForId:index];
        if ([knownIdentifiers containsObject:identifier]) {
            dictionary[identifier] = @(index);
        }
    }
    ZTSIdentifiersToModify = [dictionary copy];
}

- (void)_setupMenu {
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *fontSize = [[menuItem submenu] addItemWithTitle:@"Font size"
                                                             action:nil
                                                      keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] init];
        fontSize.submenu = submenu;
        NSMenuItem *increase = [submenu addItemWithTitle:@"Increase"
                                                  action:@selector(_increaseFontSizeHandler)
                                           keyEquivalent:@"+"];
        increase.target = self;
        NSMenuItem *decrease = [submenu addItemWithTitle:@"Decrease"
                                                  action:@selector(_decreaseFontSizeHandler)
                                           keyEquivalent:@"-"];
        decrease.target = self;
    }
}

- (DVTFontAndColorTheme *)_currentTheme {
    id fontAndColorThemeClass = NSClassFromString(@"DVTFontAndColorTheme");
    DVTFontAndColorTheme *theme = [fontAndColorThemeClass currentTheme];
    return theme;
}

- (void)_enumerateFontsForTheme:(DVTFontAndColorTheme *)theme usingBlock:(void (^)(NSFont *font, NSInteger nodeTypeID, BOOL *stop))block {
    __weak id weakTheme = theme;
    [ZTSIdentifiersToModify enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSNumber *nodeId, BOOL *stop) {
        NSFont *font = [weakTheme fontForNodeType:[nodeId integerValue]];
        block(font, [nodeId integerValue], stop);
    }];
}

- (void)_updateConsoleFontsWithModifier:(ZTSFontModifier)modifier {
    __weak DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    NSArray *consoleTextKeys = @[@"_consoleDebuggerPromptTextFont",
                                 @"_consoleDebuggerInputTextFont",
                                 @"_consoleDebuggerOutputTextFont",
                                 @"_consoleExecutableInputTextFont",
                                 @"_consoleExecutableOutputTextFont"];
    
    for (NSString *key in consoleTextKeys) {
        NSFont *font = [currentTheme valueForKey:key];
        NSFont *modifiedFont = modifier(font);
        
        [currentTheme setValue:modifiedFont forKey:key];
    };
}

@end
