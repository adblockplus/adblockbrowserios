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

import UIKit

extension SAContentWebView {
    func loadURL(_ url: NSURL?) {
        var url = url

        if let relativeURL = url, (relativeURL.host?.isEmpty ?? true) {
            if let relativeURLString = relativeURL.absoluteString, let currentURL = currentRequest?.url {
                // If the new URL is relative to the current URL
                // (only path, does not contain host)
                // it must be fully resolved against the current URL.
                // Otherwise [UIWebView loadRequest] will make 'file:' request from it
                url = NSURL(string: relativeURLString, relativeTo: currentURL)
            } else {
                url = nil
            }
        }

        stopLoading()

        if let url = url {
            loadRequest(URLRequest(url: url as URL))
        } else if let url = NSURL(string: "about:blank") {
            loadRequest(URLRequest(url: url as URL))
        }
    }

    class func prepare(_ aWebView: SAContentWebView,
                       contextMenuDataSource: ContextMenuDataSource?,
                       webNavigationEventsDelegate: WebNavigationEventsDelegate?,
                       contentScriptLoaderDelegate: ContentScriptLoaderDelegate?) {
        let webNavigationDelegateBlock = {(url: NSURL) -> Void in

            /*
             parentWebView exists in only two cases. Parent is the webview which was
             active at that moment.
             1. windowOpen API call coming from a content webview (window.open or <a _blank>)
             2. long tap "open in new tab"

             Chrome extensions API documentation vagueness exhibit No.42:
             https://developer.chrome.com/extensions/webNavigation#event-onCreatedNavigationTarget
             "Fired when a new window, or a new tab in an existing window, is created to host a navigation."
             No exceptions and/or conditions documented.
             The question: "what should be listener callback values for sourceTab/FrameId when a tab
             is created from the browser (by clicking plus button), not from another tab?"
             The answer: Chrome does not fire the above event at all in such scenario.
             */
            if aWebView.isInitialized() { {
                guard let tab = aWebView.chromeTab else {
                    print("Preparing content webview but it has no ChromeTab attached")
                    return
                }
                guard let openerTab = tab.openerTab else {
                    // fire onCreatedNavigationTarget only when openerTab exists (see above)
                    return
                }
                guard let openerFrameId = tab.openerFrame?.frameId else {
                    print("Content webview has opener tab but not opener frame, can't invoke webNavigation")
                    return
                }
                webNavigationEventsDelegate?.createdNavigationTarget(
                    with: url as URL,
                    newTabId: tab.identifier,
                    sourceTabId: Int(openerTab.identifier),
                    sourceFrameId: Int(truncating: openerFrameId))
                }()
            }

            aWebView.loadURL(url)
        }

        // Pending Webview has never been displayed, so it has to be initialized
        if !aWebView.isInitialized() {
            aWebView.scalesPageToFit = true
            aWebView.isMultipleTouchEnabled = true
            aWebView.dataDetectorTypes = UIDataDetectorTypes()
            aWebView.contentScriptLoaderDelegate = contentScriptLoaderDelegate
            aWebView.webNavigationEventsDelegate = webNavigationEventsDelegate
            aWebView.prepareTabIdAttachment()
        }

        if aWebView.wasRestored {
            aWebView.wasRestored = false

            // After the tab was restored, reload the last request.
            // Hopefully, the request is going to be loaded from cache.
            // Our testing proved that it is at least for iOS 10.

            aWebView.reload()
        } else if let pendingURL = aWebView.pendingURL {
            // Load pending request
            webNavigationDelegateBlock(pendingURL as NSURL)
        } else if aWebView.currentURL == nil {
            // new tabs beyond first one and no request set
            // run the predefined tabid fixing URL
            guard let url = ProtocolHandlerJSBridge.url(with: JSBridgeResource_EmptyPage, path: nil) else {
                return
            }

            webNavigationDelegateBlock(url as NSURL)
        } else {
            // if a webview is initialized and no pending URL is set,
            // do nothing and just update location field
        }
    }
}
