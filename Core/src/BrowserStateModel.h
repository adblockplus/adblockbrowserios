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
#import "ExtensionModelEventDelegate.h"
#import "ExtensionViewDelegates.h"
#import "SAContentWebView.h"

@class JSContext;
@class BridgeSwitchboard;
@class ExtensionPersistence;
@class ExtensionUnpacker;
@class JSInjectorReporter;
@class BrowserStateCoreData;

@protocol ContentScriptLoaderDelegate <NSObject>
/// do injection
/// @param URL known URL of the context's frame
/// @param view webview of the context's frame
- (NSInteger)injectContentScriptToContext:(JSContext *)context withURL:(NSURL *)url ofContentWebView:(SAContentWebView *)view;
/// Validates and executes extension installation request
- (void)filterExtensionInstallationFromURL:(NSURL *)reqUrl completionHandler:(void (^)(NSError *))completionHandler;

- (BridgeSwitchboard *)bridgeSwitchboard;
@end

/// Event delegate for persistent changes in BrowserExtension.
/// For now just enabling/disabling.
@protocol BrowserExtensionChangeDelegate <NSObject>
@optional
- (void)browserExtension:(BrowserExtension *)extension enabled:(BOOL)enabled;
@end

/// model is a delegate for BrowserExtension changes, distributing events
/// to ExtensionModelEventDelegates
@interface BrowserStateModel : NSObject <ExtensionModelDataSource,
                                        ContentScriptLoaderDelegate,
                                        BrowserExtensionChangeDelegate,
                                        WebNavigationEventsDelegate>

/// injector is the common instance of injection success/failure handling
- (id)initWithSwitchboard:(BridgeSwitchboard *)switchboard
              persistence:(BrowserStateCoreData *)persistence
           bundleUnpacker:(ExtensionUnpacker *)unpacker
               jsInjector:(JSInjectorReporter *)injector;

- (JSInjectorReporter *)injector;

/// load already installed extensions
- (BOOL)loadExtensions:(NSError **)error;

// observer pattern
- (void)subscribe:(id<ExtensionModelEventDelegate>)delegate;
- (void)unsubscribe:(id<ExtensionModelEventDelegate>)delegate;

- (BrowserExtension *)unpackAndCreateExtensionWithId:(NSString *)extensionId
                                            fromData:(NSData *)data
                                               error:(NSError *__autoreleasing *)error;

- (BrowserExtension *)extensionWithId:(NSString *)extensionId;

@end
