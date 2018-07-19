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

#import "WebRequestEventDispatcher.h"
#import "RequestRule.h"
#import "NSArray+IterateAsyncSeries.h"
#import "NSURL+Conformance.h"

#import <KittCore/KittCore-Swift.h>

static NSTimeInterval blockingRoundtripMax = -DBL_MAX;
static NSTimeInterval blockingRoundtripMin = DBL_MAX;
static NSTimeInterval blockingRoundtripTotal = 0.0;
static NSUInteger blockingRoundtripCount = 0;

static WebRequestEventDispatcher *_instance;

@interface WebRequestEventDispatcher ()
@property (nonatomic, strong) NSMutableArray<RequestRule *> *requestRules;
/// registered extensions, for bundle resource access
@property (nonatomic, strong) NSMutableDictionary *extensions;
@end

@implementation WebRequestEventDispatcher

+ (void)initialize
{
    _instance = nil;
}

+ (void)setSharedInstance:(WebRequestEventDispatcher *)instance
{
    _instance = instance;
}

+ (WebRequestEventDispatcher *)sharedInstance
{
    static dispatch_once_t pred;
    // semantical equivalent of synchronized block, without the locking
    // Will be run once and only once, at the first call
    dispatch_once(&pred, ^{
        // the condition normally won't be needed, but we got the
        // test-positive setSharedInstance
        if (!_instance) {
            _instance = [[WebRequestEventDispatcher alloc] init];
        }
    });
    return _instance;
}

- (id)init
{
    if (self = [super init]) {
        _requestRules = [NSMutableArray new];
        _extensions = [NSMutableDictionary new];
        return self;
    }
    return nil;
}

- (void)addRequestRule:(RequestRule *)rule
{
    /// being called from main thread through CommandDispatcher webRequest.removeListener
    @synchronized(_requestRules)
    {
        [_requestRules addObject:rule];
    }
}

- (void)removeRequestRuleForCallbackId:(NSString *)callbackId
{
    // being called from main thread through CommandDispatcher webRequest.addListener
    @synchronized(_requestRules)
    {
        NSUInteger idx = [_requestRules indexOfObjectPassingTest:^BOOL(RequestRule *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            return [obj containsActionWithCallbackId:callbackId];
        }];
        if (idx != NSNotFound) {
            [_requestRules removeObjectAtIndex:idx];
        }
    }
}

- (NSData *)dataOfResource:(NSString *)resource extensionId:(NSString *)extensionId
{
    BrowserExtension *extension = [_extensions objectForKey:extensionId];
    if (!extension) {
        return nil;
    }
    NSError *errorLocal = nil;
    NSData *ret = [extension dataForBundleResource:resource error:&errorLocal];
    return errorLocal ? nil : ret;
}

- (SessionManager *)sessionManagerForWebViewWithTabId:(NSUInteger)tabId
{
    SAContentWebView *webView = [Chrome.sharedInstance findContentWebView:tabId];
    return webView.chromeTab.sessionManager;
}

- (void)removeRequestRulesForExtension:(BrowserExtension *)extension
{
    @synchronized(_requestRules)
    {
        [_requestRules filterUsingPredicate:
                           [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                               RequestRule *rule = (RequestRule *)obj;
                               // predicate is FALSE -> element is REMOVED (hence negation)
                               return ![rule.originExtension isEqual:extension];
                           }]];
    }
}

- (void)applyRulesOnDetails:(WebRequestDetails *)details
          modifyingResponse:(BlockingResponse *)response
                finishBlock:(ResponseBlock)finishBlock
{
    // make a threadsafe snapshot of the current delegates list, so that
    // the request is matched against consistent state
    // being called from NSURLProtocol worker threads
    NSArray *rulesCopy = nil;
    @synchronized(_requestRules)
    {
        rulesCopy = [NSArray arrayWithArray:_requestRules];
    }
    rulesCopy = [rulesCopy filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id _Nonnull evaluatedObject, NSDictionary<NSString *, id> *_Nullable bindings) {
        return [evaluatedObject matchesDetails:details];
    }]];
    __block NSTimeInterval stamp = [NSDate timeIntervalSinceReferenceDate];
    [rulesCopy iterateSeriesWithBlock:^(id element, void (^continueBlock)(void)) {
        RequestRule *rule = (RequestRule *)element;
        [rule applyToResponse:response
                  withDetails:details
              completionBlock:^{
                  continueBlock();
              }];
    }
        completionBlock:^{
            // all rules passed, return
            [self logBlockingRoundtripOfDetails:details withStartTime:stamp];
            finishBlock(response);
        }];
}

#pragma mark ExtensionModeEventDelegate

- (void)onModelExtensionAdded:(BrowserExtension *)extension
{
    [_extensions setObject:extension forKey:extension.extensionId];
}

- (void)onModelExtensionChanged:(BrowserExtension *)extension
{
    if (extension.enabled) {
        [self onModelExtensionAdded:extension];
    } else {
        [self onModelWillRemoveExtension:extension];
    }
}

- (void)onModelWillRemoveExtension:(BrowserExtension *)extension
{
    [_extensions removeObjectForKey:extension.extensionId];
    [self removeRequestRulesForExtension:extension];
}

#pragma mark - Private

- (void)logBlockingRoundtripOfDetails:(WebRequestDetails *)details withStartTime:(NSTimeInterval)stamp
{
    stamp = [NSDate timeIntervalSinceReferenceDate] - stamp;
    stamp = stamp * 1000; // move to ms range
    blockingRoundtripCount++;
    blockingRoundtripTotal += stamp;
    blockingRoundtripMax = MAX(blockingRoundtripMax, stamp);
    blockingRoundtripMin = MIN(blockingRoundtripMin, stamp);
}

@end
