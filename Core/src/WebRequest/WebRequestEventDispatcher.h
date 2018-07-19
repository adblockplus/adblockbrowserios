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

@class RequestRule;
@class WebRequestDetails;
@class BlockingResponse;
@class BrowserHistoryManager;
@class SessionManager;
@class AsyncJavascriptResourceTypeDetector;
typedef void (^ResponseBlock)(BlockingResponse *__nonnull);

/// Threadsafe singleton observer of ModelEventDelegate, keeping a list
/// of BrowserExtension objects as WebRequestDelegate interfaces.
/// Capable of iterating the delegate methods while calling a specific method.
@interface WebRequestEventDispatcher : NSObject <ExtensionModelEventDelegate>

/// TDD setter
+ (void)setSharedInstance:(WebRequestEventDispatcher *__nonnull)instance;
/// static getter
+ (WebRequestEventDispatcher *__nonnull)sharedInstance;

/// Some background script has created a declarativeWebRequest rule
- (void)addRequestRule:(RequestRule *__nonnull)rule;
- (void)removeRequestRuleForCallbackId:(NSString *__nonnull)callbackId;
/// Give ProtocolHandlers access to bundle resources
- (NSData *__nullable)dataOfResource:(NSString *__nonnull)resource
                         extensionId:(NSString *__nonnull)extensionId;

- (SessionManager *__nullable)sessionManagerForWebViewWithTabId:(NSUInteger)tabId;

- (void)removeRequestRulesForExtension:(BrowserExtension *__nonnull)extension;

- (void)applyRulesOnDetails:(WebRequestDetails *__nonnull)details
          modifyingResponse:(BlockingResponse *__nonnull)response
                finishBlock:(ResponseBlock __nonnull)finishBlock;

@end
