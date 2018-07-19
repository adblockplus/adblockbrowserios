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

@interface NSString (PatternMatching)

/// @return URL if the string looks like one and can be created from it
- (NSURL *)URLValue;

/// [NSURL URLWithString] misunderstands form "192.168.23.80[:8777]"
/// (that is a naked ip with optional port) as a scheme "192.168.23.80"
/// with resource "8777". UIWebView subsequently converts this to "file:" scheme,
/// yielding rejected request (one cannot get "local file" via browser on iOS).
/// As the iOS URL parser seems to be of no help, we must check the form ourselves
/// and prepend "http:" manually
- (NSString *)stringAsCorrectedNakedIpURL;

- (NSRegularExpression *)regexFromChromeGlobPattern:(NSString *)glob
                                       parsingError:(NSError **)error;

/// Handles URL string in any form, attempts to normalize it for NSURL acceptability
/// and in case of being just a path (absolute or relative), resolves it against baseURL.
/// @return nil if self is not an URL string in any recognizable form
- (NSURL *)asURLResolvedAgainst:(NSURL *)baseURL;

@end
