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

#import "ProtocolHandlerJSBridge.h"
#import "Settings.h"
#import "NSHTTPURLResponse+Uncacheable.h"

#import <KittCore/KittCore-Swift.h>

@interface ProtocolHandlerJSBridge () <NSURLConnectionDelegate>
/// handler forges a new connection, needs to remember it
/// in order to be able to cancel it later (if iOS asks so)
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation ProtocolHandlerJSBridge

/// mapping of meta-protocol resources to "hostnames"
/// which will be encoded in the request
static NSDictionary *_bridgeRequestHosts;

+ (BOOL)isBridgeRequestURL:(NSURL *)url
{
    return [[Settings bridgeScheme] isEqualToString:url.scheme];
}

+ (BOOL)isVirtualResourceBridgeRequestURL:(NSURL *)url
{
    return [self isBridgeRequestURL:url] && ([[_bridgeRequestHosts allKeysForObject:url.host] count] != 0);
}

+ (NSURL *)URLWithBridgeResource:(JSBridgeResource)resource path:(NSString *)path
{
    // make absolute path
    if (!path) {
        path = @"/";
    } else if (![path hasPrefix:@"/"]) {
        path = [NSString stringWithFormat:@"/%@", path];
    }
    return [[NSURL alloc] initWithScheme:[Settings bridgeScheme]
                                    host:_bridgeRequestHosts[@(resource)]
                                    path:path];
}

+ (void)initialize
{
    _bridgeRequestHosts = @{
        @(JSBridgeResource_EmptyPage) : @"ContentWebViewEmptyPage",
        @(JSBridgeResource_UsefulPage) : @"ContentWebViewUsefulPage"
    };
}

#pragma mark NSURLProtocol interface

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

/// static peek, called by iOS
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return !request.passedProtocolHandler &&
        [self isBridgeRequestURL:request.URL];
}

- (void)startLoading
{
    NSURL *reqURL = [[self request] URL];
    if (
        [reqURL.host isEqualToString:_bridgeRequestHosts[@(JSBridgeResource_EmptyPage)]]) {
        NSHTTPURLResponse *response = [NSHTTPURLResponse uncacheableResponseWithURL:reqURL
                                                                        contentType:@"text/plain" // irrelevant
                                                                         statusCode:200];
        [[self client] URLProtocol:self
                didReceiveResponse:response
                cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocolDidFinishLoading:self];
        return;
    }
    NSMutableURLRequest *finalRequest = [[self request] mutableCopy];
    [finalRequest setPassedProtocolHandler:YES];
    NSString *finalURLStr = [NSString stringWithFormat:@"%@:%@",
                                      [Settings extensionServerScheme],
                                      finalRequest.URL.resourceSpecifier];
    [finalRequest setURL:[NSURL URLWithString:finalURLStr]];
    _connection = [NSURLConnection connectionWithRequest:finalRequest
                                                delegate:self];
}

- (void)stopLoading
{
    [_connection cancel];
}

#pragma mark NSURLConnectionDelegate

/// transparent implementation, simple pass-through of events from
/// NSURLConnectionDelegate to NSURLProtocolClient
- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response
{
    if (response == nil) {
        return request;
    }
    NSMutableURLRequest *redirectableRequest = [request mutableCopy];
    [redirectableRequest setPassedProtocolHandler:NO];
    [[self client] URLProtocol:self
        wasRedirectedToRequest:redirectableRequest
              redirectResponse:response];
    return redirectableRequest;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[self client] URLProtocol:self didFailWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [[self client] URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

@end
