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

#import "NSArray+IterateAsyncSeries.h"

@implementation NSArray (IterateAsyncSeries)

typedef void (^ApplySingleElementBlock)(NSUInteger);

// I don't thoroughly understand the following pattern but it was the only way
// to avoid 'retain cycle' warnings or null pointer crashes inside the dispatch_async
// when i implemented recursive calling of the declared block right away.
// https://gist.github.com/mikeash/1254684/838daff38fc211c3726ce7d0faafd1f679828954
// (gist was seriously fixed to be even compilable)

ApplySingleElementBlock ApplyElementRecursive(void (^block)(ApplySingleElementBlock recurse, NSUInteger index))
{
    return ^(NSUInteger index) {
        block(ApplyElementRecursive(block), index);
    };
}

- (void)iterateSeriesWithBlock:(void (^)(id element, void (^continueBlock)(void)))iteratorBlock
               completionBlock:(void (^)(void))completionBlock
{
    ApplySingleElementBlock block = ApplyElementRecursive(^(ApplySingleElementBlock recurse, NSUInteger index) {
        if (index >= [self count]) {
            // all rules passed, call back
            completionBlock();
            return;
        }
        iteratorBlock(self[index], ^{
            // it works without dispatch as well but the whole iteration is then
            // serialized into one call stack
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                recurse(index + 1);
            });
        });
    });
    block(0);
}

@end
