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

#import "ProtocolHandlerChromeExt.h"
#import "WebRequestEventDispatcher.h"
#import "NSHTTPURLResponse+Uncacheable.h"
#import "ObjCLogger.h"

@implementation ProtocolHandlerChromeExt

/// bundle resource URL matching pattern
static NSRegularExpression *_rexURL = nil;
static NSDictionary *_suffixMimeMatches;

#define BUNDLE_SCHEME @"chrome-extension"

+ (void)initialize
{
    NSError *err = nil;
    /// BUNDLE_SCHEME://extensionId/resource
    _rexURL = [NSRegularExpression regularExpressionWithPattern:
                                       [NSString stringWithFormat:@"^\\s*(%@://[A-Za-z0-9_-]+/.+?)\\s*$", BUNDLE_SCHEME]
                                                        options:0
                                                          error:&err];
    if (err) {
        LogError(@"Error compiling URL pattern: %@", [err description]);
        _rexURL = nil;
    }
    // This seemingly duplicates the matching structure already done in
    // WebRequestDetails. But this does a different, way simpler lookup.
    // Ideally there would be an universal bidirectional matcher utility,
    // but i'm sacrificing technical debt relief on the altar of feature progress.

    /// Must specify charset=utf-8 for textual formats so that the data from filesystem are not
    /// converted to default ASCII (hence UTF8 chars becoming unexpected hex codes).
    /// When the file by chance does not contain any UTF8 chars, the charset is harmless.
    _suffixMimeMatches = @{
        @"application/xml; charset=utf-8" : @".xml",
        @"text/html; charset=utf-8" : @".html",
        @"text/plain; charset=utf-8" : @".txt",
        @"application/json; charset=utf-8" : @".json",
        @"text/css; charset=utf-8" : @".css",
        @"application/javascript; charset=utf-8" : @".js",
        @"image/jpeg" : @".jpg",
        @"image/gif" : @".gif",
        @"image/png" : @".png",
        @"application/pdf" : @".pdf"
    };
}

+ (NSURL *)URLAsBundleResourceFromString:(NSString *)urlString
{
    if ([urlString length] == 0) {
        return nil;
    }
    NSTextCheckingResult *firstMatch = [_rexURL firstMatchInString:urlString
                                                           options:0
                                                             range:NSMakeRange(0, [urlString length])];
    if (!firstMatch) {
        return nil; // not like URL
    }
    NSString *url = [urlString substringWithRange:[firstMatch rangeAtIndex:1]];
    return [NSURL URLWithString:url];
}

#pragma mark NSURLProtocol interface

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

/// static peek, called by iOS
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    BOOL isBundleRequest = [self isBundleResourceRequest:request];
    LogDebug(@"ProtocolHandlerChromeExt canInitWithRequest %@ %@",
        (isBundleRequest ? @"yes" : @"no"), request.URL.absoluteString);
    return isBundleRequest;
}

/// canInitWithRequest said YES, iOS will init us
/// a transparent implementation at the moment
- (id)initWithRequest:(NSURLRequest *)request
       cachedResponse:(NSCachedURLResponse *)cachedResponse
               client:(id<NSURLProtocolClient>)client
{
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    LogDebug(@"ProtocolHandlerChromeExt initWithRequest %@", request.URL.absoluteString);
    LogDebug(@"ProtocolHandlerChromeExt initWithRequest (%@)(%@)",
        cachedResponse.data ? @"no data" : [NSString stringWithFormat:@"data %ld", (long)[cachedResponse.data length]],
        cachedResponse.response ? @"no response" : [NSString stringWithFormat:@"response %lld %@",
                                                             cachedResponse.response.expectedContentLength,
                                                             cachedResponse.response.URL.absoluteString]);
    return self;
}

/// iOS calls this
- (void)startLoading
{
    NSURL *reqURL = [[self request] URL];
    LogDebug(@"ProtocolHandlerChromeExt startLoading %@", reqURL.absoluteString);
    // the URL wellformed-ness was ensured in canInitWithRequest, now use its parts
    NSString *resourcePath = reqURL.relativePath;
    NSString *extensionId = [[self class] extensionIdOfBundleResourceRequest:[self request]];
    NSData *data = [[WebRequestEventDispatcher sharedInstance] dataOfResource:resourcePath
                                                                  extensionId:extensionId];
    // Try to be helpful by providing sensible Content-Type with the fake response
    NSString *contentType = @"application/octet-stream"; // default
    for (NSString *mime in _suffixMimeMatches) {
        if ([resourcePath hasSuffix:_suffixMimeMatches[mime]]) {
            contentType = mime;
            break;
        }
    }
    NSHTTPURLResponse *response = [NSHTTPURLResponse uncacheableResponseWithURL:reqURL
                                                                    contentType:contentType
                                                                     statusCode:(data ? 200 : 404)];
    [[self client] URLProtocol:self
            didReceiveResponse:response
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (data) {
        [[self client] URLProtocol:self didLoadData:data];
    }
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
    // intentionally empty, no new connection is created
    // hence nothing to do on stop
    // But the method is pure virtual and must be defined
}
@end
