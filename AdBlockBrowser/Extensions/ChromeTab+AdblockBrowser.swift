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

// MARK: - Tab preview

var associatedObjectHandle = "TabPreview"

extension ChromeTab {
    @objc dynamic var preview: UIImage? {
        get {
            return objc_getAssociatedObject(self, &associatedObjectHandle) as? UIImage
        }
        set {
            objc_setAssociatedObject(self, &associatedObjectHandle, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - URL loading

extension ChromeTab {
    func load(url: URL?) {
        var url = url

        if let relativeURL = url, (relativeURL.host?.isEmpty ?? true) {
            let relativeURLString = relativeURL.absoluteString
            if let currentURL = webView.currentRequest?.url {

                // If the new URL is relative to the current URL
                // (only path, does not contain host)
                // it must be fully resolved against the current URL.
                // Otherwise [UIWebView loadRequest] will make 'file:' request from it

                url = Foundation.URL(string: relativeURLString, relativeTo: currentURL)
            } else {
                url = nil
            }
        }

        webView.stopLoading()

        if let url = url {
            webView.load(URLRequest(url: url));
        } else if let url = Foundation.URL(string: "about:blank") {
            webView.load(URLRequest(url: url));
        }
    }
}
