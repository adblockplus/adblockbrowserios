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

#import "BridgeSwitchboard.h"
#import "Settings.h"
#import "BridgeEnums.h"
#import "Utils.h"
#import "WebRequestEventDispatcher.h"
#import "JSInjectorReporter.h"

#import <KittCore/KittCore-Swift.h>

@implementation BridgeSwitchboard {
    MessageHandler *_messageHandler;
}

- (instancetype)init
{
    if (self = [super init]) {
        _virtualGlobalScopeExtension = [[BrowserExtension alloc] initWithExtensionId:kGlobalScopeExtId
                                                                            manifest:[[Manifest alloc] init]
                                                                         persistence:nil
                                                                              bundle:nil
                                                                     commandDelegate:nil];

        _bridgeContext = [[JSBridgeContext alloc] init];
        _dispatcher = [[CommandDispatcher alloc] initWithBridgeContext:_bridgeContext];
        _eventDispatcher = [[EventDispatcher alloc] initWithBridgeSwitchboard:self];
        _messageHandler = [[MessageHandler alloc] initWithBridgeSwitchboard:self];
    }
    return self;
}

- (void)registerExtension:(BrowserExtension *)extension inContentWebView:(SAContentWebView *)aWebView
{
    NSUInteger idx = [aWebView.extensions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        bool found = [((BrowserExtension *)obj).extensionId isEqualToString:extension.extensionId];
        *stop = found;
        return found;
    }];
    if (idx == NSNotFound) {
        [aWebView.extensions addObject:extension];
    }
}

- (void)unregisterExtension:(BrowserExtension *)extension inContentWebView:(SAContentWebView *)aWebView
{
    [extension removeContentCallbacksFor:aWebView.identifier event:CallbackEvent_Undefined];
    // Script object lives on, but callbacks linked to this tab id need to be removed
    [aWebView.extensions removeObject:extension];
}

- (void)unregisterExtensionsInWebView:(SAContentWebView *)aWebView
{
    NSArray *extensionsCopy = [aWebView.extensions copy];
    for (BrowserExtension *extension in extensionsCopy) {
        [self unregisterExtension:extension inContentWebView:aWebView];
    }
    [self unregisterExtension:_virtualGlobalScopeExtension inContentWebView:aWebView];
}

- (void)registerBackgroundWebView:(id<BackgroundFacade>)aWebView forExtension:(BrowserExtension *)extension
{
    aWebView.bridgeSwitchboard = self;
    aWebView.extension = extension;
    if ([aWebView isKindOfClass:[WKWebView class]]) {
        [((WKWebView *)aWebView).configuration.userContentController addScriptMessageHandler:_messageHandler name:@"switchboard"];
    }
}

- (void)unregisterBackgroundWebViewForExtension:(BrowserExtension *)extension
{
    // Script object lives on, but callbacks registered from background script need to be removed
    [WebRequestEventDispatcher.sharedInstance removeRequestRulesForExtension:extension];
    [extension removeCallbacksFor:CallbackOriginBackground];
    [_contextMenuDelegate onContextMenuRemoveAllForExtension:extension];
}

- (void)registerBrowserActionPopup:(SAPopupWebView *)aWebView forExtension:(BrowserExtension *)extension
{
    NSAssert(aWebView.origin == CallbackOriginPopup, @"Called with incorrect origin!");
    aWebView.bridgeSwitchboard = self;
    aWebView.extension = extension;
}

- (void)unregisterBrowserActionForExtension:(BrowserExtension *)extension
{
    [extension removeCallbacksFor:CallbackOriginPopup];
}

- (BrowserExtension *)getExtension:(NSString *)fromExtensionId
                            origin:(CallbackOriginType)origin
                       fromWebView:(id<WebViewFacade>)aWebView
{
    if ([fromExtensionId isEqualToString:kGlobalScopeExtId]) {
        return _virtualGlobalScopeExtension;
    } else {
        switch (origin) {
        case CallbackOriginContent: {
            // find a related Script object
            SAContentWebView *contentWW = (SAContentWebView *)aWebView;
            NSUInteger idx = [contentWW.extensions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                bool found = [((BrowserExtension *)obj).extensionId isEqualToString:fromExtensionId];
                *stop = found;
                return found;
            }];
            if (idx != NSNotFound) {
                return [contentWW.extensions objectAtIndex:idx];
            }
        } break;
        case CallbackOriginBackground:
            return ((id<BackgroundFacade>)aWebView).extension;
        case CallbackOriginPopup:
            return ((SAPopupWebView *)aWebView).extension;
        }
    }
    return nil;
}

@end
