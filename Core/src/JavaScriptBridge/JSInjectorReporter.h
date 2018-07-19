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
#import "BridgeEnums.h"

@import JavaScriptCore;

typedef void (^CommandHandlerBackendCompletion)(NSError *__nullable error, id __nullable response);

/**
 WARNING Brutal hack.
 JS callbacks are registered with extension instances, where JS code of that extension
 did add a listener. The overall design didn't anticipate callbacks which could have
 no related extension. In other words, no specific extension is adding a listener, but
 it is a "global" utility callback. This is exactly the case of fulltext search, where
 JS code needs to know about UI actions, even if no extension is installed at all.
 
 Refactoring the callback handlers so that "global events" have a special place to
 register with turned out to be a major effort. Instead, a ghost "global scope extension"
 is created, which isn't presented in the extension list and doesn't install in webviews.
 */
static NSString *const __nonnull kGlobalScopeExtId = @"GlobalScopeExtension";

/// Class representing the process and UI feedback of injecting a JavaScript code
/// into a UIWebView. Needs a standalone class because the instance is a delegate
/// for the email composition controller.
@class SAWebView, SAContentWebView;

@interface JSInjectorReporter : NSObject

@property (atomic, weak, nullable) NSThread *webThread;

NS_ASSUME_NONNULL_BEGIN

- (instancetype)init;

- (instancetype)initWithBundle:(NSBundle *)bundle;

/// @return complete JS API string for applicable webview contexts.
/// Browser action is not wrapping any script, the script is in the DOM
-(NSString *)stringWithBrowserActionAPIForExtensionId:(NSString *)extensionId
  NS_SWIFT_NAME(browserActionApi(for:));
-(NSString *)stringWithBackgroundAPIForExtensionId:(NSString *)extensionId
  NS_SWIFT_NAME(backgroundApi(for:));

/// contentscript api takes extensionid AND tabid
- (NSString *)stringWithContentScriptAPIForExtensionId:(NSString *)extensionId
                                                 tabId:(NSUInteger)tabId
                                                 runAt:(NSString *)runAt
                                        wrappingScript:(NSString *)script;
/// content DOM api takes extensionid and tabid but not a specific script
/// (it is published to whole DOM)
- (NSString *)stringWithContentDOMAPIForExtensionId:(NSString *)extensionId
                                              tabId:(NSUInteger)tabId;

/// callback entry function in window scope
- (BOOL)injectContentWindowGlobalSymbolsToWebView:(SAContentWebView *)webView
                            orNonMainFrameContext:(JSContext *)context
                                      isMainFrame:(BOOL)isMainFrame
                               scriptsInAllFrames:(BOOL)allFrames;

/**
 @param jsCode javascript snippet to inject/evaluate
 @param webView the target UIWebView for injection
 @param properties string:string map which will be attached to the formatted message
 @return YES if injection was successful
 @return NO if error is detected and email composition
 controller with preformatted output was displayed.
*/
- (BOOL)injectJavaScriptCode:(NSString *)jsCode
                   toWebView:(UIWebView *)webView
                   orContext:(JSContext *__nullable)context
       errorReportProperties:(NSDictionary *)properties;

- (void)handleInjectionResult:(NSString *)evalResult
               withCallbackId:(NSString *)callbackId
                   withOrigin:(CallbackOriginType)origin
        errorReportProperties:(NSDictionary *)properties
                andCompletion:(CommandHandlerBackendCompletion)completion;

NS_ASSUME_NONNULL_END

@end
