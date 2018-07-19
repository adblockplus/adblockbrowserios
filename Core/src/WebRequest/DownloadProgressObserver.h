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

#define DOWNLOAD_PROGRESS_COUNT_BYTES 1
#define DOWNLOAD_PROGRESS_COUNT_CONNECTIONS 1

#import <Foundation/Foundation.h>

/**
 This class is attached to instance of NetworkActivityDelegate,
 when new navigation request start. It holds a status of the current progress.
 */
@interface DownloadProgressObserver : NSObject

/// Actual progress, which should be observed
@property (readonly) CGFloat currentProgress;

/// This property should point to mainDocumentURL of current request
@property (atomic, strong) NSURL *topLevelNavigationURL;

- (void)incrementLoadingCount;
- (void)incrementMaxLoadCount;

- (void)incrementReceivedByteCount:(long long)bytes;
- (void)incrementExpectedByteCount:(long long)bytes;

- (void)startProgressWithURL:(NSURL *)url;
- (void)completeProgress;
- (void)reset;

- (BOOL)isLoading;

@end
