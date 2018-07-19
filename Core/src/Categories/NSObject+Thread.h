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

@interface NSObject (Thread)


 /// Performs the block on the specified thread in one of specified modes.
 /// @param thread The thread to target; nil implies the main thread.
 /// @param modes The modes to target; nil or an empty array gets you the default run loop mode.
 /// @param block The block to run.
- (void)performOnThread:(NSThread *)thread modes:(NSArray *)modes block:(dispatch_block_t)block;


/// A helper method used by -performOnThread:modes:block:. Runs in the specified context and simply calls the block.
/// @param block The block to run.
- (void)onThreadPerformBlock:(dispatch_block_t)block;

@end
