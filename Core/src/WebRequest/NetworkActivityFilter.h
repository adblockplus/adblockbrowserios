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
 @discussion
 Event filter for numerical transitions (primarily booleans). Makes sure that
 each transition lives at least for the given interval. Faster transitions are
 merged and postponed to after the interval.
 
 Rationale: the resource loading traffic for a single UIWebView (as observed by
 NSURLProtocol) was found to be quite erratic, depending on the particular page
 being loaded. There are bursts of dozens of concurrent connections, followed by
 intervals of just one or two connections, and sometimes even interleaved with
 brief intervals of no open connections at all, when WebKit most probably digests
 what's already loaded and planning next requests. Represented as immediate visual
 feedback, it's as pleasant as a worn-out fluorescent tube. This class is a
 kind of low pass filter and "evens out" the fast transitions.

 @todo generalize for any type of events
 */

#import <Foundation/Foundation.h>

/**
 The final event handler block declaration
 @param NSNumber the event state
 */
typedef void (^ActivityEventHandler)(NSNumber *);

@interface NetworkActivityFilter : NSObject

/**
 @param interval the filtering timeout
 @param handler event handler block
 */
- (id)initWithInterval:(NSTimeInterval)interval eventHandler:(ActivityEventHandler)handler;
/**
 @param state the momentary state to filter
 */
- (void)filterTransitionToState:(NSNumber *)state;

@end
