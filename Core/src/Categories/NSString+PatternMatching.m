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

#import "NSString+PatternMatching.h"
#import <Foundation/NSRegularExpression.h>
#import "ObjCLogger.h"

@implementation NSString (PatternMatching)

/// Default scheme if the value is a valid URL but without scheme
static NSString *const kDefaultURLScheme = @"http";

static NSRegularExpression *_rexURL = nil;
static NSRegularExpression *_rexNakedIPAddress = nil;
static NSRegularExpression *_rexJSRegexPattern = nil;

- (NSURL *)URLValue
{
    if (!_rexURL) {
        NSError *err = nil;
        // https://gist.github.com/dperini/729294
        // Modified: make scheme prefix optional
        _rexURL = [NSRegularExpression
            regularExpressionWithPattern:@"^((http|https|ftp)\\://)?([a-zA-Z0-9\\.\\-]+(\\:[a-zA-Z0-9\\.&amp;%\\$\\-]+)*@)*((25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9])\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1]{1}[0-9]{2}|[1-9]{1}[0-9]{1}|[0-9])|localhost|([a-zA-Z0-9\\-]+\\.)*[a-zA-Z0-9\\-]+\\.([a-zA-Z]{2,10}))(\\:[0-9]+)*(/($|[a-zA-Z0-9\\.\\,\\?\\'\\\\\\+&amp;%\\$#\\=~_\\-\\@]+))*$"
                                 options:0
                                   error:&err];
        if (err) {
            LogError(@"Error compiling URL pattern: %@", [err description]);
            _rexURL = nil;
        }
    }
    // Adding the whitespace trimming in the regex would be simpler and more elegant but i was afraid of
    // breaking the regex because it has multiple optional expression end markers ($) which appear to
    // me even slightly wrongly duplicated. Dunno what adding multiple whitespace entities would do to it.
    NSString *trimmedSelf = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSTextCheckingResult *firstMatch = [_rexURL firstMatchInString:trimmedSelf
                                                           options:0
                                                             range:NSMakeRange(0, [trimmedSelf length])];
    if (!firstMatch) {
        return nil; // not like URL
    }
    NSString *urlString = [trimmedSelf substringWithRange:firstMatch.range];
    NSURL *url = [NSURL URLWithString:urlString];
    if (url && [url.scheme length] == 0) {
        /**
         When NSURL is created with a string _without_ scheme (just www.hostname.tld), a weird thing happens:
         it's a valid NSURL but both `scheme` and `host` are null. In such case, adding scheme with
         NSURLComponents is useless, because it will just prepend the resource specifier with the scheme:
         creates `scheme:www.hostname.tld` - not a valid URL either. Attempt to set
         NSURLComponents.scheme = @"scheme://" results in NSInvalidArgumentException "invalid characters in scheme".

         The only option left is a string prefix of `resourceSpecifier` which is the only NSURL property
         with a reasonable value when created with www.hostname.tld
         */
        urlString = [@"http://" stringByAppendingString:url.resourceSpecifier];
        url = [NSURL URLWithString:urlString];
    }
    return url;
}

- (NSString *)stringAsCorrectedNakedIpURL
{
    if (!_rexNakedIPAddress) {
        NSError *err = nil;
        _rexNakedIPAddress = [NSRegularExpression
            regularExpressionWithPattern:@"^\\s*([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}:[0-9]{2,5})\\s*$"
                                 options:0
                                   error:&err];
        if (err) {
            LogError(@"Error compiling naked IP address pattern: %@", [err description]);
            _rexNakedIPAddress = nil;
        }
    }
    NSTextCheckingResult *firstMatch = [_rexNakedIPAddress firstMatchInString:self
                                                                      options:0
                                                                        range:NSMakeRange(0, [self length])];
    if (!firstMatch) {
        // not a pattern we are looking for
        return self;
    }
    NSString *url = [self substringWithRange:[firstMatch rangeAtIndex:1]];
    return [NSString stringWithFormat:@"http://%@", url];
}

- (NSRegularExpression *)regexFromChromeGlobPattern:(NSString *)pattern
                                       parsingError:(NSError *__autoreleasing *)error
{
    // @todo deterministically follow the specification at
    // https://developer.chrome.com/extensions/match_patterns
    // instead of selective hacking
    pattern = [pattern stringByReplacingOccurrencesOfString:@"<all_urls>" withString:@"*"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"*" withString:@".*?"];
    pattern = [NSString stringWithFormat:@"^%@$", pattern];
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:NSRegularExpressionCaseInsensitive
                               error:error];
    return *error ? nil : regex;
}

- (NSURL *)asURLResolvedAgainst:(NSURL *)baseURL
{
    /*
     Guard against Unicode chars in the URL, NSURL(Components) doesn't understand them
     There is no way to know what characters are in a given NSCharacterSet
     (unless iterating entire unicode range)
     But we want to neutralize the query part, so that set should be a good start
     */
    NSMutableCharacterSet *charsNotToEscape = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    // Interestingly it does not contain percent, which is present if the query contains an already escaped URL
    // (a common practice of referral platforms and search engines)
    [charsNotToEscape addCharactersInString:@"%"];
    NSString *partiallyEscaped = [self stringByAddingPercentEncodingWithAllowedCharacters:charsNotToEscape];
    // Decompose and test the incoming URL string
    NSURLComponents *components = [NSURLComponents componentsWithString:partiallyEscaped];
    if (!components) {
        return nil;
    }
    // Preemptively protect against invalid tokens in the path, like dot references and double slashes
    // In which case NSURLComponents silently fails and renders nil NSURL
    NSString *standardizedPath = [components.path stringByStandardizingPath];
    components.path = standardizedPath;
    if (components.host) {
        // URL is fully qualified, return the components directly
        return components.URL;
    }
    // The URL is just a path, absolute or relative. Resolve against given base URL.
    NSURL *normalizedURL = [NSURL URLWithString:components.string relativeToURL:baseURL];
    return normalizedURL.absoluteURL;
}

@end
