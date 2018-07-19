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

#import "NetworkActivityFilter.h"

@interface NetworkActivityFilter ()

@property (nonatomic, readonly) NSTimeInterval FILTER_INTERVAL;
@property (nonatomic, readonly) ActivityEventHandler eventHandler;
@property (atomic) NSNumber *lastStateTransition;
@property (atomic) NSDate *lastHandlerCallStamp;

@end

@implementation NetworkActivityFilter

- (id)initWithInterval:(NSTimeInterval)interval
          eventHandler:(ActivityEventHandler)handler
{
    self = [super init];
    if (self) {
        _FILTER_INTERVAL = interval;
        _eventHandler = handler;
        _lastStateTransition = nil;
        _lastHandlerCallStamp = nil;
    }
    return self;
}

- (void)filterTransitionToState:(NSNumber *)state
{
    // The calls may be coming from multiple resource loading threads, serialize
    dispatch_async(dispatch_get_main_queue(), ^{
        // Already queued calls to this event handler are obsoleted by this new call
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        NSDate *now = [NSDate date];
        // if this is the first call, preset the diff at threshold interval
        // to trigger the event
        NSTimeInterval diffSince = self->_lastHandlerCallStamp ? [now timeIntervalSinceDate:self->_lastHandlerCallStamp] : self->_FILTER_INTERVAL;
        if (state) {
            // exchange only if called with valid state, as opposite to nil (see below)
            self->_lastStateTransition = state;
        }
        // ease out fast transitions
        if (diffSince >= self->_FILTER_INTERVAL) {
            // last transition is running for at least the timeout
            // post the current state
            self->_lastHandlerCallStamp = now;
            self->_eventHandler(self->_lastStateTransition);
        } else if (state) {
            // Called with valid state but too early after the last transition,
            // requeue with nil parameter as a reminder to try again with what
            // will be the last transition state at that moment
            NSTimeInterval diffLeft = self->_FILTER_INTERVAL - diffSince;
            [self performSelector:_cmd withObject:nil afterDelay:diffLeft];
        }
    });
}

@end
