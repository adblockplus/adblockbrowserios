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

#import "NSURL+Conformance.h"
#import "ProtocolHandlerJSBridge.h"

@implementation NSURL (Conformance)

- (NSString *)conformantRefererString
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    // I don't think referer path should ever be nil, but such bug was reported
    if (!components.path) {
        components.path = @"/";
    }
    components.query = nil;
    components.fragment = nil;
    NSURL *conformantURL = components.URL;
    // if components failed for any reason, fall back to original self string
    return conformantURL ? conformantURL.absoluteString : self.absoluteString;
}

- (BOOL)isRFC2616EquivalentOf:(NSURL *)aURL
{

    if ([self isEqual:aURL]) {
        return YES; // sometimes Cocoa gets it right
    }
    if (![self isURLPart:@"scheme" withDefaultValue:nil equalToURL:aURL caseInsensitive:YES]) {
        return NO;
    }
    if (![self isURLPart:@"host" withDefaultValue:nil equalToURL:aURL caseInsensitive:YES]) {
        return NO;
    }
    if (![self isURLPart:@"user" withDefaultValue:nil equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    if (![self isURLPart:@"password" withDefaultValue:nil equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    // according to rfc2616, ports can weakly match if one is missing and the other is default for the scheme
    NSString *scheme = [((self.scheme == nil) ? aURL.scheme : self.scheme)lowercaseString];
    NSNumber *defaultPort = [@{ @"http" : @(80),
        @"https" : @(443),
        @"ftp" : @(21) } objectForKey:scheme];

    if (![self isURLPart:@"port" withDefaultValue:defaultPort equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    if (![self isURLPart:@"path" withDefaultValue:@"/" equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    if (![self isURLPart:@"query" withDefaultValue:nil equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    if (![self isURLPart:@"fragment" withDefaultValue:nil equalToURL:aURL caseInsensitive:NO]) {
        return NO;
    }
    return YES;
}

- (BOOL)isURLPart:(NSString *)key
    withDefaultValue:(id)defaultValue
          equalToURL:(NSURL *)url
     caseInsensitive:(BOOL)caseInsensitive
{
    id (^applyDefault)(NSURL *) = ^id(NSURL *url) {
        id retval = [url valueForKey:key];
        BOOL isEmpty = [retval isKindOfClass:[NSString class]] ? ([retval length] == 0) : (retval == nil);
        return isEmpty ? defaultValue : retval;
    };
    id part1 = applyDefault(self);
    BOOL isPart1Nil = (part1 == nil);
    id part2 = applyDefault(url);
    BOOL isPart2Nil = (part2 == nil);

    if (isPart1Nil != isPart2Nil) {
        // one is nil, other is not
        return NO;
    } else if (isPart1Nil) {
        // both are nil
        return YES;
    }
    return caseInsensitive ? ([part1 caseInsensitiveCompare:part2] == NSOrderedSame) : ([part1 compare:part2] == NSOrderedSame);
}

- (BOOL)shouldBeHidden
{
    NSString *selfString = self.absoluteString;
    return
        [selfString isEqualToString:@"about:blank"] ||
        [selfString isEqualToString:@""] ||
        [ProtocolHandlerJSBridge isBridgeRequestURL:self];
}

@end
