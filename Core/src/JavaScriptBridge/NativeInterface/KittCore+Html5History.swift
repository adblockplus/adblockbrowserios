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

enum Html5HistoryEventType: String, JSParameter {
    case pushState
    case replaceState
    case forward
    case back
    case popstate

    init?(json: Any?) {
        if let jsonString = json as? String, let event = type(of: self).init(rawValue: jsonString) {
            self = event
        } else {
            Log.warn("Unkown HTML5 history command \(String(describing: json))")
            return nil
        }
    }
}

extension KittCore {
    // swiftlint:disable:next cyclomatic_complexity
    func onHistoryEvent(_ type: Html5HistoryEventType, _ object: JSAny) throws -> Any? {
        guard let contentWebView = context.source as? SAContentWebView else {
            throw NSError(message: "Html5 history command %@ called from nontab webview \(type)")
        }

        let URLObject: Any

        if let dictionary = object.any as? [String: Any], let url = dictionary["href"] {
            // There is no formal spec for the history API parameter, but empirically it may be
            // an object where the full URL is under "href" key
            URLObject = url
        } else {
            URLObject = object.any
        }

        // by default the object is directly the new URL string
        guard let incomingURLString = URLObject as? String else {
            throw NSError(message: "Html5 history command '\(type)' state object expected string got \(URLObject.self) '\(URLObject)'")
        }

        if incomingURLString.isEmpty {
            throw NSError(message: "Html5 history command '\(type)' got empty URL string")
        }

        guard let incomingURL = incomingURLString.asURLResolvedAgainst(contentWebView.currentURL) else {
            throw NSError(message: "Html5 history command '\(type)' has invalid URL, string was '\(incomingURLString)'")
        }

        contentWebView.closeCurtain()
        contentWebView.setExternallyCurrentURL(incomingURL)
        contentWebView.assignAlias(forCurrentMainFrame: incomingURL.absoluteString)

        let tabId = contentWebView.identifier

        if let historyDelegate = contentWebView.historyManager {
            switch type {
            case .pushState:
                historyDelegate.onTabId(tabId, didStartLoading: incomingURL)
            case .replaceState:
                historyDelegate.onTabId(tabId, didReplaceCurrentWith: incomingURL)
            case .forward:
                historyDelegate.onTabIdDidGoForward(tabId)
            case .back:
                historyDelegate.onTabIdDidGoBack(tabId)
            case .popstate:
                // NOTHING TO DO
                // HTML5 back/forward is handled, this event is only responsible for updating tab's url.
                break
            }
        }

        return nil
    }
}
