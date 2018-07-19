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

@interface NSArray (IterateAsyncSeries)

/*
 Asynchronous iteration of NSArray items.
 Loosely modeled after https://github.com/caolan/async#eachSeries
 iteratorBlock gets each NSArray item in series. When iteratorBlock is done with
 processing, it must call continueBlock(). Just returning from iteratorBlock does nothing.
 completionBlock() is called when all items are iterated.
 */
- (void)iterateSeriesWithBlock:(void (^)(id element, void (^continueBlock)(void)))iteratorBlock
               completionBlock:(void (^)(void))completionBlock;

@end
