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

#import "SAWebViewFaviconLoader.h"
#import "SAContentWebView.h"
#import "Settings.h"

#import <KittCore/KittCore-Swift.h>

static NSString *const FAVICON_DEFAULT_PATH = @"/favicon.ico";

static NSString *const ICON_LINK_REL_APPLE = @"apple-touch-icon";

static NSArray *_scenarioSelectors;
static dispatch_queue_t _loadingQueue;

@interface FaviconObject : NSObject <FaviconFacade>

@property (nonatomic, strong) NSString *iconUrl;
@property (nonatomic, strong) NSData *iconData;
@property (nonatomic, strong) NSNumber *size;

@end

@implementation FaviconObject

@end

@interface SAWebViewFaviconLoader () <NSURLConnectionDataDelegate> {
    NSUInteger _selectorNextIndex;
    FaviconGroup *_faviconGroup;
    NSURLRequest *_currentRequest;
    NSURL *_requestedFaviconURL;
    NSInteger _requestedFaviconSize;
}

@property (nonatomic, weak) id<FaviconLoadingDelegate> delegate;
@property (nonatomic, strong) BrowserHistoryManager *historyManager;
@end

@implementation SAWebViewFaviconLoader

+ (void)initialize
{
    _scenarioSelectors = @[ NSStringFromSelector(@selector(URLFaviconStringFromDOMOfServerURL:)),
        NSStringFromSelector(@selector(URLFaviconStringWithDefaultServerURL:)),
        NSStringFromSelector(@selector(URLFaviconStringWithModifiedServer:)) ];
    _loadingQueue = dispatch_queue_create("com.kitt.faviconloading", DISPATCH_QUEUE_SERIAL);
}

+ (dispatch_queue_t)loadingQueue
{
    return _loadingQueue;
}

- (BrowserHistoryManager *)historyManager
{
    return _historyManager;
}

- (instancetype)initWithDelegate:(id<FaviconLoadingDelegate>)delegate
                  historyManager:(BrowserHistoryManager *)historyManager
{
    if (self = [super init]) {
        _delegate = delegate;
        _historyManager = historyManager;
    }
    return self;
}

- (void)startFaviconLoadingFromURL:(NSURL *)currentFaviconURL
                          withSize:(NSUInteger)size
                   andFaviconGroup:(FaviconGroup *)faviconGroup
{
    if (faviconGroup.resolved) {
        return;
    }
    dispatch_suspend(_loadingQueue);
    _faviconGroup = faviconGroup;
    _currentRequest = faviconGroup.request;
    _requestedFaviconSize = size;
    _selectorNextIndex = 0;
    // doesn't need dispatch to main thread. Connection start is threadsafe and result callback
    // is queued on main thread anyway
    [self startConnectionWithURL:currentFaviconURL];
}

- (void)startFaviconLoadingWith:(NSURLRequest *)currentRequest
{
    _currentRequest = currentRequest;
    _requestedFaviconSize = 0;
    _selectorNextIndex = 0;
    [self connectionCompletedWithFaviconData:nil];
}

- (void)connectionCompletedWithFaviconData:(NSData *)data
{
    if (data) {
        if (_requestedFaviconSize == 0) {
            // no specific favicon size was requested, find out
            UIImage *iconImage = [UIImage imageWithData:data];
            if (!iconImage) {
                [_delegate setCurrentFavicon:nil];
                dispatch_resume(_loadingQueue);
                return;
            }
            _requestedFaviconSize = iconImage.size.width;
        }

        NSMutableArray<NSURL *> *urls = [NSMutableArray array];
        if (_currentRequest.URL) {
            [urls addObject:_currentRequest.URL];
        }
        if (_currentRequest.originalURL) {
            [urls addObject:_currentRequest.originalURL];
        }
        if (_historyManager && [urls count] > 0) {
            UrlIcon *icon = [_historyManager attach:data
                                        fromIconURL:_requestedFaviconURL
                                           withSize:_requestedFaviconSize
                                             toURLs:urls];
            _faviconGroup.favicon = icon;
            [_delegate setCurrentFavicon:icon];
        } else {
            FaviconObject *object = [[FaviconObject alloc] init];
            object.iconData = data;
            object.iconUrl = _requestedFaviconURL.absoluteString;
            object.size = [[NSNumber alloc] initWithInteger:_requestedFaviconSize];
            _faviconGroup.favicon = object;
            [_delegate setCurrentFavicon:object];
        }

        dispatch_resume(_loadingQueue);
    } else if (_selectorNextIndex == [_scenarioSelectors count]) {
        // all strategies failed
        [_delegate setCurrentFavicon:nil];
        dispatch_resume(_loadingQueue);
    } else {
        // continue with next
        SEL selector = NSSelectorFromString(_scenarioSelectors[_selectorNextIndex++]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *scenarioURLString = [self performSelector:selector withObject:_currentRequest.URL];
#pragma clang diagnostic pop
        if (scenarioURLString) {
            NSURL *scenarioURL = [NSURL URLWithString:scenarioURLString];
            [self startConnectionWithURL:scenarioURL];
        } else {
            [self connectionCompletedWithFaviconData:nil];
        }
    }
}

#pragma mark - Static

+ (NSString *)URLStringFromValidatedFaviconURL:(NSURL *)url withCurrentURL:(NSURL *)currentURL
{
    NSString *ret = url.absoluteString;
    if ([url.host length] == 0) {
        // URL without host, resolve against host and make absolute again
        url = [NSURL URLWithString:ret relativeToURL:currentURL];
        ret = url.absoluteString;
    } else if ([ret hasPrefix:@"//"]) {
        // Absolute URL (incl. hostname).
        // Icons can apparently be declared without 'protocol:'
        // http://stackoverflow.com/a/16844961
        ret = [NSString stringWithFormat:@"%@:%@",
                        url.scheme, ret];
    }
    return ret;
}

#pragma mark - Private

- (void)startConnectionWithURL:(NSURL *)url
{
    _requestedFaviconURL = url;
    NSMutableURLRequest *iconRequest = [NSMutableURLRequest requestWithURL:url];
    // all outgoing requests better have a valid UA
    [iconRequest setValue:[Settings defaultWebViewUserAgent] forHTTPHeaderField:@"User-Agent"];
    [NSURLConnection sendAsynchronousRequest:iconRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               // handler callbacks should be on main thread because we asked for it, but better check
                               NSAssert([NSThread isMainThread], @"NSURLConnection.sendAsynchronousRequest completion not queued on main thread");
                               if (connectionError) {
                                   [self connectionCompletedWithFaviconData:nil];
                                   return;
                               }
                               if ((response.expectedContentLength > 0L) && [response isKindOfClass:[NSHTTPURLResponse class]]) {
                                   NSHTTPURLResponse *iconResponse = (NSHTTPURLResponse *)response;
                                   NSString *contentType = [iconResponse allHeaderFields][@"Content-Type"];
                                   if ((iconResponse.statusCode == 200) &&
                                       // There are sites returning 200 with text/html. Ignore those
                                       ([contentType hasPrefix:@"image/"] ||
                                           // Slashdot be damned. Serving ico with text/plain mime is lunatic.
                                           [contentType hasPrefix:@"text/plain"])) {
                                       [self connectionCompletedWithFaviconData:data];
                                       return;
                                   }
                               }
                               [self connectionCompletedWithFaviconData:nil];
                           }];
}

@end
