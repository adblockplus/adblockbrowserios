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

#import "RequestFilteringCache.h"
#import "ProtocolHandlerJSBridge.h"
#import "ProtocolHandlerChromeExt.h"
#import "ObjCLogger.h"

@implementation RequestFilteringCache

static NSDictionary *_storagePolicyNames;

+ (void)initialize
{
    _storagePolicyNames = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"allowed", [NSNumber numberWithInt:NSURLCacheStorageAllowed],
                           @"memonly", [NSNumber numberWithInt:NSURLCacheStorageAllowedInMemoryOnly],
                           @"disabled", [NSNumber numberWithInt:NSURLCacheStorageNotAllowed],
                           nil];
}

/**
 NSURLCache is the first execution point where URL loading system publishes
 NSURLRequest and allows the client code to influence the loading. Potential
 custom NSURLProtocol implementation goes next.
 However, iOS URL loading may decide that a request should be cached regardless
 of the client code opinion. The decision logic is private and unknown, but one
 condition was observed: when NSURLRequest ever gets a response without any
 cache-control header. On first request for a particular resource, the request
 passes through here and the following (potential) custom NSURLProtocol. On
 second and further request, the previous response is served right away, without
 even reaching this NSURLCache. Really, NEVER AGAIN for the same resource URL
 in the give existence of the app. The cache is cleared only by restarting
 the app. While the official spec
 http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.9
 is saying what should be happening when cache-control header IS DEFINED,
 i could not locate any authoritative answer to what should be happening when
 it is not. On the other hand, the header is NOT MANDATORY, so the iOS reaction
 is obviously inadequate.
*/
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    NSCachedURLResponse *cachedResponse = [super cachedResponseForRequest:request];
    if (
        [ProtocolHandlerChromeExt canInitWithRequest:request] ||
        [ProtocolHandlerJSBridge canInitWithRequest:request]) {
        // the request is one of our special protocols, do not cache
        LogDebug(@"NOCACHE %@", request.URL.absoluteString);
        return nil;
    }
    return cachedResponse;
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request
{
    if (
        [ProtocolHandlerChromeExt canInitWithRequest:request] ||
        [ProtocolHandlerJSBridge canInitWithRequest:request]) {
        // the request is one of our special protocols, do not cache
        return;
    }
    [super storeCachedResponse:cachedResponse forRequest:request];
}

@end
