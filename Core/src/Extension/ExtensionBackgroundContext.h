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
#import "BrowserStateModel.h"

/// Manages UIWebView instances needed for background script operation and dispatches API calls from/to the scripts.
@class JSInjectorReporter;

@protocol BackgroundFacade;

@import WebKit;

@interface ExtensionBackgroundContext : NSObject <UIWebViewDelegate, // catching url change requests
                                            ExtensionModelEventDelegate // acting on extension changes
                                            >

// map of extension ids to their respective web views (1:1)
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, id> *reloadingTasks;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, id<BackgroundFacade> > *webViews;
@property (nonatomic, weak, readonly) BridgeSwitchboard *switchboard;
@property (nonatomic, weak, readonly) JSInjectorReporter *injector;

@property (nonatomic, strong) id<WKUIDelegate> uiDelegate;

- (id<BackgroundFacade>)backgroundWebViewFor:(NSString *)extensionId;

/// switchboard is our bridge to the content scripts
/// injector is the common instance of injection success/failure handling
- (id)initWithSwitchboard:(BridgeSwitchboard *)switchboard
               jsInjector:(JSInjectorReporter *)injector;

/// Default = false.
/// Must be set to true if loadScriptsOfExtensionId call is intended later.
/// Otherwise scripts will be loaded immediately upon creating the extension
/// and later loadScripts call will fail!
@property (nonatomic) BOOL skipInitialScriptLoad;

/// Will load the background scripts if it wasn't loaded upon creating the extension
- (void)loadScriptsOfExtensionId:(NSString *)extensionId;

- (void)evaluateJavaScript:(NSString *)javaScriptString
               inExtension:(NSString *)extensionId
         completionHandler:(void (^)(id, NSError *))completionHandler;

@end
