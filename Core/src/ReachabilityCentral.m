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

#import "ReachabilityCentral.h"
#import "Reachability.h"
#import "ObjCLogger.h"

@interface ReachabilityCentral () {
    Reachability *_internetReachability;
}
@property (atomic) NetworkStatus internetReachabilityStatus;
@end

static ReachabilityCentral *_instance;

@implementation ReachabilityCentral

+ (void)setUp
{
    _instance = [ReachabilityCentral new];
}

+ (NetworkStatus)currentInternetReachabilityStatus
{
    return _instance.internetReachabilityStatus;
}

- (instancetype)init
{
    if (self = [super init]) {
        /**
         While this modernized ARC compatible Reachability provides callback blocks,
         it has separate blocks for change in connectivity and for disconnect. Which
         is unnecessarily complicated because we don't treat disconnect any differently.
         Let's use good old NSNotifications where all changes end up in one place.
         */
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        _internetReachability = [Reachability reachabilityForInternetConnection];
        [_internetReachability startNotifier];
        // Reachability produces notifications only on future changes.
        // Get the initial state now.
        [self reachabilityChanged:[NSNotification notificationWithName:kReachabilityChangedNotification
                                                                object:_internetReachability]];
    }
    return self;
}

- (void)dealloc
{
    [_internetReachability stopNotifier];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reachabilityChanged:(NSNotification *)note
{
    Reachability *r = [note object];
    NSParameterAssert([r isKindOfClass:[Reachability class]]); // copied from Apple example
    _internetReachabilityStatus = [r currentReachabilityStatus];
    LogInfo(@"Current reachability: %ld", (long)_internetReachabilityStatus);
}

@end
