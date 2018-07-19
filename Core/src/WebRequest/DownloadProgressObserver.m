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

#import "DownloadProgressObserver.h"
#import "ObjCLogger.h"

@interface DownloadProgressObserver () {
    /// Basically, current value of progress is updated with delay after
    /// Final value of progress is desired value to which current is heading to.
    /// The main idea is that same connection are delayed, and this approach hides this delay.
    float _currentProgress1, _currentProgress2;
    float _finalProgress1, _finalProgress2;
    /// It may happen that document.readyState reports being "complete" but loading of
    /// resources continues. In such case, the progress is briefly set to 100% and then
    /// slides back to incrementing. If the progress was already "completed" for one
    /// loading, incrementing must be hidden.
    BOOL _isCompleteForced;
}

/// Time of list update of progress
@property (nonatomic) NSTimeInterval lastUpdate;

/// Number of currently closed connections
@property (nonatomic) NSUInteger loadingCount;
/// Number of all connections
@property (nonatomic) NSUInteger maxLoadCount;

/// Currently received bytes
@property (nonatomic) long long receivedByteCount;
/// Currently expected bytes
@property (nonatomic) long long expectedByteCount;

@end

@implementation DownloadProgressObserver

/// Initial download value
const static float InitialProgressValue = 0.05f;

- (instancetype)init
{
    if (self = [super init]) {
        _lastUpdate = [[NSProcessInfo processInfo] systemUptime];
        _isCompleteForced = NO;
    }
    return self;
}

- (void)startProgressWithURL:(NSURL *)url;
{
    self.topLevelNavigationURL = url;
    if (_finalProgress1 < InitialProgressValue && _finalProgress2 < InitialProgressValue) {
        _currentProgress1 = _finalProgress1 = InitialProgressValue;
        _currentProgress2 = _finalProgress2 = InitialProgressValue;
    }
}

- (CGFloat)currentProgress
{
    if (_isCompleteForced) {
        return 1.0;
    } else {
#if defined(DOWNLOAD_PROGRESS_COUNT_BYTES) && defined(DOWNLOAD_PROGRESS_COUNT_CONNECTIONS)
        return (_currentProgress1 + _currentProgress2) / 2;
#elif defined(DOWNLOAD_PROGRESS_COUNT_BYTES)
        return _currentProgress2;
#else
        return _currentProgress1;
#endif
    }
}

- (void)updateFinalProgress
{
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];

    /// Time elapsed from last update.
    NSTimeInterval diff = now - _lastUpdate;

    // Update progress of closed connections (linear interpolation)
    _currentProgress1 = MAX(MIN(_finalProgress1, _currentProgress1 + (_finalProgress1 - _currentProgress1) * diff), _currentProgress1);

    // Update progress of received bytes
    _currentProgress2 = MAX(MIN(_finalProgress2, _currentProgress2 + (_finalProgress2 - _currentProgress2) * diff), _currentProgress2);

#if defined(DOWNLOAD_PROGRESS_COUNT_BYTES) && defined(DOWNLOAD_PROGRESS_COUNT_CONNECTIONS)
    // This piece of code will slow down prograss update
    _currentProgress1 = MIN(_currentProgress1, _currentProgress2);
    _currentProgress2 = MIN(_currentProgress1, _currentProgress2);
#endif

    _lastUpdate = now;

    // Debug message, not used now
    LogDebug(@"%f %f %f %ld %ld %lld %lld",
        _currentProgress1 + _currentProgress2, _finalProgress1 + _finalProgress2, diff,
        (long)_loadingCount, (long)_maxLoadCount, _receivedByteCount, _expectedByteCount);
}

- (void)incrementLoadingCount
{
    [self updateFinalProgress];
    _loadingCount++;
    // This should not have happened, but it is happening.
    // There were severals bugs in crushlytics, which was caused by NaN value of progress.
    // I was not able to reproduce that scenario, but only place where it may happened
    // is here.
    if (_maxLoadCount <= 0) {
        return;
    }
    _finalProgress1 = MAX(_currentProgress1, (float)_loadingCount / (float)_maxLoadCount);
}

- (void)incrementMaxLoadCount
{
    [self updateFinalProgress];
    _maxLoadCount++;
    _finalProgress1 = MAX(_currentProgress1, (float)_loadingCount / (float)_maxLoadCount);
}

- (void)incrementReceivedByteCount:(long long)bytes
{
    [self updateFinalProgress];
    _receivedByteCount += bytes;
    if (_expectedByteCount <= 0) {
        return;
    }
    _finalProgress2 = MAX(_currentProgress2, (float)_receivedByteCount / (float)_expectedByteCount);
}

- (void)incrementExpectedByteCount:(long long)bytes
{
    [self updateFinalProgress];
    _expectedByteCount += bytes;
    _finalProgress2 = MAX(_currentProgress2, (float)_receivedByteCount / (float)_expectedByteCount);
}

- (void)completeProgress
{
    _isCompleteForced = YES;
    _topLevelNavigationURL = nil;
    _currentProgress1 = _finalProgress1 = 1.0;
    _currentProgress2 = _finalProgress2 = 1.0;
}

- (void)reset
{
    _isCompleteForced = NO;
    _topLevelNavigationURL = nil;
    _finalProgress1 = _currentProgress1 = 0.0f;
    _finalProgress2 = _currentProgress2 = 0.0f;
    _loadingCount = _maxLoadCount = 0;
    _expectedByteCount = _receivedByteCount = 0;
}

- (BOOL)isLoading
{
    return _topLevelNavigationURL != nil;
}

@end
