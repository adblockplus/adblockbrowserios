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

#import "ExtensionBackgroundContext.h"
#import "BrowserStateModel.h"
#import "Settings.h"
#import "BridgeSwitchboard.h"
#import "Utils.h"
#import "ProtocolHandlerChromeExt.h"
#import "SAWebView.h"
#import "JSInjectorReporter.h"
#import "ProtocolHandlerJSBridge.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@implementation ExtensionBackgroundContext

- (id)initWithSwitchboard:(BridgeSwitchboard *)switchboard
               jsInjector:(JSInjectorReporter *)injector
{
    if (self = [super init]) {
        _switchboard = switchboard;
        _injector = injector;
        _reloadingTasks = [[NSMutableDictionary alloc] init];
        _webViews = [[NSMutableDictionary alloc] init];
        _skipInitialScriptLoad = NO;
    }
    return self;
}

- (id<BackgroundFacade>)backgroundWebViewFor:(NSString *)extensionId
{
    return [_webViews objectForKey:extensionId];
}

// this method already expects that extension exists and does not have a related UIWebView
- (void)addExtensionSafe:(BrowserExtension *)extension
{
    [self createBackgroundFor:extension];
}

- (void)loadScriptsOfExtensionId:(NSString *)extensionId
{
    id<BackgroundFacade> webView = _webViews[extensionId];
    if (webView) {
        [webView loadExtensionBundleScript];
    }
}

// this method already expects that extension exists and has a related UIWebView
- (void)removeExtensionSafe:(BrowserExtension *)extension
{
    [self removeBackgroundFor:extension.extensionId];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString
               inExtension:(NSString *)extensionId
         completionHandler:(void (^)(id, NSError *))completionHandler
{
    id<WebViewFacade> webView = _webViews[extensionId];
    if (!webView) {
        if (completionHandler != nil) {
            NSError *error = [NSError errorWithDomain:@"Kitt"
                                                 code:0
                                             userInfo:@{ NSLocalizedDescriptionKey : @"Requested extension has not been found." }];
            completionHandler(nil, error);
        }
        return;
    }

    if (completionHandler) {
        CallbackBox *box = [[CallbackBox alloc] init];
        void (^scopedCompletion)(id, NSError *) = ^(id evalResult, NSError *e) {
            completionHandler(evalResult, e);
            box.callback = nil;
        };
        box.callback = scopedCompletion;
        // reassign to the original handler for the following eval call
        completionHandler = scopedCompletion;
    }

    [webView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
}

- (void)setUiDelegate:(id<WKUIDelegate>)uiDelegate
{
    _uiDelegate = uiDelegate;
    [_webViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[WKWebView class]]) {
            [obj setUIDelegate:uiDelegate];
        }
    }];
}

#pragma mark -
#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *reqUrl = [request URL];
    LogDebug(@"Background shouldStartLoadWithRequest %@", [reqUrl absoluteString]);
    // allow virtual protocols
    // (delegate to ProtocolHandlerChromeExt, ProtocolHandlerJSBridge)
    if ([ProtocolHandlerChromeExt isBundleResourceRequest:request] ||
        [ProtocolHandlerJSBridge isBridgeRequestURL:request.URL]) {
        return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark ModelEventDelegate

- (void)onModelExtensionAdded:(BrowserExtension *)extension
{
    if ([_webViews objectForKey:extension.extensionId]) {
        LogWarn(@"Background got Added event for extension '%@' already in the context", extension.extensionId);
        return;
    }
    [self addExtensionSafe:extension];
}

- (void)onModelWillRemoveExtension:(BrowserExtension *)extension
{
    if (![_webViews objectForKey:extension.extensionId]) {
        if (extension.enabled) {
            LogWarn(@"Background got Removed event for enabled extension '%@' not in the context", extension.extensionId);
        }
        return;
    }
    LogDebug(@"Background removing extension '%@'", extension.extensionId);
    [self removeExtensionSafe:extension];
}

- (void)onModelExtensionChanged:(BrowserExtension *)extension
{
    id<WebViewFacade> existingView = [_webViews objectForKey:extension.extensionId];
    if (existingView && extension.enabled) {
        LogWarn(@"Background got Changed.enabled for extension '%@' already in the context", extension.extensionId);
        return;
    }
    if (!existingView && !extension.enabled) {
        LogWarn(@"Background got Changed.disabled for extension '%@' not in the context", extension.extensionId);
        return;
    }
    if (extension.enabled) {
        LogDebug(@"Background got Changed.enabled, adding extension '%@'", extension.extensionId);
        [self addExtensionSafe:extension];
    } else {
        LogDebug(@"Background got Changed.disabled, removing extension '%@'", extension.extensionId);
        [self removeExtensionSafe:extension];
    }
}

@end
