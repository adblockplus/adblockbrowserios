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
 Custom protocol handler for outgoing request in bundle resource access scheme. It's
 the only class which "knows" the specific scheme string, so it provides
 some utility methods for detecting URL conformance.
*/
@interface ProtocolHandlerChromeExt : NSURLProtocol

/// @return created NSURL if the string conforms to 'chrome-extension://ExtensionId/relativepath' else returns nil.
+ (NSURL *)URLAsBundleResourceFromString:(NSString *)urlString;

@end
