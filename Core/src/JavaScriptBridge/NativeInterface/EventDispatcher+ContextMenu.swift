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

extension EventDispatcher {
    @objc
    public func contextMenuClicked(_ extension: BrowserExtension, json: Any) {
        dispatch(.contextMenuClicked, extension: `extension`, json: json) { callback in
            // chrome.contextMenus.onClick event handler requires caller tab object
            var context = callback.context
            // If browser action was emitted, active web view exists for sure so
            // it's not needed to check for validity
            let tabId = Chrome.sharedInstance.focusedWindow?.activeTab?.identifier ?? 0
            // @todo this is a quick fix. Proper creation of full tab object out of
            // SAContentWebView is being done in a different feature and will be merged here
            context["tabId"] = tabId

            return BridgeCallback(webView: callback.webView,
                                  frame: callback.frame,
                                  origin: callback.origin,
                                  extension: callback.extension,
                                  event: callback.event,
                                  callbackId: callback.callbackId,
                                  context: context)
        }
    }
}
