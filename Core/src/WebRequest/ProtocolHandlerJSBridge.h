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

/// Enumeration of known meta-protocol resources
typedef enum {
    /// initial request in case of no initial page
    JSBridgeResource_EmptyPage,
    JSBridgeResource_UsefulPage,
} JSBridgeResource;

/**
Handler for meta-protocol kitt: used to divert URL requests from UIWebView handling.
Changes the protocol and lets the request through to the server.
*/
@interface ProtocolHandlerJSBridge : NSURLProtocol

/// Tells whether the URL is a bridge schema request
+ (BOOL)isBridgeRequestURL:(nullable NSURL *)url;

/// Whether the URL is a request for virtual bridge resource
/// as defined in JSBridgeResource
+ (BOOL)isVirtualResourceBridgeRequestURL:(nonnull NSURL *)url;

/// @param path optional, can be null
/// @return URL request for particular meta-protocol resource
+ (nullable NSURL *)URLWithBridgeResource:(JSBridgeResource)resource path:(nullable NSString *)path;

@end
