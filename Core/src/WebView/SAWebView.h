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

// A transparent subclass of UIWebView. All UIWebView instantiations in
// the project have been converted to this class.
//
// Currently it serves just as a vehicle for logging de/allocations. Might be
// very useful in the future, for example carrying the creation scope with it,
// instead of various maps scattered through the project.

#import <UIKit/UIKit.h>
#import "BridgeEnums.h"
#import "WebViewFacade.h"
@import JavaScriptCore;

/// A reflection of WebKit-private WebFrame, which cannot be used directly
@protocol WebKitFrame <NSObject>
- (id _Nullable)parentFrame;

@end

@class KittFrame, BridgeSwitchboard;

@interface SAWebView : UIWebView <WebViewFacade>

/// Can be called from any thread
- (NSEnumerator *__nonnull)threadsafeKittFrames;
/// Is expected to be called from main thread
/// @return the created KittFrame for given WebKittFrame. Has its frame URL already set.
- (KittFrame *__nonnull)mainThreadAddContext:(JSContext *__nonnull)context
                                   fromFrame:(id<WebKitFrame> __nonnull)webKitFrame;
- (KittFrame *__nullable)kittFrameForWebKitFrame:(id __nonnull)frame;
- (KittFrame *__nullable)kittFrameForReferer:(NSString *__nonnull)referer;
/// In case of ProtocolHandler request arriving before JSC creation,
/// the request needs a temporary frame which will not have JS context.
/// Creates main frame mapping (-1,0) if parentFrameURLString is null
- (KittFrame *__nonnull)provisionalFrameForURL:(NSString *__nonnull)url
                      parentFrameRefererString:(NSString *__nullable)parentFrameURLString;

/// HTML5 history events do not make any frame load requests, however
/// any resource, loaded from frame, has it referer set to url of last event.
- (void)assignAliasForCurrentMainFrame:(NSString *__nullable)alias;

@property (nonatomic, nullable, readonly, weak) BridgeSwitchboard *bridgeSwitchboard;

@end
