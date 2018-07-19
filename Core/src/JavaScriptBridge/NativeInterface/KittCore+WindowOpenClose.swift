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

extension KittCore {
    func open(_ parameter: JSAny) throws -> Any? {

        let about = "about:blank"

        let urlString: String
        if let uwUrlString = (parameter.any as? [String: Any])?["url"] as? String, !uwUrlString.isEmpty {
            // https://developer.mozilla.org/en-US/docs/Web/API/Window/open#Description
            // "If strUrl is an empty string, then a new blank, empty window (URL about:blank) is created"
            urlString = uwUrlString
        } else {
            urlString = about
        }

        guard
            let URL = context.source.url,
            let url = urlString.asURLResolvedAgainst(URL),
            let urlScheme = url.scheme else {
                // malformed URL
                throw NSError(message: "window.open invalid URL \(urlString)")
        }

        if ["http", "https"].contains(urlScheme) || urlString == about {
            /*
             @todo an unconditional new window should be displayed only if `target` is `_blank`.
             https://developer.mozilla.org/en-US/docs/Web/API/Window/open#Examples
             But Kitt, as of the moment
             - does not remember JS-assigned window.open target name with the window
             - does not provide return value of window.open call
             So we can't look up a previously opened named window and even if we could, we can't return it.
             (There is no recent sane way of constructing a "window object" synchronously)
             So the only natural (ie. as normal as possible) behavior is to open a new window
             upon any call to window.open, regardless of the `target` value.
             */

            let delegate = context.source.bridgeSwitchboard?.browserControlDelegate

            guard let source = context.source as? SAWebView else {
                throw NSError(message: "window.open invalid URL \(urlString)")
            }

            if let frame = context.sourceFrame, let kittFrame = source.kittFrame(forWebKitFrame: frame) {
                delegate?.showNewTab(with: url, fromSource: source, from: kittFrame)
            } else {
                delegate?.showNewTab(with: url, fromSource: source, from: nil)
            }

        } else {
            // Handles special types of schemes like mailto://...
            // Test case: Join button in acceptableads.org
            UIApplication.shared.openURL(url)
        }

        return nil
    }

    func close() throws -> Any? {
        guard let source = context.source as? SAWebView, source.origin != .content else {
            throw NSError(message: "Only content scripts allowed to window.close through bridgeSwitchboard")
        }

        guard let uwFrame = context.sourceFrame, let uwJson = source.frameJson(from: uwFrame), uwJson["frameId"] as? Int == 0 else {
            throw NSError(message: "Only calls from main frames are allowed to window.close through bridgeSwitchboard")
        }

        let window = context.chrome.focusedWindow

        if window?.tabs.count == 1 && !Settings.canCloseLastTab() {
            throw NSError(message: "Closing last tab is not allowed in settings")
        }

        guard let tab = (context.source as? SAContentWebView)?.chromeTab else {
            throw NSError(message: "Tab should be set")
        }

        let tabWasActive = tab.active
        if (window?.remove(tab: tab) ?? false) && tabWasActive {
            // closed tab was active, switch to the new active tab
            let newActiveTab = window?.activeTab
            // Ideally we would know if the window which just closed itself was really
            // originated by the previous webview, but we don't.
            newActiveTab?.webView.reload()
        }

        return nil
    }
}
