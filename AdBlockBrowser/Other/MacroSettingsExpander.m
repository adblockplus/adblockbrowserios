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

#import "MacroSettingsExpander.h"
#import "AdblockBrowser-Swift.h"

@implementation MacroSettingsExpander

+ (NSString *) hockeyAppIdentifier {

    NSString *haId;

#ifdef DEBUG
    haId = [ABBAPIData hockeyAppIdDebug];
#elif DEVBUILD
    haId = [ABBAPIData hockeyAppIdDevBuild];
#elif RELEASE
    haId = [ABBAPIData hockeyAppIdRelease];
#endif

    BOOL isUnset = [haId isEqualToString:@""];
    return isUnset ? nil : haId;
}

+ (void) crash_BadAccess {
    int *x = NULL;
    *x = 42;
    // prevent compiler from possibly removing unused variable
    NSLog(@"%p",x);
}

+ (void) crash_Selector {
    NSObject *obj = [NSObject new];
    SEL nonexistentSelector = NSSelectorFromString(@"nonexistentFunction");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [obj performSelector:nonexistentSelector withObject:nil];
#pragma
}

+ (void)crash_ArrayOutOfBounds {
    id value = [@[@"A"] objectAtIndex:1];
    // prevent compiler from possibly removing unused variable
    NSLog(@"%@",value);
}

@end
