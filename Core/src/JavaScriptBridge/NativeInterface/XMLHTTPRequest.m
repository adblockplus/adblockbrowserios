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

#import "XMLHTTPRequest.h"

#import "BridgeEnums.h"
#import "Utils.h"
#import "ProtocolHandlerChromeExt.h"
#import "NSJSONSerialization+NSString.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

/// When server response does not give expected content length
static const long long DEFAULT_LENGTH = 2048;

// Needs to implement NSURLConnectionDataDelegate to provide consistent
// handling of various HTTP request results

@interface XMLHTTPRequest () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSRegularExpression *rexEscapeSequence;
@property (nonatomic, strong) CommandHandlerExecutableCompletion completion;
@property (nonatomic, strong) NSHTTPURLResponse *currentResponse;
@property (nonatomic, strong) NSMutableData *currentData;

@end

@implementation XMLHTTPRequest

- (id)init
{
    if (self = [super init]) {
        // This was meant to remove the first backslash in any sequence of backslashes
        // But getting the value out of dictionary seems to remove it already. I'm confused
        // because now i don't know what was wrong with sending out strings previously.
        // So i will leave it here until it turns out to be really stable no matter what
        // the extension devs will be trying to send through XHR.
        NSError *error = NULL;
        _rexEscapeSequence = [NSRegularExpression regularExpressionWithPattern:@"\\\\(\\\\\\*)"
                                                                       options:0
                                                                         error:&error];
        if (error) {
            LogError(@"Error compiling rexEscapeSequence %@", [error localizedDescription]);
            _rexEscapeSequence = nil;
        }
    }
    return self;
}

- (void)sendParameters:(NSDictionary *)parameters
         fromExtension:(BrowserExtension *)extension
        withCompletion:(CommandHandlerExecutableCompletion)completion
{
    _completion = completion;
    // URL
    NSString *urlString = parameters[@"url"];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url.host) {
        // is a relative path, local bundle resource is being asked
        url = [ProtocolHandlerChromeExt URLforRequestResource:urlString
                                                  extensionId:extension.extensionId];
    }
    // Method
    NSString *method = parameters[@"method"];
    // Headers
    NSDictionary *headers = parameters[@"headers"];
    // Request to send
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    // Copy header to request
    [request setHTTPMethod:method];
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [request addValue:obj forHTTPHeaderField:key];
    }];
    // Append text body
    id incomingData = parameters[@"data"];
    if ([method isEqualToString:@"POST"] && incomingData) {
        NSData *httpBodyData;
        if (parameters[@"binary"]) {
            // if binary flag is set, we are sure that incomingData is a string
            httpBodyData = [[NSData alloc] initWithBase64EncodedString:incomingData options:0];
        } else {
            // if not binary, data may have been deserialized by JSONKit to various types
            NSString *stringData = nil;
            if ([incomingData isKindOfClass:[NSString class]]) {
                // is already a string, just typecast
                stringData = incomingData;
                // See comment at _rexEscapeSequence declaration above. Leaving the code here temporarily
                //      stringData = [_rexEscapeSequence stringByReplacingMatchesInString:stringData options:0 range:NSMakeRange(0, [stringData length]) withTemplate:@"$1"];
            } else {
                // What is expected here is a JSONifiable container, like NSArray or NSDictionary.
                // Try to get the string out again, to be able to detect and append the encoding
                // before setting http body
                NSError *jsonErr = nil;
                stringData = [NSJSONSerialization stringWithJSONObject:incomingData options:0 error:&jsonErr];
                if (jsonErr) {
                    _completion(nil, @{ @"error" : jsonErr.localizedDescription });
                    return;
                }
            }
            // Set default encoding for text
            NSStringEncoding stringEncoding = NSUTF8StringEncoding;
            NSString *header = headers[@"content-type"];
            // Is content header present?
            if (header) {
                // header is set, so encode string by requested encoding
                NSError *error = NULL;
                // Tries to get encoding from content-type string
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@";\\s*charset\\s*=\\s*([^;\\s]+)"
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:&error];
                NSTextCheckingResult *match = [regex firstMatchInString:header options:0 range:NSMakeRange(0, [header length])];
                if (match) {
                    NSRange range = [match rangeAtIndex:1];
                    NSString *encoding = [header substringWithRange:range];
                    CFStringEncoding cfStringEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)(encoding));
                    // Is encoding valid?
                    if (cfStringEncoding != kCFStringEncodingInvalidId) {
                        stringEncoding = CFStringConvertEncodingToNSStringEncoding(cfStringEncoding);
                    }
                }
            } else {
                // header is not set, append default content header
                [request addValue:@"text/plain; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
            }
            httpBodyData = [stringData dataUsingEncoding:stringEncoding];
        }
        [request setHTTPBody:httpBodyData];
    }
    // Set timeout
    int timeout = [parameters[@"timeout"] intValue];
    if (timeout != 0) {
        // Convert to seconds
        NSTimeInterval _timeout = timeout / 1000.0;
        [request setTimeoutInterval:_timeout];
    }
    // Send request
    [NSURLConnection connectionWithRequest:request delegate:self];
}

#pragma mark - NSULRConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        _currentResponse = (NSHTTPURLResponse *)response;
        long long expectedLength = [_currentResponse expectedContentLength];
        if (expectedLength <= 0L) {
            expectedLength = DEFAULT_LENGTH;
        }
        _currentData = [NSMutableData dataWithCapacity:(NSUInteger)expectedLength];
    } else {
        _currentResponse = nil;
        _currentData = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (_currentData) {
        [_currentData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _completion(nil, @{ @"error" : error.localizedDescription });
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
    if (_currentResponse) {
        NSString *responseData = nil;
        params[@"status"] = @(_currentResponse.statusCode);
        if (_currentResponse.allHeaderFields) {
            params[@"headers"] = _currentResponse.allHeaderFields;
        }
        if ([_currentData length] && (_currentResponse.statusCode == 200)) {
            CFStringEncoding cfStringEncoding = kCFStringEncodingInvalidId;
            NSString *encoding = [_currentResponse textEncodingName];
            if (encoding != nil) {
                cfStringEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)(encoding));
            }
            if (cfStringEncoding != kCFStringEncodingInvalidId) {
                NSStringEncoding stringEncoding = CFStringConvertEncodingToNSStringEncoding(cfStringEncoding);
                responseData = [[NSString alloc] initWithData:_currentData encoding:stringEncoding];
            } else {
                // Probably data
                params[@"binary"] = @(YES);
                responseData = [_currentData base64EncodedStringWithOptions:0];
            }
            params[@"data"] = responseData;
        }
    }

    _completion(nil, params);
}

@end
