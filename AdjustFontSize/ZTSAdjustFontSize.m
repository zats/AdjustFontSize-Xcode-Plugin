//
//  AdjustFontSize.m
//  AdjustFontSize
//
//  Created by Sash Zats on 5/26/15.
//  Copyright (c) 2015 Sash Zats. All rights reserved.
//

#import "ZTSAdjustFontSize.h"


typedef NSFont *(^ZTSFontModifier)(NSFont *font);

static NSString *const ZTSSourceTextSettingsChangedNotification = @"DVTFontAndColorSourceTextSettingsChangedNotification";
static NSString *const ZTSConsoleSettingsChangedNotification = @"DVTFontAndColorConsoleSettingsChangedNotification";
static NSString *const ZTSGeneralUISettingsChangedNotification = @"DVTFontAndColorGeneralUISettingsChangedNotification";

static NSDictionary *ZTSIdentifiersToModify;

static NSString *const ZTSAdjustFontSizeIndependentZoomKey = @"ZTSAdjustFontSizeIndependentZoomKey";

@interface DVTSourceNodeTypes : NSObject
+ (instancetype)nodeTypeNameForId:(NSInteger)nodeId;
+ (NSInteger)nodeTypesCount;
@end


@interface DVTFontAndColorTheme : NSObject
+ (instancetype)currentTheme;
- (void)setFont:(NSFont *)font forNodeTypes:(NSIndexSet *)nodeTypes;
- (NSFont *)fontForNodeType:(NSInteger)nodeType;
@end


@interface ZTSAdjustFontSize()

@property (nonatomic, strong, readwrite) NSBundle *bundle;

@end


@implementation ZTSAdjustFontSize

#pragma mark - Lifecycle

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    
    NSString *currentApplicationName = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        static ZTSAdjustFontSize *sharedPlugin;
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        self.bundle = plugin;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _setupUserDefaults];
            [self _setupSourceNodeTypesIdentifiersMapping];
            [self _setupMenu];
        });
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
    if ([self _shouldAdjustIDEFontSizesIndependently]) {
        if ([[self _currentWindowResponder] isKindOfClass:NSClassFromString(@"IDEConsoleTextView")]) {
            [self _updateConsoleFontsWithModifier:modifier];
        }
        else {
            [self _updateEditorFontsWithModifier:modifier];
        }
    }
    else {
        [self _updateConsoleFontsWithModifier:modifier];
        [self _updateEditorFontsWithModifier:modifier];
    }
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
        NSMenuItem *fontSize = [[menuItem submenu] addItemWithTitle:@"Font Size"
                                                             action:nil
                                                      keyEquivalent:@""];
        NSMenu *submenu = [[NSMenu alloc] init];
        fontSize.submenu = submenu;
        
        NSMenuItem *increase = [submenu addItemWithTitle:@"Increase"
                                                  action:@selector(_increaseFontSizeHandler)
                                           keyEquivalent:@"="];
        increase.keyEquivalentModifierMask = NSControlKeyMask;
        increase.target = self;
        
        NSMenuItem *decrease = [submenu addItemWithTitle:@"Decrease"
                                                  action:@selector(_decreaseFontSizeHandler)
                                           keyEquivalent:@"-"];
        decrease.keyEquivalentModifierMask = NSControlKeyMask;
        decrease.target = self;
        
        NSMenuItem *independentZoom = [submenu addItemWithTitle:@"Adjust Editor and Console Independently"
                                                         action:@selector(_saveIDEZoomIndependenceSetting:)
                                                  keyEquivalent:@""];
        independentZoom.state = [self _shouldAdjustIDEFontSizesIndependently] ? NSOnState : NSOffState;
        independentZoom.target = self;
    }
}

- (void)_setupUserDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ZTSAdjustFontSizeIndependentZoomKey: @NO}];
}

- (BOOL)_shouldAdjustIDEFontSizesIndependently {
    return [[NSUserDefaults standardUserDefaults] boolForKey:ZTSAdjustFontSizeIndependentZoomKey];
}

- (void)_saveIDEZoomIndependenceSetting:(NSMenuItem *)menuItem {
    BOOL shouldIndependentlyZoom = (menuItem.state == NSOnState) ? NO : YES;
    
    [[NSUserDefaults standardUserDefaults] setBool:shouldIndependentlyZoom forKey:ZTSAdjustFontSizeIndependentZoomKey];
    menuItem.state = (menuItem.state == NSOnState) ? NSOffState : NSOnState;
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

- (id)_currentWindowResponder {
    return [NSApplication sharedApplication].keyWindow.firstResponder;
}

- (void)_updateEditorFontsWithModifier:(ZTSFontModifier)modifier {
    __weak DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    NSMutableDictionary *groupedFonts = [NSMutableDictionary dictionary];
    [self _enumerateFontsForTheme:currentTheme usingBlock:^(NSFont *font, NSInteger nodeTypeID, BOOL *stop) {
        if (!groupedFonts[font]) {
            groupedFonts[font] = [NSMutableIndexSet indexSetWithIndex:nodeTypeID];
        } else {
            [groupedFonts[font] addIndex:nodeTypeID];
        }
    }];
    [groupedFonts enumerateKeysAndObjectsUsingBlock:^(NSFont *font, NSIndexSet *indexSet, BOOL *stop) {
        [currentTheme setFont:modifier(font) forNodeTypes:indexSet];
    }];
}

- (void)_updateConsoleFontsWithModifier:(ZTSFontModifier)modifier {
    DVTFontAndColorTheme *currentTheme = [self _currentTheme];
    static NSArray *consoleTextKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        consoleTextKeys = @[@"_consoleDebuggerPromptTextFont",
                            @"_consoleDebuggerInputTextFont",
                            @"_consoleDebuggerOutputTextFont",
                            @"_consoleExecutableInputTextFont",
                            @"_consoleExecutableOutputTextFont"];
    });
    
    for (NSString *key in consoleTextKeys) {
        NSFont *font = [currentTheme valueForKey:key];
        NSFont *modifiedFont = modifier(font);
        [currentTheme setValue:modifiedFont forKey:key];
    }
    
    if ([[self _currentWindowResponder] respondsToSelector:NSSelectorFromString(@"_themeFontsAndColorsUpdated")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[self _currentWindowResponder] performSelector:NSSelectorFromString(@"_themeFontsAndColorsUpdated") withObject:nil];
#pragma clang diagnostic pop
    }
}


@end
