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

@protocol NetworkActivityDelegate <NSObject>
- (void)onNetworkLoadingProgress:(double)progress;
- (void)onNetworkActivityState:(BOOL)active;
@end

@class SAContentWebView;

/**
@discussion
Used by all instances of Protocol Handler to harvest network connections activity.
Emits a global notification in case of any network activity regardless of tab id.
Activity grouped by tab id and routed to registered activity delegates by tab id.
Thread safe.

@todo resource loading progress computation per tab id
 */
@interface NetworkActivityObserver : NSObject <UIWebViewDelegate>

extern NSString *__nonnull const kNetworkActivityNotification;

/**
 Must be a singleton because it's used by NSURLProtocol implementation, of
 which we don't control the constructor signature neither instantiation, and
 there is an arbitrary number of instances. Any kind of post-constructor
 dependency injection is unreliable because we can't know how early will the
 particular instance be used by URL loading system.
 */
// TDD setter
+ (void)setSharedInstance:(NetworkActivityObserver *__nonnull)instance;
// static getter
+ (NetworkActivityObserver *__nonnull)sharedInstance;
+ (BOOL)activityStatusFromNotificationUserInfo:(NSDictionary *__nonnull)userInfo;
// NSURLProtocol init/dealloc
- (void)onProtocolHandlerInstantiated;
- (void)onProtocolHandlerDeallocated;
// creation/destruction of tab id contexts
// @see SAContentWebView
- (void)registerActivityDelegate:(id<NetworkActivityDelegate> __nonnull)delegate forTabId:(NSUInteger)tabId;
- (void)unregisterActivityDelegateForTabId:(NSUInteger)tabId;
// NSURLConnectionDelegate event handlers
// tabId is nil for connections not bound to any tab (background XHR etc.)
- (void)registerNewConnection:(NSURLConnection *__nonnull)connection forTabId:(NSNumber *__nullable)tabId;
- (void)connection:(NSURLConnection *__nonnull)connection receivedResponseWithExpectedLength:(long long)length;
- (void)connection:(NSURLConnection *__nonnull)connection receivedDataLength:(NSUInteger)length;
- (void)unregisterConnection:(NSURLConnection *__nonnull)connection;

- (void)tryTocompleteProcessOfWebView:(UIWebView *__nonnull)sender;

- (void)onReadyStateDidChanged:(SAContentWebView *__nonnull)sender;

@end
