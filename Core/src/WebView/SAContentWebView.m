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

#import "SAContentWebView.h"
#import "ProtocolHandlerJSBridge.h"
#import "BrowserStateModel.h"
#import "ProtocolHandlerChromeExt.h"
#import "Utils.h"
#import "SAWebViewFaviconLoader.h"
#import "WebRequestEventDispatcher.h"
#import "NSURL+Conformance.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

static NSString *const kSessionTabIdFormat = @"KittTab-%lu";

/// declare as UIWebViewDelegate only privately
@interface SAContentWebView () <UIWebViewDelegate> {
    BOOL _isCurrentDocumentQueried;
    /// When the first document query on first didFinishLoad finds the document still
    /// not completed, set up a timer for repeated querying
    dispatch_source_t _documentQueryTimer;
    BOOL _isFirstFrameLoadAfterShouldStart;
    BOOL _initialized;
    /// The public currentURL property can return various values, this is one of them
    NSURL *_currentURLInternal;
}

@property (atomic, strong) NSURL *currentURL;

@property (nonatomic, strong) NSString *lastRequestIsBundleExtensionId;

@property (nonatomic) ContentWebViewStatus status;

@property (nonatomic, strong) SessionManager *sessionManager;

@end

@implementation SAContentWebView

NSString *const kContentWebViewFinishedLoadingNotification = @"ContentWebView.finishedLoading";

+ (id)allocWithZone:(struct _NSZone *)zone
{
    LogDebug(@"ContentWebView allocWithZone");
    return [super allocWithZone:zone];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        _identifier = 0;
        self.delegate = self;
        _networkActive = NO;
        _networkLoadingProgress = 0.0;
        _lastRequestIsBundleExtensionId = nil;
        _status = ContentWebViewComplete;
        _pendingURL = nil;
        _extensions = [NSMutableArray new];
        _initialized = NO;
    }
    return self;
}

/**
 These two are technically not needed, delegation to super would happen automatically. But
 it's kept for future overloading of possible UIWebView's related properties (like scroll offset)
*/
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
}

- (CallbackOriginType)origin
{
    return CallbackOriginContent;
}

- (void)prepareTabIdAttachment
{
    NSAssert(_identifier != 0, @"Identifier is not set");
    NSAssert(![self isInitialized], @"Tabid attachment called but webview already initialized");
    _initialized = YES;
    [[NetworkActivityObserver sharedInstance] registerActivityDelegate:self forTabId:_identifier];
    [TabIdCodec prepareNextWebViewForTabId:_identifier];
}

- (BOOL)isInitialized
{
    return _initialized;
}

- (NSURL *)currentURL
{
    // Most important is pending URL because it may be overriding the last currentURL
    // Next most relevant is current URL because the UIWebView may not be reporting it as request yet
    // The actual request reported by UIWebView goes as last option because UIWebView is quite lazy
    return _pendingURL ? _pendingURL : (_currentURLInternal ? _currentURLInternal : self.request.URL);
}

- (void)setCurrentURL:(NSURL *)currentURL
{
    NSURL *url = _currentURLInternal;

    [self willChangeValueForKey:NSStringFromSelector(@selector(currentURL))];
    _currentURLInternal = currentURL;
    [self didChangeValueForKey:NSStringFromSelector(@selector(currentURL))];

    if (![url isEqual:currentURL]) {
        [self setCurrentFavicon:[self faviconFor:currentURL]];
    }

    [self navigationHistoryDidChange];
}

// This has a weird name and is NOT a dedicated setter as above,
// because currentURL is still meant to be a private readonly value
// and only overwritable under special conditions described in header
- (void)setExternallyCurrentURL:(nonnull NSURL *)currentURL
{
    self.currentURL = currentURL;
}

- (void)clearDOMCache
{
}

- (void)DOMNodeForSourceAttribute:(nonnull NSString *)srcAttr
                       completion:(nonnull void (^)(NSString *__nullable nodeName, id<WebKitFrame> __nullable sourceFrame))completion
{
    completion(nil, nil);
}

- (void)onDidStartLoadingURL:(NSURL *)url isMainFrame:(BOOL)isMainFrame
{
    if (isMainFrame) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.historyManager onTabId:self->_identifier didStartLoading:url];
        });
    }
}

- (void)onRedirectResponse:(nonnull NSURLResponse *)redirResponse
                 toRequest:(nonnull NSURLRequest *)newRequest;
{
    if ([redirResponse.URL isEqual:newRequest.mainDocumentURL]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.historyManager onTabId:self->_identifier cancelledLoading:redirResponse.URL];
        });
    }
}

- (void)onErrorOccuredWithRequest:(NSURLRequest *)request
{
    if ([request.URL isEqual:request.mainDocumentURL]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.historyManager onTabId:self->_identifier cancelledLoading:request.URL];
        });
    }
}

- (void)setMainFrameAuthenticationResult:(id<AuthenticationResultProtocol>)mainFrameAuthenticationResult
{
    _mainFrameAuthenticationResult = mainFrameAuthenticationResult;
    [URLAuthCache.sharedInstance set:mainFrameAuthenticationResult];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)sender shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSNumber *typeNumber = [ResourceTypeDetector objc_detectTypeFromRequest:request allowExtended:YES];
    WebRequestResourceType type = typeNumber ? typeNumber.integerValue : -1; // -1 is undetermined type

    LogInfo(@"tab %lu shouldStartLoadWithRequest %@ %@", (unsigned long)_identifier, [request.URL isEqual:request.mainDocumentURL] ? @"main" : @"", request.URL);

    NSURL *reqUrl = [request URL];
    /**
     about: requests are ignorable until Kitt actually uses it for some meta information displaying.
     Possible cases:
     1. `about:blank` issued as User-Agent initial fixing request
     2. `about:blank` produced by UIWebView whenever `iframe.url` is set
     3. `about://arbitrary-garbage` produced by trying to load a malformed URL.
     This last one has a specialty of getting produced instead of `about:blank` of case 2, once it is
     assigned as the URL to load, so it results in endless loading cycle if it is not stopped here.
     */
    if ([reqUrl.scheme isEqualToString:@"about"]) {
        if ([reqUrl.resourceSpecifier isEqualToString:@"srcdoc"]) {
            /**
             There isn't much known about `about:srcdoc`. `about` scheme in general is specified in
             http://tools.ietf.org/html/rfc6694 but it does not mention `srcdoc`. Anyway the request
             appears to be an approval of WebKit wanting to load <iframe srcdoc> and does not load
             without returning YES. Mind that it's not the iframe content load itself yet, just an
             approval prerequisite! Hence there is no iframe context and it does not make sense to
             continue the request processing beyond this check.
             */
            return YES;
        }
        if (type != WebRequestResourceTypeMainFrame) {
            // allow about:blank if it's not main frame
            return YES;
        }
        LogInfo(@"shouldStartLoadWithRequest tab %lu ignoring", (unsigned long)_identifier);
        return NO;
    }

    if (_ignoreAllRequests) {
        return NO;
    }

    if ([ProtocolHandlerJSBridge isBridgeRequestURL:reqUrl]) {
        if ([ProtocolHandlerJSBridge isVirtualResourceBridgeRequestURL:reqUrl]) {
            // some kind of virtual page (tab id fixing etc.) which must not appear
            // in webrequest, network activity etc. so return immediately
            // after updating the active delegate
            return [_activeBrowserDelegate webView:sender shouldStartLoadWithRequest:request navigationType:navigationType];
        } else {
            [_contentScriptLoaderDelegate filterExtensionInstallationFromURL:reqUrl
                                                           completionHandler:^(NSError *error) {
                                                               if (error) {
                                                                   UIAlertView *alert = [Utils alertViewWithError:error
                                                                                                            title:@"Extension installation"
                                                                                                         delegate:nil];
                                                                   [alert show];
                                                               } else {
                                                                   [self->_extensionViewPresenter showExtensionView];
                                                               }
                                                           }];
            return NO;
        }
    }
    _lastRequestIsBundleExtensionId = [ProtocolHandlerChromeExt isBundleResourceRequest:request] ? [ProtocolHandlerChromeExt extensionIdOfBundleResourceRequest:request] : nil;

    // If browserDelegate is not set or does not implement shouldStartLoadWithRequest,
    // we have no information that would authorize us to deny the request, hence
    // allow by default
    BOOL shouldStart = YES;
    if ([_activeBrowserDelegate respondsToSelector:_cmd]) {
        shouldStart = [_activeBrowserDelegate webView:sender shouldStartLoadWithRequest:request navigationType:navigationType];
    }

    if (shouldStart) {
        // NetworkActivityObserver should be interested only in events and it's complete command
        shouldStart = [[NetworkActivityObserver sharedInstance] webView:sender
                                             shouldStartLoadWithRequest:request
                                                         navigationType:navigationType];
    }
    // PZ note: the above NetworkActivityObserver returns NO only if request is for a special
    // DOM observation bridge URL, so there is no need to continue with chrome APIs composition
    if (!shouldStart) {
        return NO;
    }
    if (!([ProtocolHandlerChromeExt isBundleResourceRequest:request]
            || [request.URL.scheme isEqualToString:@"http"]
            || [request.URL.scheme isEqualToString:@"https"])) {
        // Not an obvious web request, try if somebody else is interested in handling it
        // (mailto, phone, itms-apps)
        UIApplication *app = [UIApplication sharedApplication];
        if ([app canOpenURL:request.URL]) {
            [app openURL:request.URL];
        }
        return NO;
    }

    if (type == WebRequestResourceTypeObject || type == WebRequestResourceTypeOther) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[LocalizationResources downloadFailureAlertTitle]
                                                            message:BundleLocalizedString(@"Browser cannot download this file.", @"Download prohibition alert text")
                                                           delegate:nil
                                                  cancelButtonTitle:[LocalizationResources alertOKText]
                                                  otherButtonTitles:nil];
        [alertView show];
        return NO;
    }
    if ([request.URL isEqual:request.mainDocumentURL]) {
        _currentRequest = request;
        // new mainframe request
        // allow DOM querying
        _documentQueryTimer = nil;
        _isCurrentDocumentQueried = NO;
        // remember for the case when the URL sticks (it's not going to be a redirection)
        _pendingURL = request.URL;
        _isFirstFrameLoadAfterShouldStart = YES;

        id<AuthenticationResultProtocol> newAuthResult = [[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUnknown host:_pendingURL.host];
        if ([_pendingURL.scheme isEqualToString:@"https"]) {
            // the new level is potentially secure, ask cache
            // The authentication delegate was not called yet
            newAuthResult = [URLAuthCache.sharedInstance get:_pendingURL];
            if (!newAuthResult) {
                newAuthResult = [[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelTrustImplicit host:_pendingURL.host];
            }
        }
        // do not call the property setter as it would overwrite the mapping
        [self willChangeValueForKey:NSStringFromSelector(@selector(mainFrameAuthenticationResult))];
        _mainFrameAuthenticationResult = newAuthResult;
        [self didChangeValueForKey:NSStringFromSelector(@selector(mainFrameAuthenticationResult))];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)sender
{
    if (_isFirstFrameLoadAfterShouldStart) {
        // last allowed URL is actually being loaded.
        // Clear pending and the last known document title
        self.currentURL = _pendingURL;
        [self clearDOMCache];
        _pendingURL = nil;
        _isFirstFrameLoadAfterShouldStart = NO;
        self.documentTitle = nil;
        self.status = ContentWebViewLoading;
    }
    if ([_activeBrowserDelegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [_activeBrowserDelegate webViewDidStartLoad:sender];
    }
    [[NetworkActivityObserver sharedInstance] webViewDidStartLoad:sender];

    [self navigationHistoryDidChange];
}

- (void)webViewDidFinishLoad:(UIWebView *)sender
{
    LogDebug(@"Tab %lu didFinishLoad %@", (unsigned long)_identifier, _currentURLInternal);
    /*
     Web view did finish load, it is a SSL link but security level is still not determined.
     This means that authentication delegate was not called in protocol handler. Observed sometimes
     with a page loaded previously in a different tab.
     */
    if ([_currentURLInternal.scheme isEqualToString:@"https"]) {
        id<AuthenticationResultProtocol> verifyAuthResult = [URLAuthCache.sharedInstance get:_currentURLInternal];
        if (verifyAuthResult && verifyAuthResult.level != _mainFrameAuthenticationResult.level) {
            // Cache knows the page status different from the current one, update.
            // Do not call the property setter as it would overwrite the mapping
            [self willChangeValueForKey:NSStringFromSelector(@selector(mainFrameAuthenticationResult))];
            _mainFrameAuthenticationResult = verifyAuthResult;
            [self didChangeValueForKey:NSStringFromSelector(@selector(mainFrameAuthenticationResult))];
        }
    }

    if (!_isCurrentDocumentQueried
        && !_documentQueryTimer
        && ![self queryDocumentInWebView:sender]) {
        // Document was not queried yet, timer is not running and first query says document is not completed.
        // PZ NOTE: i tried to set up a single persistent timer and then cancel/resume it repeatedly. But the
        // event handler never fired for me that way. Don't know why.
        _documentQueryTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(_documentQueryTimer, DISPATCH_TIME_NOW, 200ull * NSEC_PER_MSEC, 50ull * NSEC_PER_MSEC);
        __weak typeof(self) wSelf = self;
        __weak typeof(sender) wSender = sender;
        dispatch_source_set_event_handler(_documentQueryTimer, ^{
            __strong typeof(self) sSelf = wSelf;
            if ([sSelf queryDocumentInWebView:wSender]) {
                sSelf->_documentQueryTimer = nil;
            }
        });
        dispatch_resume(_documentQueryTimer);
    }
    // Must go after historymanager update because it will be queried for the
    // latest history updates
    if ([_activeBrowserDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [_activeBrowserDelegate webViewDidFinishLoad:sender];
    }
    [[NetworkActivityObserver sharedInstance] webViewDidFinishLoad:sender];

    [self.chromeTab saveState];
    [self navigationHistoryDidChange];
}

- (void)webView:(UIWebView *)sender didFailLoadWithError:(NSError *)error
{
    LogInfo(@"didFailLoad %lu %@ %ld", (unsigned long)_identifier, sender.request.URL.absoluteString, (long)error.code);
    switch ([error code]) {
    case kCFURLErrorCancelled: {
        // Do nothing in this case
        break;
    }
    case 102: {
        // Frame load interrupted.
        // Is somehow linked to site redirection (like most frequently www.site.com to mobile.site.com)
        // But there is no visual difference in behavior, so according to sources it is safe to ignore
        break;
    }
    case 204: {
        // Plug-in handled load
        // http://iphonedevsdk.com/forum/iphone-sdk-development/23580-webkiterrordomain-error-204.html
        break;
    }
    case kCFURLErrorUserCancelledAuthentication: {
        // The error name says it all. User did it so he doesn't need to know again about it.
        // Note: consciously produced in ProtocolHandler authentication challenge handling
    } break;
    default: {
        NSDictionary *userInfo = [error userInfo];
        __unused NSString *url = userInfo ? [userInfo objectForKey:NSURLErrorFailingURLStringErrorKey]
                                          : @"undefined";
        NSString *title = [Utils applicationName];
        NSString *message = [error localizedDescription];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:[LocalizationResources alertOKText]
                                              otherButtonTitles:nil];
        [alert show];
        // Must go after historymanager update because it will be queried for the
        // latest history updates
        if ([self.chromeTab active] && [_activeBrowserDelegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
            [_activeBrowserDelegate webView:sender didFailLoadWithError:error];
        }

        [[NetworkActivityObserver sharedInstance] webView:sender didFailLoadWithError:error];
        break;
    }
    }

    [self.chromeTab saveState];
    [self navigationHistoryDidChange];
}

#pragma mark - NetworkActivityDelegate

/// Must remember the last provided network activity values even if self is
/// not the active view. It will be needed to update the view when it becomes
/// active again. Otherwise it would get updated only as late as the next event
/// arrives.
- (void)onNetworkLoadingProgress:(double)progress
{
    if (progress != _networkLoadingProgress) {
        // Progress bar has to be in range from 0.0 to 1.0
        progress = MAX(0.0, MIN(progress, 1.0));
        self.networkLoadingProgress = progress;
        if ([_activeBrowserDelegate respondsToSelector:_cmd]) {
            [_activeBrowserDelegate onNetworkLoadingProgress:progress];
        }
    }
}

- (void)onNetworkActivityState:(BOOL)active
{
    if (active != _networkActive) {
        _networkActive = active;
        if ([_activeBrowserDelegate respondsToSelector:_cmd]) {
            [_activeBrowserDelegate onNetworkActivityState:active];
        }
    }
}

#pragma mark - FaviconLoaderDelegate

- (NSString *)stringFromEvalJS:(NSString *)jsString
{
    return [self stringByEvaluatingJavaScriptFromString:jsString];
}

#pragma mark - Private

/// @return if document is completed
- (bool)queryDocumentInWebView:(UIWebView *)webView
{
    NSString *readyState = self.readyState;
    if (![readyState isEqualToString:@"complete"]) {
        return NO;
    }
    self.status = ContentWebViewComplete;
    if (!webView.request) {
        // Some kind of strange real world browsing corner case, not easily reproducible
        LogError(@"webview claims readyState=complete but no request");
        return YES;
    }
    NSURL *mainFrameLoadingURL = webView.request.mainDocumentURL;
    if (!mainFrameLoadingURL) {
        // Some kind of strange real world browsing corner case, not easily reproducible
        LogError(@"webview claims readyState=complete but request has no mainDocumentURL");
        return YES;
    }
    if (![ProtocolHandlerJSBridge isBridgeRequestURL:mainFrameLoadingURL]) {
        // Not needed when a bridge request is going through
        [self.historyManager createOrUpdateHistoryFor:mainFrameLoadingURL
                                             andTitle:self.documentTitle
                                   updateVisitCounter:NO];
        [self.faviconLoader verifyFaviconWith:self.request];
    }
    // @todo onCompleted for subframes, if it's even technically possible. We do have
    // frame id mapping in ProtocolHandler, but that signals only finished loading on wire,
    // not a "document completely loaded and initialized, including the resources it refers to"
    [_webNavigationEventsDelegate completedNavigationToURL:mainFrameLoadingURL
                                                     tabId:_identifier
                                                   frameId:0];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kContentWebViewFinishedLoadingNotification
                      object:self
                    userInfo:@{
                        @"url" : mainFrameLoadingURL,
                        @"title" : self.documentTitle ? self.documentTitle : @""
                    }];

    [self.historyManager onTabId:self.identifier
             didFinishLoadingURL:mainFrameLoadingURL
                       withTitle:self.documentTitle];

    // if any pending URL was set, it has become a current URL
    self.currentURL = mainFrameLoadingURL;
    _pendingURL = nil;
    return YES;
}

- (void)setReadyState:(NSString *)readyState
{
    NSAssert([NSThread isMainThread], @"Must be set from main thread");
    _readyState = readyState;
    // Interactive is apparently too early (previous page might be still displayed).
    if ([@"complete" isEqualToString:[readyState lowercaseString]]) {
        [self closeCurtain];
    }
    [[NetworkActivityObserver sharedInstance] onReadyStateDidChanged:self];
}

@end
