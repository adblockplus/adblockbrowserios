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

#import "SAWebView.h"
#import "NetworkActivityObserver.h"
#import "SAWebViewFaviconLoader.h"
#import "WebViewProtocolDelegate.h"

/// https://developer.chrome.com/extensions/webNavigation#type-TransitionType
typedef NS_ENUM(NSUInteger, WebNavigationTransitionType) {
    TransitionTypeLink,
    TransitionTypeTyped,
    TransitionTypeAutoBookmark,
    TransitionTypeAutoSubframe,
    TransitionTypeManualSubframe,
    TransitionTypeGenerated,
    TransitionTypeStartPage,
    TransitionTypeFormSubmit,
    TransitionTypeReload,
    TransitionTypeKeyword,
    TransitionTypeKeywordGenerated
};

/// https://developer.chrome.com/extensions/webNavigation#type-TransitionQualifier
typedef NS_ENUM(NSUInteger, WebNavigationTransitionQualifier) {
    TransitionQualifierClientRedirect, // JS
    TransitionQualifierServerRedirect, // HTTP code
    TransitionQualifierForwardBack,
    TransitionQualifierFromAddressBar
};

@protocol WebNavigationEventsDelegate
- (void)createdNavigationTargetWithURL:(nonnull NSURL *)url
                              newTabId:(NSUInteger)tabId
                           sourceTabId:(NSInteger)srcTabId
                         sourceFrameId:(NSInteger)srcFrameId;
- (void)beforeNavigateToURL:(nonnull NSURL *)url
                      tabId:(NSUInteger)tabId
                    frameId:(NSUInteger)frameId
              parentFrameId:(NSInteger)parentId;
- (void)completedNavigationToURL:(nonnull NSURL *)url
                           tabId:(NSUInteger)tabId
                         frameId:(NSUInteger)frameId;
- (void)committedNavigationToURL:(nonnull NSURL *)url
                           tabId:(NSUInteger)tabId
                         frameId:(NSUInteger)frameId
                            type:(WebNavigationTransitionType)transitionType
                      qualifiers:(nonnull NSArray<NSNumber *> *)transitionQualifiers;
/// Callbacks were tied to specific extensions so far, but it wasn't a problem
/// because the existing event sources knew their originating extension. With the
/// introduction of webNavigation now there are events which have no relation
/// to a specific extension
- (nonnull NSArray *)arrayOfExtensionUnspecificCallbacksOfType:(CallbackEventType)eventType;
@end

/// Define a single composite delegate, so that SAContentWebView doesn't need
/// two separate properties, while both are expected to be implemented by
/// one target object
@protocol ActiveContentViewDelegate <UIWebViewDelegate, NetworkActivityDelegate>

@end

/// UIWebView subclass used to instantiate specifically the public content
/// web views (browser tabs). Encapsulates properties and functionality specific
/// to browser tabs (unlike other webview contexts like background or action).
@protocol ContentScriptLoaderDelegate;
@class BrowserHistoryManager;
@class BridgeSwitchboard;
@class ChromeTab;
@class ContentWebView;
@protocol ExtensionViewPresenter;

typedef NS_ENUM(NSUInteger, ContentWebViewStatus) {
    ContentWebViewLoading,
    ContentWebViewComplete
};

@interface SAContentWebView : SAWebView <ActiveContentViewDelegate, FaviconLoadingDelegate, WebViewProtocolDelegate>

extern NSString *const _Nonnull kContentWebViewFinishedLoadingNotification;

/**
When application-wide NSUserDefaults setting for UserAgent is changed, it gets
picked up only by newly created UIWebViews. The existing instances keep using the
UserAgent which was set at their instantiation time. That seems to be a nice workaround
to differentiate requests from multiple UIWebViews, with the bonus of having
the page resources (going directly to NSURLProtocol) tagged too. No need for
mainDocumentURL observation. HOWEVER, it was observed that the UserAgent "sticks"
only after at least one URL request passes through the newly created UIWebView.
If an user creates two UIWebViews, hence changes UserAgent twice, but uses the
first instance only after that, the second UserAgent will be used even for the
first instance.
 
This method sets a local identifier, registers self with the activity observer
and prepares UserAgent for the first request. Making the first request is a duty
of whoever has called the method.*/
- (void)prepareTabIdAttachment;

/// Tab ID
@property NSUInteger identifier;

/// loading status
@property (readonly) ContentWebViewStatus status;
/// Downloaded favicon of web resource
/// Observed by: BrowserTabViewCell, ChromeTab
@property (nonatomic, strong, nullable) id<FaviconFacade> currentFavicon;
/// URL assigned while webview is idle
/// Because setting webview request force it to reload,
/// this variable is used
@property (nonatomic, strong, nullable) NSURL *pendingURL;
/// @return pendingURL if any, or what is known to be a current URL
/// (even if self.request doesn't confirm yet) or self.request as the fallback
/// Observed: BrowserTabViewCell
@property (atomic, readonly, nullable) NSURL *currentURL;
/// currentURL is generally meant to be readonly, driven only by UIWebViewDelegate callbacks!
/// However there is HTML5 history API which effectively changes the current URL but does not
/// produce any UIWebViewDelegate activity. In such cases, the new new externally detected
/// current URL must be injected forcefuly.
- (void)setExternallyCurrentURL:(nonnull NSURL *)currentURL;

/// Return true if this webview has running resource requests
/// @discussion
/// UIWebView.loading does not WFM. I don't know whether i broke something with
/// the multipath NSURLProtocol juggling we do now, or if threading is sloppy
/// (UIWebView thread safety is considered opaque and nondeterministic), but
/// certain pages keep on saying "loading:YES" even when there is visibly nothing
/// happening and NSURLProtocol doesn't know about any traffic either. Google-fu didn't
/// yield anything. It's malfunctioning mostly on complicated pages with subframes, but
/// happens rarely for simpler responsive pages too. So let's ignore "loading" and
/// use this flag driven by NetworkActivityObserver.
@property (readonly) BOOL networkActive;

/**
 Upon installation of very specific combination of extensions,
 UIActionSheet which is displayed on long press, lets the click event through to
 to the underlying UIWebView and the long press is translated to tap. This all happens
 in a single stack trace. The effect is observable on pages where tap produces a new
 window (tab), like techmeme.com or news.google.com. The long press action sheet is
 displayed but the new tab is created and shifted in beneath.
 
 So the workaround is to flag that UIActionSheet is being opened, and ignore any requests
 coming from UIWebView in that moment. Ideally the mentioned specific combination of
 extensions should be studied. It is LinkPreview + Font-Resize. Any number of other
 extensions along with only one of them does not produce the malfunction.

 @remark also LinkPreview + Translate
 
 Apparently this bug is not caused by improper usage of gesture recognizers.
 From unknown reason canceled touch events are considered as link click. One possible
 solution is to open actionsheet after gesture is complete, however this approach is
 not really user friendly.
*/
@property (nonatomic) BOOL ignoreAllRequests;

/**
 * @return YES if identifier has been attached to this webview
 */
- (BOOL)isInitialized;

@property (nonatomic, assign, nullable) id<ActiveContentViewDelegate> activeBrowserDelegate;
@property (nonatomic, weak, nullable) id<ContentScriptLoaderDelegate> contentScriptLoaderDelegate;
@property (nonatomic, assign, nullable) id<WebNavigationEventsDelegate> webNavigationEventsDelegate;
// delegate responsible for showing the list of scripts
@property (nonatomic, assign, nullable) id<ExtensionViewPresenter> extensionViewPresenter;

@property (atomic) double networkLoadingProgress;

@property (nonatomic) BOOL wasRestored;

- (void)clearDOMCache;

/// ContentWebView, contrary to other contexts, holds a list of extensions, not just one
/// @todo still named extensions for backward compatibility (make the change smaller)
@property (nonatomic, strong, nullable) NSMutableArray *extensions;

@property (nonatomic, weak, nullable) ChromeTab *chromeTab;

@property (nonatomic, strong, nullable) SAWebViewFaviconLoader *faviconLoader;

/// WebViewProtocolDelegate
@property (nonatomic, copy, nonnull) id<AuthenticationResultProtocol> mainFrameAuthenticationResult;

@property (nonatomic, strong, nullable) NSString *readyState;

@property (nonatomic, strong, nullable) NSURLRequest *currentRequest;

@property (nonatomic, strong, nullable) UIView *curtain;

@end
