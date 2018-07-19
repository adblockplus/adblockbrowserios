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

// The Value stored in DOMNodesCache
final class DOMNodeCacheValue: NSObject {
    let nodeName: String
    weak var originFrame: WebKitFrame?

    init(nodeName: String, originFrame: WebKitFrame) {
        self.nodeName = nodeName
        self.originFrame = originFrame
    }
}

public final class ContentWebView: SAContentWebView {
    private let DOMNodeCache = AsyncWaitingReadCache<DOMNodeCacheValue>(getterTimeout: 0.1)

    // MARK: - DOM

    public func onCreatedDOMNodeName(_ nodeName: String, withSrcAttribute srcAttr: String, from frame: WebKitFrame) {
        let value = DOMNodeCacheValue(nodeName: nodeName, originFrame: frame)
        DOMNodeCache.set(srcAttr, value: value)
    }

    public override func domNode(forSourceAttribute srcAttr: String, completion: @escaping (String?, WebKitFrame?) -> Void) {
        DOMNodeCache.getAsync(srcAttr) { value in
            let nodeName = value?.nodeName
            let frame = value?.originFrame
            Log.debug("DOMNodeName GET NAME \(String(describing: nodeName)) FRAME \(String(describing: frame)) \(srcAttr)")
            completion(nodeName, frame)
        }
    }

    public override func clearDOMCache() {
        DOMNodeCache.clear()
    }

    public override func onRedirectResponse(_ redirResponse: URLResponse, to newRequest: URLRequest) {
        super.onRedirectResponse(redirResponse, to: newRequest)
        if redirResponse.url != newRequest.mainDocumentURL {
            if let fromUrl = redirResponse.url, let toUrl = newRequest.url {
                DOMNodeCache.cloneValue(of: fromUrl.absoluteString, toKey: toUrl.absoluteString)
            }
        }
    }

    // MARK: - UIWebView

    open override func loadRequest(_ request: URLRequest) {
        var request = request
        request.originalURL = request.url
        super.loadRequest(request)
    }

    open override func goBack() {
        super.goBack()
        historyManager?.onTabIdDidGoBack(identifier)
        navigationHistoryDidChange()
    }

    open override func goForward() {
        super.goForward()
        historyManager?.onTabIdDidGoForward(identifier)
        navigationHistoryDidChange()
    }

    // MARK: - DOM Events

    func DOMDidLoad() {
        if let currentURL = currentURL {
            historyManager?.createOrUpdateHistory(for: currentURL, andTitle: documentTitle, updateVisitCounter: true)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func handleEvent(_ event: Any?, fromFrame: WebKitFrame) -> Bool {
        guard let event = event as? [String: Any] else {
            Log.warn("Unable to process event")
            return false
        }

        guard let type = event["type"] as? String else {
            Log.warn("Unsupported event type \(String(describing: event["type"]))")
            return false
        }

        switch type {
        case "DOMDidLoad":
            if let properties = event["state"] as? [String: Any] {
                if let title = (properties["title"] as? String)?.trimmedDocumentTitle, title != self.documentTitle {
                    self.documentTitle = title
                }
                if let readyState = properties["readyState"] as? String, readyState != self.readyState {
                    self.readyState = readyState
                }
            }
            DOMDidLoad()
            return true
        case "ReadyStateDidChange":
            if let readyState = (event["state"] as? [String: Any])?["readyState"] as? String {
                self.readyState = readyState
                return true
            } else {
                return false
            }
        case "TitleDidChanged":
            self.documentTitle = (event["state"] as? [String: Any])?["newValue"] as? String
            return true
        case "FaviconsDidChanged":
            return loadFaviconsWith(event["state"])
        case "DOMMutationEvent":
            guard let state = event["state"] as? [[String: String]] else {
                return false
            }

            for value in state {
                if let name = value["name"], let src = value["src"] {
                    /*
                     If a resource with the same URL exists in multiple frames (may be a main frame and a subframe),
                     this will potentially overwrite the value. But it is harmless for two reasons:
                     1. it will not change the node name, as a resource with the same URL will hardly have
                     two different node types in different frames
                     2. originating frame is relevant only for subframes - main frame requests are detected by
                     mainDocumentURL equality so the frame is known without consulting the DOM node cache
                     */
                    onCreatedDOMNodeName(name, withSrcAttribute: src, from: fromFrame)
                }
            }
            return true
        default:
            return false
        }
    }
}

extension String {
    var trimmedDocumentTitle: String {
        // We want titles as "\n\tStartseite  -\n\tBild.de"
        // convert to "Startseite - Bild.de", that means replace
        // whitespace sequences with one space
        // http://stackoverflow.com/a/18083852
        let set = CharacterSet.whitespacesAndNewlines
        let title = self.replacingOccurrences(of: "[\\s]+",
                                              with: " ",
                                              options: .regularExpression,
                                              range: nil)
        return title.trimmingCharacters(in: set)
    }
}
