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

/**
A protocol of properties detectable/derivable from webview request(s)
To be used in scope of the request handling instead of whole webview reference.
*/
typedef NS_ENUM(NSUInteger, RequestSecurityLevel) {
    RequestSecurityLevelUnknown, // security validation failed
    RequestSecurityLevelInsecure, // plain non SSL request
    RequestSecurityLevelUntrusted, // SSL not trusted
    RequestSecurityLevelTrustForced, // SSL not trusted but user approved
    RequestSecurityLevelTrustImplicit, // SSL trusted
    RequestSecurityLevelTrustExtended // SSL EV identified
};

/// This could as well be struct but ARC prohibits NSObject descendants in structs
/// In Swift this will be obviously enum, EVOrgName applies only to TrustExtended
@protocol AuthenticationResultProtocol

- (nonnull instancetype)initWithLevel:(RequestSecurityLevel)level host:(nonnull NSString *)host;
@property (nonatomic, readonly, nonnull) NSString *host;
@property (nonatomic, readonly) RequestSecurityLevel level;
@property (nonatomic, copy, nullable) NSString *EVOrgName;

@end

@protocol WebKitFrame;

@protocol WebViewProtocolDelegate <NSObject>

@property (nonatomic, copy, nonnull) id<AuthenticationResultProtocol> mainFrameAuthenticationResult;
- (void)DOMNodeForSourceAttribute:(nonnull NSString *)srcAttr
                       completion:(nonnull void (^)(NSString *__nullable nodeName, id<WebKitFrame> __nullable sourceFrame))completion;
- (void)onRedirectResponse:(nonnull NSURLResponse *)redirResponse
                 toRequest:(nonnull NSURLRequest *)newRequest;
- (void)onErrorOccuredWithRequest:(nonnull NSURLRequest *)request;
- (void)onDidStartLoadingURL:(nonnull NSURL *)url isMainFrame:(BOOL)isMainFrame;
@end
