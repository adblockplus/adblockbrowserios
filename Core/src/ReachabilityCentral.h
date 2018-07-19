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
#import <KittCore/Reachability.h>

/**
 Reachability is expected to be queried for any outgoing request, from any
 protocol handler. In other words, very often. This singleton provides read only
 property updated from background, which does not add any execution on top of
 returning an already known value. Other option would be a notification
 broadcast to which all protocol handles would subscribe, but that means having
 to distribute the notifications even to protocol handler instances which are
 not processing any requests at the moment or even has the connection cancelled
 recently. Pull model seems to be more appropriate.
 
 The singleton was deliberately designed without sharedInstance accessor
 to keep things very simple to call.
 */
@interface ReachabilityCentral : NSObject

/**
 Reachability notifications are reportedly unreliable when instantiated from
 a background thread. So while this is a singleton and as such could be set up
 from +initialize, it will be most probably called when the reachability query
 is run for the first time, which would be in protocol handler worker thread.
 An explicit initializer is needed to control the point and thread of setup.
 */
+ (void)setUp;

+ (NetworkStatus)currentInternetReachabilityStatus;

@end
