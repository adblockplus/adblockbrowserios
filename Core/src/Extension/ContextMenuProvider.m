/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "ContextMenuProvider.h"
#import "BridgeSwitchboard.h"
#import "Utils.h"
#import "BrowserPageSharingActivity.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@implementation CurrentContextURLs

@end

@interface ContextMenuProvider ()
@property (nonatomic, assign) id<NativeActionCommandDelegate> commandDelegate;
@property (nonatomic, strong) NSMutableArray *registeredMenuItems;
@property (nonatomic, assign) UIWebView *editingWebView;
@property (nonatomic, strong) NSRegularExpression *rexEditingMenuSelector;
@end

#define EDITING_MENU_SELECTOR_PREFIX @"EditingMenuItem_"

@implementation ContextMenuProvider

- (id)initWithCommandDelegate:(id<NativeActionCommandDelegate>)commandDelegate
{
    self = [super init];
    if (self) {
        _commandDelegate = commandDelegate;
        _registeredMenuItems = [NSMutableArray new];
        NSError *err = nil;
        _rexEditingMenuSelector = [NSRegularExpression
            regularExpressionWithPattern:
                [NSString stringWithFormat:@"^%@([a-zA-Z0-9]+)$",
                          EDITING_MENU_SELECTOR_PREFIX]
                                 options:0
                                   error:&err];
        if (err) {
            _rexEditingMenuSelector = nil;
        }
    }
    return self;
}

- (NSInteger)arrayIndexForButtonIndex:(NSInteger)buttonIndex
{
    return [_registeredMenuItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        ContextMenuItem *menuItem = (ContextMenuItem *)obj;
        bool match = (menuItem.buttonIndex == buttonIndex);
        *stop = match;
        return match;
    }];
}

- (NSInteger)arrayIndexForMenuId:(NSString *)menuId
{
    return [_registeredMenuItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        ContextMenuItem *menuItem = (ContextMenuItem *)obj;
        bool match = [menuItem.menuId isEqualToString:menuId];
        *stop = match;
        return match;
    }];
}

- (BOOL)testAndReportMatchURL:(NSURL *)url
                  withRegexes:(NSArray *)regexes
{
    if (!url || !regexes || ([regexes count] == 0)) {
        // nothing to match, defaults to ok
        return YES;
    }
    NSString *urlStr = [url absoluteString];
    NSUInteger idx = [Utils indexOfMatchInRegexArray:regexes forString:urlStr];
    return idx != NSNotFound;
}

- (BOOL)isMenuItemApplicable:(ContextMenuItem *)menuItem
               toCurrentURLs:(CurrentContextURLs *)urls
                   inContext:(MenuContextType)contextType
{
    if (![menuItem isEnabled]) {
        return NO;
    }
    if (![menuItem isApplicableToContext:contextType]) {
        return NO;
    }
    if (![self testAndReportMatchURL:urls.link
                         withRegexes:[menuItem arrayOfRegexesForTargetURL]]) {
        return NO;
    }
    if (![self testAndReportMatchURL:urls.page
                         withRegexes:[menuItem arrayOfRegexesForDocumentURL]]) {
        return NO;
    }
    return YES;
}

#pragma mark -
#pragma mark ContextMenuDataSource

- (NSArray *)getActivityActionsForURLs:(CurrentContextURLs *)urls
{
    for (ContextMenuItem *menuItem in _registeredMenuItems) {
        menuItem.buttonIndex = NSNotFound;
    }

    NSArray *applicableMenus =
        [_registeredMenuItems filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            ContextMenuItem *menuItem = (ContextMenuItem *)obj;
            return [self isMenuItemApplicable:menuItem
                                toCurrentURLs:urls
                                    inContext:MenuContext_WholeWebPage];
        }]];

    if (![applicableMenus count]) {
        return nil;
    }

    NSMutableArray *activities = [NSMutableArray arrayWithCapacity:[applicableMenus count]];

    for (ContextMenuItem *menuItem in applicableMenus) {
        BrowserPageSharingActivity *activity = [[BrowserPageSharingActivity alloc] initWithContextMenuItem:menuItem];
        [activities addObject:activity];
    }

    return activities;
}

- (void)activityTypeClicked:(NSString *)type
                withPageURL:(NSURL *)pageURL
{
    NSInteger index = [_registeredMenuItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        ContextMenuItem *menuItem = (ContextMenuItem *)obj;
        bool match = [[menuItem activityType] isEqualToString:type];
        *stop = match;
        return match;
    }];

    if (index == NSNotFound) {
        LogWarn(@"URL context action of type %@ has been clicked, but it is unknown.", type);
        return;
    }

    ContextMenuItem *menuItem = _registeredMenuItems[index];

    NSDictionary *clickProps = @{
        @"menuItemId" : menuItem.menuId,
        @"pageUrl" : pageURL ? pageURL.absoluteString : [NSNull null]
    };
    [_commandDelegate.eventDispatcher contextMenuClicked:menuItem.originExtension
                                                    json:clickProps];
}

- (void)addActionsForURLs:(CurrentContextURLs *)urls
              toContainer:(UIActionSheet *)container
                inContext:(MenuContextType)contextType
{
    for (ContextMenuItem *menuItem in _registeredMenuItems) {
        menuItem.buttonIndex = NSNotFound;
    }
    NSArray *applicableMenus = [_registeredMenuItems filteredArrayUsingPredicate:
                                                         [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                                                             ContextMenuItem *menuItem = (ContextMenuItem *)obj;
                                                             return [self isMenuItemApplicable:menuItem
                                                                                 toCurrentURLs:urls
                                                                                     inContext:contextType];
                                                         }]];
    if (![applicableMenus count]) {
        return;
    }
    for (ContextMenuItem *menuItem in applicableMenus) {
        NSInteger buttonIndex = [container addButtonWithTitle:[menuItem title]];
        menuItem.buttonIndex = buttonIndex;
    }
}

- (BOOL)isButtonIndex:(NSInteger)actionIndex registeredForContext:(MenuContextType)contextType
{
    NSUInteger index = [_registeredMenuItems indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        ContextMenuItem *menuItem = (ContextMenuItem *)obj;
        BOOL match = (menuItem.buttonIndex == actionIndex) && [menuItem isApplicableToContext:contextType];
        *stop = match;
        return match;
    }];
    return (index != NSNotFound);
}

- (void)actionIndexClicked:(NSInteger)actionIndex
             withSelection:(NSString *)selectedText
                  withURLs:(CurrentContextURLs *)urls
{
    NSInteger idx = [self arrayIndexForButtonIndex:actionIndex];
    if (idx == NSNotFound) {
        LogWarn(@"URL context action index %ld clicked but unknown", (long)actionIndex);
        return;
    }
    ContextMenuItem *menuItem = [_registeredMenuItems objectAtIndex:idx];
    NSDictionary *clickProps = @{
        @"menuItemId" : menuItem.menuId,
        @"selectionText" : selectedText,
        @"pageUrl" : urls.page ? urls.page.absoluteString : [NSNull null],
        @"linkUrl" : urls.link ? urls.link.absoluteString : [NSNull null],
        @"srcUrl" : urls.image ? urls.image.absoluteString : [NSNull null]
    };
    [_commandDelegate.eventDispatcher contextMenuClicked:menuItem.originExtension
                                                    json:clickProps];
}

#pragma mark -
#pragma mark ContextMenuDelegate

- (void)onContextMenuCreateId:(NSString *)createMenuId
               withProperties:(NSDictionary *)properties
                fromExtension:(BrowserExtension *)extension
{
    ContextMenuItem *menuItem = [[ContextMenuItem alloc] initWithMenuId:createMenuId
                                                        originExtension:extension];
    NSError *err = nil;
    [menuItem setInitialProperties:properties error:&err];
    if (err) {
        UIAlertView *alert = [Utils alertViewWithError:err
                                                 title:[NSString stringWithFormat:@"%@: create context menu", extension.manifest.name]
                                              delegate:nil];
        [alert show];
        return;
    }
    [_registeredMenuItems addObject:menuItem];
    [self updateEditingMenuItems];
}

- (void)onContextMenuUpdateId:(NSString *)updateMenuId
               withProperties:(NSDictionary *)properties
{
    NSInteger idx = [self arrayIndexForMenuId:updateMenuId];
    if (idx == NSNotFound) {
        LogError(@"Menu id '%@' requested for update, but not found", updateMenuId);
        return;
    }
    ContextMenuItem *menuItem = [_registeredMenuItems objectAtIndex:idx];
    NSError *err = nil;
    [menuItem mergeWithProperties:properties error:&err];
    if (err) {
        UIAlertView *alert = [Utils alertViewWithError:err
                                                 title:[NSString stringWithFormat:@"Update context menu %@", updateMenuId]
                                              delegate:nil];
        [alert show];
        return;
    }
    [self updateEditingMenuItems];
}

- (void)onContextMenuRemoveId:(NSString *)removeMenuId
{
    NSInteger idx = [self arrayIndexForMenuId:removeMenuId];
    if (idx == NSNotFound) {
        LogError(@"Menu id '%@' requested for delete, but not found", removeMenuId);
        return;
    }
    [_registeredMenuItems removeObjectAtIndex:idx];
    [self updateEditingMenuItems];
}

- (void)onContextMenuRemoveAllForExtension:(BrowserExtension *)extension
{
    [_registeredMenuItems filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
        ContextMenuItem *menuItem = (ContextMenuItem *)obj;
        return ![menuItem.originExtension isEqual:extension];
    }]];
    [self updateEditingMenuItems];
}

- (void)setEditingWebView:(UIWebView *)webView
{
    _editingWebView = webView;
}

- (void)updateEditingMenuItems
{
    NSMutableArray *items = [NSMutableArray new];
    for (ContextMenuItem *menuItem in _registeredMenuItems) {
        NSString *selectorStr = [NSString stringWithFormat:@"%@%@", EDITING_MENU_SELECTOR_PREFIX, menuItem.menuId];
        [items addObject:[[UIMenuItem alloc] initWithTitle:[menuItem title] action:NSSelectorFromString(selectorStr)]];
    }
    [[UIMenuController sharedMenuController] setMenuItems:items];
}

- (BOOL)acceptsEditingMenuSelector:(SEL)aSelector withURLs:(CurrentContextURLs *)urls
{
    NSString *sel = NSStringFromSelector(aSelector);
    NSTextCheckingResult *firstMatch = [_rexEditingMenuSelector firstMatchInString:sel options:0 range:NSMakeRange(0, [sel length])];
    if (firstMatch) {
        NSString *menuId = [sel substringWithRange:[firstMatch rangeAtIndex:1]];
        NSInteger idx = [self arrayIndexForMenuId:menuId];
        ContextMenuItem *menuItem = [_registeredMenuItems objectAtIndex:idx];
        if ([self isMenuItemApplicable:menuItem
                         toCurrentURLs:urls
                             inContext:MenuContext_TextSelection]) {
            menuItem.lastPageURL = urls.page;
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    if ([super methodSignatureForSelector:aSelector]) {
        return [super methodSignatureForSelector:aSelector];
    }
    return [super methodSignatureForSelector:@selector(selectedEditingMenuId:)];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSString *sel = NSStringFromSelector([anInvocation selector]);
    NSTextCheckingResult *firstMatch = [_rexEditingMenuSelector firstMatchInString:sel options:0 range:NSMakeRange(0, [sel length])];
    if (firstMatch) {
        NSString *menuId = [sel substringWithRange:[firstMatch rangeAtIndex:1]];
        [self selectedEditingMenuId:menuId];
    } else {
        [super forwardInvocation:anInvocation];
    }
}

- (void)selectedEditingMenuId:(NSString *)menuId
{
    NSString *selectedText = [_editingWebView stringByEvaluatingJavaScriptFromString:@"window.getSelection().toString()"];
    NSInteger idx = [self arrayIndexForMenuId:menuId];
    ContextMenuItem *menuItem = [_registeredMenuItems objectAtIndex:idx];
    NSDictionary *clickProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 menuItem.menuId, @"menuItemId",
                                             [menuItem.lastPageURL absoluteString], @"pageUrl",
                                             [NSNull null], @"linkUrl",
                                             selectedText, @"selectionText",
                                             nil];
    [_commandDelegate.eventDispatcher contextMenuClicked:menuItem.originExtension
                                                    json:clickProps];
}

@end
