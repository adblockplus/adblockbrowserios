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

/**
Cocoa has annotated delegate/callback interfaces for Swift optionality typing and checks
them at compilation. But it does not verify the optionality at runtime, hence there are
cases of delegate calls where parameters are annotated as nonnull at ObjC side and represented
as nonoptional at Swift side, but still happen to be null.

One known location is NSURLConnectionDataDelegate.didReceiveResponse (response)

This proxy class replaces the original NSURLConnectionDataDelegate, takes the original as
parameter, checks the nilness in between, and does not forward if failed.
*/

#import <Foundation/Foundation.h>

@class ProtocolHandler;

@interface ConnectionDelegateSanitizer : NSObject <NSURLConnectionDataDelegate>

- (instancetype)initWithForwardHandler:(ProtocolHandler *)handler;

@end
