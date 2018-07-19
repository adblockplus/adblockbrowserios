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

#import "NetworkActivityObserver.h"
#import "NetworkActivityFilter.h"
#import "DownloadProgressObserver.h"
#import "NSURL+Conformance.h"
#import "SAContentWebView.h"

#import <objc/runtime.h>

const NSTimeInterval ACTIVITY_TIMEOUT = 0.5;

/// Statistics object per NSURLConnection
@interface ConnectionTrafficCounterStruct : NSObject
/// originating tab id for the NSURLConnection
/// connection not bound to any tab (background XHR etc.) is represented as @(0)
@property (nonatomic, nonnull) NSNumber *tabId;
// data stats
@property (nonatomic) long long expectedLength;
@property (nonatomic) long long receivedLength;
@end

@implementation ConnectionTrafficCounterStruct
- (id)initWithTabId:(NSNumber *__nonnull)tabId
{
    self = [super init];
    if (self) {
        _tabId = tabId;
        _expectedLength = 0L;
        _receivedLength = 0L;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone
{
    ConnectionTrafficCounterStruct *copy = [[[self class] allocWithZone:zone]
        initWithTabId:_tabId];
    copy.expectedLength = _expectedLength;
    copy.receivedLength = _receivedLength;
    return copy;
}

@end

static NetworkActivityObserver *_instance;

@interface NetworkActivityObserver ()

/// NSURLProtocol instances are just counted at the moment for ocassional debugging.
/// Nothing more useful was requested yet
@property (atomic) NSInteger handlersCount;

/// NSURLConnection->ConnectionTrafficCounterStruct
@property (nonatomic, strong) NSLock *connectionsLock;
@property (nonatomic, strong) NSMapTable *connectionsCounters;

/// Writing concurrency on delegates is not an issue because register/unregister
/// is coming from UI thread only. But iteration is coming from URL loading
/// hence any number of threads may want to read.
@property (nonatomic, strong) NSLock *delegatesLock;
/// tabId->NetworkActivityDelegate
@property (nonatomic, strong) NSMutableDictionary *delegateForTabId;
/// tabId->NetworkActivityFilter
/// @todo make NetworkActivityFilter member of someone instead of this
/// redundant dictionary. Most practical would be NetworkActivityFilter, but
/// that would make SAContentWebView responsible for filtering its own
/// traffic, which i hesitate to see as a good idea. Needs more thinking.
@property (nonatomic, strong) NSMutableDictionary *filterForTabId;
/// The "singleton" filter for any activity across all tabs
@property (nonatomic, strong) NetworkActivityFilter *globalActivityFilter;
@end
// Global activity event properties

static NSString *kActivityKey = @"Activity";
static const char *ProgressbarInfo = "ProgressbarInfo";

@implementation NetworkActivityObserver

NSString *const kNetworkActivityNotification = @"NetworkActivityNotification";

#pragma mark - Static methods

+ (void)initialize
{
    _instance = nil;
}

+ (void)setSharedInstance:(NetworkActivityObserver *)instance
{
    _instance = instance;
}

+ (NetworkActivityObserver *)sharedInstance
{
    static dispatch_once_t pred;
    // semantical equivalent of synchronized block, without the locking
    // Will be run once and only once, at the first call
    dispatch_once(&pred, ^{
        // the condition normally won't be needed, but we got the
        // test-positive setSharedInstance
        if (!_instance) {
            _instance = [[NetworkActivityObserver alloc] init];
        }
    });
    return _instance;
}

+ (BOOL)activityStatusFromNotificationUserInfo:(NSDictionary *)userInfo
{
    return [[userInfo objectForKey:kActivityKey] boolValue];
}

#pragma mark - Instance methods

- (id)init
{
    self = [super init];
    if (self) {
        _handlersCount = 0;
        _connectionsLock = [NSLock new];
        _connectionsCounters = [NSMapTable strongToStrongObjectsMapTable];
        _delegatesLock = [NSLock new];
        _delegateForTabId = [NSMutableDictionary new];
        _filterForTabId = [NSMutableDictionary new];
        _globalActivityFilter =
            [[NetworkActivityFilter alloc] initWithInterval:ACTIVITY_TIMEOUT
                                               eventHandler:^(NSNumber *stateBool) {
                                                   [[NSNotificationCenter defaultCenter] postNotificationName:kNetworkActivityNotification
                                                                                                       object:self
                                                                                                     userInfo:@{ kActivityKey : stateBool }];
                                               }];
        [[NSNotificationCenter defaultCenter] addObserverForName:kContentWebViewFinishedLoadingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self tryTocompleteProcessOfWebView:note.object];
                                                      }];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onProtocolHandlerInstantiated
{
    _handlersCount++;
}

- (void)onProtocolHandlerDeallocated
{
    _handlersCount--;
}

- (void)registerActivityDelegate:(id<NetworkActivityDelegate>)delegate forTabId:(NSUInteger)tabId
{
    @synchronized(_delegatesLock)
    {
        [_delegateForTabId setObject:delegate forKey:@(tabId)];
        __weak __typeof(delegate) wDelegate = delegate;
        [_filterForTabId setObject:[[NetworkActivityFilter alloc] initWithInterval:ACTIVITY_TIMEOUT
                                                                      eventHandler:^(NSNumber *stateBool) {
                                                                          [wDelegate onNetworkActivityState:[stateBool boolValue]];
                                                                      }]
                            forKey:@(tabId)];
    }
}

- (void)unregisterActivityDelegateForTabId:(NSUInteger)tabId
{
    @synchronized(_delegatesLock)
    {
        [_delegateForTabId removeObjectForKey:@(tabId)];
        [_filterForTabId removeObjectForKey:@(tabId)];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)registerNewConnection:(NSURLConnection *)connection forTabId:(NSNumber *)tabId
{
    bool wasNoActivity = NO;
    NSNumber *__nonnull safeTabId = tabId ? tabId : @(0);
    ConnectionTrafficCounterStruct *counter = [[ConnectionTrafficCounterStruct alloc] initWithTabId:safeTabId];
    @synchronized(_connectionsLock)
    {
        wasNoActivity = ([_connectionsCounters count] == 0);
        [_connectionsCounters setObject:counter forKey:connection];
    }
    if (wasNoActivity) {
        [_globalActivityFilter filterTransitionToState:@(YES)];
    }
    [self onActivityOfTabId:counter.tabId];

// -----

#ifdef DOWNLOAD_PROGRESS_COUNT_CONNECTIONS
    id<NetworkActivityDelegate> delegate = _delegateForTabId[counter.tabId];
    DownloadProgressObserver *progress = nil;
    if (delegate && (progress = objc_getAssociatedObject(delegate, ProgressbarInfo))) {

        if ([progress.topLevelNavigationURL isEqual:[connection.currentRequest mainDocumentURL]]) {
            @synchronized(progress)
            {
                [progress incrementMaxLoadCount];
                [delegate onNetworkLoadingProgress:progress.currentProgress];
            }
        }
    }
#endif
}

- (void)connection:(NSURLConnection *)connection receivedResponseWithExpectedLength:(long long)length
{
    ConnectionTrafficCounterStruct *counter = nil;
    @synchronized(_connectionsLock)
    {
        counter = [_connectionsCounters objectForKey:connection];
        counter.expectedLength = length;
        counter = [counter copy];
    }
    [self onActivityOfTabId:counter.tabId];

// -----

#ifdef DOWNLOAD_PROGRESS_COUNT_BYTES
    id<NetworkActivityDelegate> delegate = _delegateForTabId[counter.tabId];
    DownloadProgressObserver *progress = nil;
    if (delegate && (progress = objc_getAssociatedObject(delegate, ProgressbarInfo))) {

        if ([progress.topLevelNavigationURL isEqual:[connection.currentRequest mainDocumentURL]]) {

            // If expected length is not unknown, we update expected byte count right here.
            if (length != NSURLResponseUnknownLength) {
                @synchronized(progress)
                {
                    [progress incrementExpectedByteCount:length];
                    [delegate onNetworkLoadingProgress:progress.currentProgress];
                }
            }
        }
    }
#endif
}

- (void)connection:(NSURLConnection *)connection receivedDataLength:(NSUInteger)length
{
    ConnectionTrafficCounterStruct *counter = nil;
    @synchronized(_connectionsLock)
    {
        counter = [_connectionsCounters objectForKey:connection];
        counter.receivedLength += length;
        counter = [counter copy];
    }
    [self onActivityOfTabId:counter.tabId];

// -----

#ifdef DOWNLOAD_PROGRESS_COUNT_BYTES
    id<NetworkActivityDelegate> delegate = _delegateForTabId[counter.tabId];
    DownloadProgressObserver *progress = nil;
    if (delegate && (progress = objc_getAssociatedObject(delegate, ProgressbarInfo))) {

        if ([progress.topLevelNavigationURL isEqual:[connection.currentRequest mainDocumentURL]]) {

            // If expected length was unknown, we are periodically updating expected byte count.
            if (counter.expectedLength == NSURLResponseUnknownLength) {
                @synchronized(progress)
                {
                    [progress incrementExpectedByteCount:length];
                    [delegate onNetworkLoadingProgress:progress.currentProgress];
                }
            }
        }
    }
#endif
}

- (void)unregisterConnection:(NSURLConnection *)connection
{
    NSAssert(connection, @"Need connection to unregister");
    bool isActivityEnded = NO;
    NSNumber *tabId;
    ConnectionTrafficCounterStruct *counter = nil;
    @synchronized(_connectionsLock)
    {
        counter = [_connectionsCounters objectForKey:connection];
        tabId = counter.tabId;
        [_connectionsCounters removeObjectForKey:connection];
        isActivityEnded = ([_connectionsCounters count] == 0);
        counter = [counter copy];
    }
    if (isActivityEnded) {
        [_globalActivityFilter filterTransitionToState:@(NO)];
    }
    if (tabId) {
        [self onActivityOfTabId:tabId];
    }

    // -----

    id<NetworkActivityDelegate> delegate = _delegateForTabId[counter.tabId];
    DownloadProgressObserver *progress = nil;
    if (delegate && (progress = objc_getAssociatedObject(delegate, ProgressbarInfo))) {

        if ([progress.topLevelNavigationURL isEqual:[connection.currentRequest mainDocumentURL]]) {

            @synchronized(progress)
            {
#ifdef DOWNLOAD_PROGRESS_COUNT_BYTES
                // We count received bytes here, because we do not want to move progress bar to ahead.
                if (counter.expectedLength == NSURLResponseUnknownLength) {
                    [progress incrementReceivedByteCount:counter.receivedLength];
                } else {
                    // Not really necessary to known exact number of bytes, which we received.
                    // But we have already promised, that we will receive counter.expectedLength bytes.
                    [progress incrementReceivedByteCount:counter.expectedLength];
                }
#endif

#ifdef DOWNLOAD_PROGRESS_COUNT_CONNECTIONS
                [progress incrementLoadingCount];
#endif

                [delegate onNetworkLoadingProgress:progress.currentProgress];
            }
        }
    }
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)sender shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSAssert([sender isKindOfClass:[SAContentWebView class]], @"NetworkActivityObserver shouldStartLoadWithRequest not with SAContentWebView");
    // It would be naturally expected that sender.request holds the "previous URL",
    // hence being a comparison source. Unfortunately, UIWebView has its own idea of
    // assignment timing and sender.request very often reports an even older URL
    // even if didStartLoad was already called with the "last previous URL".
    // Safer approach is to ask our override for what it registers as the last known URL.
    SAContentWebView *senderContentWebView = (SAContentWebView *)sender;
    NSURL *nonFragmentURL = nil;
    if (request.URL.fragment) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
        components.fragment = nil;
        nonFragmentURL = components.URL;

        if ([nonFragmentURL isRFC2616EquivalentOf:senderContentWebView.currentURL]) {
            // fragment jump, no change in progress
            return YES;
        };
    }
    BOOL isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];

    BOOL isHTTP = NO;
    isHTTP |= [[request.URL.scheme lowercaseString] isEqualToString:@"http"];
    isHTTP |= [[request.URL.scheme lowercaseString] isEqualToString:@"https"];

    if (isHTTP && isTopLevelNavigation && [sender conformsToProtocol:@protocol(NetworkActivityDelegate)]) {
        // Create associated object
        DownloadProgressObserver *progress = objc_getAssociatedObject(sender, ProgressbarInfo);

        if (!progress) {
            progress = [[DownloadProgressObserver alloc] init];
            objc_setAssociatedObject(sender, ProgressbarInfo, progress, OBJC_ASSOCIATION_RETAIN);
        }

        @synchronized(progress)
        {
            [progress reset];
            [progress startProgressWithURL:request.mainDocumentURL];
        }
    }

    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)sender
{
    [self tryTocompleteProcessOfWebView:sender];
}

- (void)webView:(UIWebView *)sender didFailLoadWithError:(NSError *)error
{
    switch ([error code]) {
    // We do not know, what to do with those special types of error
    // So I am suggesting to cancel progress bar loading.
    case kCFURLErrorNotConnectedToInternet:
    case kCFURLErrorNetworkConnectionLost: {
        DownloadProgressObserver *progress = nil;
        if ((progress = objc_getAssociatedObject(sender, ProgressbarInfo))) {
            id<NetworkActivityDelegate> delegate = (id<NetworkActivityDelegate>)sender;
            @synchronized(progress)
            {
                [progress reset];
                [delegate onNetworkLoadingProgress:progress.currentProgress];
            }
        }
    } break;
    default:
        [self tryTocompleteProcessOfWebView:sender];
        break;
    }
}

- (void)tryTocompleteProcessOfWebView:(UIWebView *)sender
{
    DownloadProgressObserver *progress = nil;
    if ((progress = objc_getAssociatedObject(sender, ProgressbarInfo))) {
        id<NetworkActivityDelegate> delegate = (id<NetworkActivityDelegate>)sender;

        NSString *readyState;
        if ([sender isKindOfClass:[SAContentWebView class]]) {
            readyState = [(id)sender readyState];
        } else {
            readyState = [sender stringByEvaluatingJavaScriptFromString:@"document.readyState"];
        }

        BOOL isNotRedirect = [progress.topLevelNavigationURL isEqual:sender.request.mainDocumentURL];
        BOOL complete = [readyState isEqualToString:@"complete"];
        if (complete && isNotRedirect) {
            // Stop progress updating
            @synchronized(progress)
            {
                [progress completeProgress];
                [delegate onNetworkLoadingProgress:progress.currentProgress];
            }
        }
    }
}

- (void)onReadyStateDidChanged:(SAContentWebView *)sender
{
    [self tryTocompleteProcessOfWebView:sender];
}

- (void)onActivityOfTabId:(NSNumber *__nonnull)tabId
{
    id<NetworkActivityDelegate> tabDelegate = nil;
    NetworkActivityFilter *filter = nil;
    @synchronized(_delegatesLock)
    {
        tabDelegate = [_delegateForTabId objectForKey:tabId];
        filter = [_filterForTabId objectForKey:tabId];
    }
    if (!tabDelegate) {
        return;
    }
    // make copies of all connections counters of the relevant tab id
    NSMutableArray *countersForTabId = [NSMutableArray new];
    @synchronized(_connectionsLock)
    {
        for (ConnectionTrafficCounterStruct *counter in [_connectionsCounters objectEnumerator]) {
            if ([counter.tabId isEqualToNumber:tabId]) {
                [countersForTabId addObject:[counter copy]];
            }
        }
    }

    if ([tabDelegate respondsToSelector:@selector(onNetworkActivityState:)]) {
        [filter filterTransitionToState:@([countersForTabId count] > 0)];
    }
}

@end
