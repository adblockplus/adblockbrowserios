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

public final class WebViewManager: NSObject {
    fileprivate var weakWebViews = [Weak<SAWebView>]()

    @objc
    public func add(_ webView: SAWebView) {
        weakWebViews.append(Weak(reference: webView))
        weakWebViews = weakWebViews.filter { $0.reference != nil }
    }

    @objc
    public func remove(_ webView: SAWebView) {
        weakWebViews = weakWebViews.filter { $0.reference != nil && $0.reference != webView }
    }

    public var webViews: AnySequence<SAWebView> {
        return AnySequence(weakWebViews.lazy.flatMap { $0.reference })
    }

    @objc public static let sharedInstance = WebViewManager()
}
