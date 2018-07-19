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

#import <Foundation/Foundation.h>
#import "SAWebView.h"
#import "SAContentWebView.h"

/// Delegate to control the Browser UI from within BridgeSwitchboard
@protocol BrowserControlDelegate
- (void)loadURL:(NSURL *)url;
- (void)showNewTabWithURL:(NSURL *)url fromSource:(UIWebView *)source;
/// Incremental method to not break backward compatibility.
/// For cases where originating frame is known and needed (like window.open call)
- (void)showNewTabWithURL:(NSURL *)url fromSource:(UIWebView *)source fromFrame:(KittFrame *)frame;
@end

/**
 Central router for calls, events and messaging between content scripts
 and background scripts.
*/
@protocol ContextMenuDelegate;
@protocol BackgroundFacade;
@class BrowserExtension;
@class JSInjectorReporter;
@class CommandHandlerFactory;
@class CommandDispatcher;
@class JSBridgeContext;
@class EventDispatcher;
@class RuleActionFactory;
@class SAPopupWebView;

@interface BridgeSwitchboard : NSObject

@property (nonatomic, strong) BrowserExtension *virtualGlobalScopeExtension;
@property (nonatomic, strong) RuleActionFactory *ruleActionFactory;
@property (nonatomic, weak) id<ContextMenuDelegate> contextMenuDelegate;
// @todo remove injector as soon as all command handlers are converted to factory
@property (nonatomic, weak) JSInjectorReporter *injector;
// handler factory is owned by switchboard
@property (nonatomic, weak) id<BrowserControlDelegate> browserControlDelegate;
@property (nonatomic, weak) id<WebNavigationEventsDelegate> webNavigationDelegate;

- (BrowserExtension *)getExtension:(NSString *)fromExtensionId
                            origin:(CallbackOriginType)origin
                       fromWebView:(id<WebViewFacade>)aWebView;

// getting to know about background scripts
// one web view per script (1:1)

/// register when UIWebView for background script is instantiated
- (void)registerBackgroundWebView:(id<BackgroundFacade>)aWebView forExtension:(BrowserExtension *)extension;
/// unregister when UIWebView for background script is deleted
- (void)unregisterBackgroundWebViewForExtension:(BrowserExtension *)extension;

/// register when browser action popup is about to be displayed
- (void)registerBrowserActionPopup:(SAPopupWebView *)aWebView forExtension:(BrowserExtension *)extension;
/// unregister when the popup is about to be destroyed
- (void)unregisterBrowserActionForExtension:(BrowserExtension *)extension;

// getting to know about content scripts
// multiple scripts per web view (n:1)

/// register when scripts is about to be injected in the given webview
- (void)registerExtension:(BrowserExtension *)extension inContentWebView:(SAContentWebView *)aWebView;
/// unregister when injection fails
- (void)unregisterExtension:(BrowserExtension *)extension inContentWebView:(SAContentWebView *)aWebView;
/// unregister all extensions when webview is being reloaded (thus content scripts get lost)
- (void)unregisterExtensionsInWebView:(SAContentWebView *)aWebView;

@property (nonatomic, strong) CommandDispatcher *dispatcher;

@property (nonatomic, strong) EventDispatcher *eventDispatcher;

@property (nonatomic, strong) JSBridgeContext *bridgeContext;

@end
