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

import Foundation

extension ExtensionBackgroundContext {
    @objc
    public func createBackground(`for` `extension`: BrowserExtension) {
        if !`extension`.isRunnable(inContext: .background) || !`extension`.enabled {
            // has no background script or is disabled, nothing to do
            return
        }

        let webView: BackgroundFacade

        if Settings.useWKWebViewIfAvailable() {
            let wkWebView = BackgroundWebView(frame: CGRect())
            wkWebView.context = self
            wkWebView.uiDelegate = self.uiDelegate
            wkWebView.navigationDelegate = self
            webView = wkWebView
        } else {
            webView = SABackgroundWebView(frame: CGRect())
        }

        webViews[`extension`.extensionId] = webView
        // register the context with switchboard
        switchboard.registerBackgroundWebView(webView, for: `extension`)

        if let webView = webView as? SABackgroundWebView {
            webView.delegate = self
        }

        // run the scripts unless commanded to skip them
        // (it's up to the commanding code to run loadScripts *later)
        if !skipInitialScriptLoad {
            webView.loadExtensionBundleScript()
        }
    }

    @objc
    public func removeBackground(`for` extensionId: String) {
        if let webView = webViews[extensionId] as? BackgroundFacade {
            // tell the switchboard the background script context will disappear
            if let `extension` = webView.`extension` {
                switchboard.unregisterBackgroundWebView(for: `extension`)

                // detach from extension to prevent circular reference
                webView.`extension` = nil
            }
        }

        // kill the background script context
        webViews.removeObject(forKey: extensionId)
        cancelReloadTask(for: extensionId)
    }

    func reloadBackground(`for` extensionId: String) {
        assert(Thread.isMainThread)

        guard let webView = backgroundWebView(for: extensionId) else {
            Log.warn("No background webView to reload")
            return
        }

        if reloadingTasks[extensionId] != nil {
            // Nothing to do
            return
        }

        let `extension` = (webView as? BackgroundWebView)?.`extension`

        removeBackground(for: extensionId)

        if let `extension` = `extension` {
            let item = DispatchWorkItem { [weak self, weak `extension`] in
                self?.cancelReloadTask(for: extensionId)

                if let `extension` = `extension` {
                    self?.createBackground(for: `extension`)
                    self?.loadScripts(ofExtensionId: `extension`.extensionId)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
            reloadingTasks[extensionId] = item
        }

        performMemoryCleanUp()
    }

    // MARK: - Private

    private func cancelReloadTask(`for` extensionId: String) {
        (reloadingTasks[extensionId] as? DispatchWorkItem)?.cancel()
        reloadingTasks.removeObject(forKey: extensionId)
    }

    private func performMemoryCleanUp() {
        Chrome.sharedInstance.prune()
        URLCache.shared.removeAllCachedResponses()
    }
}

// MARK: - WKNavigationDelegate

extension ExtensionBackgroundContext: WKNavigationDelegate {
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Log.warn("WebView process did terminated")

        guard let webView = webView as? BackgroundWebView else {
            return
        }

        guard let extensionId = webView.extension?.extensionId else {
            return
        }

        reloadBackground(for: extensionId)
    }
}
