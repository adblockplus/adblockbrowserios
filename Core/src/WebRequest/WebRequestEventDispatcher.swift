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

extension Dictionary {
    func toStringDictionary() -> [String: String] {
        return reduce([String: String]()) { data, pair in
            if let key = pair.0 as? String, let value = pair.1 as? String {
                var data = data
                data[key] = value
                return data
            }
            return data
        }
    }
}

extension WebRequestEventDispatcher {
    func onBeforeRequest(_ request: URLRequest,
                         withDetails details: WebRequestDetails,
                         responseBlock:@escaping ResponseBlock) {
        details.stage = "onBeforeRequest"
        applyRules(on: details, modifyingResponse: BlockingResponse(), finish: responseBlock)
    }

    func onBeforeSendHeaders(_ requestHeaders: [AnyHashable: Any]?,
                             cookieHeaders: [String: String],
                             withDetails details: WebRequestDetails,
                             responseBlock: @escaping ResponseBlock) {
        details.stage = "onBeforeSendHeaders"
        if let requestHeaders = requestHeaders {
            var allHeaders = requestHeaders.toStringDictionary()

            // merge with additional headers
            for (key, value) in cookieHeaders {
                allHeaders[key] = value
            }

            // Some keys are not published to the extensions
            // https://developer.chrome.com/extensions/webRequest#life_cycle_footnote
            for key in ["Authorization", "Cache-Control", "Connection", "Content-Length",
                      "Host", "If-Modified-Since", "If-None-Match", "If-Range", "Partial-Data",
                      "Pragma", "Proxy-Authorization", "Proxy-Connection", "Transfer-Encoding"] {
                        allHeaders.removeValue(forKey: key)
            }

            details.requestHeaders = allHeaders
        }
        applyRules(on: details, modifyingResponse: BlockingResponse(), finish: responseBlock)
    }

    public func onHeadersReceived(_ headers: [AnyHashable: Any],
                                  withDetails details: WebRequestDetails,
                                  responseBlock: @escaping ResponseBlock) {
        details.stage = "onHeadersReceived"
        details.responseHeaders = headers.toStringDictionary()
        applyRules(on: details, modifyingResponse: BlockingResponse(), finish: responseBlock)
    }

    func getFrameFrom(_ url: String, parentFrameURLString: String, webView: SAContentWebView, isMainFrame: Bool, isSubFrame: Bool) -> KittFrame {
        let frameOfParent = webView.kittFrame(forReferer: parentFrameURLString)

        if let frameOfRequest = webView.kittFrame(forReferer: url) {
            assert(isMainFrame || isSubFrame, "A frame should already exist for a request URL only if it's a frame request")
            return frameOfRequest
        } else if let frameOfParent = frameOfParent {
            // While subframe request is hierarchically equal to any other request in a given frame,
            // contrary to other requests, it is required to have its own frameId, not the parent frame id
            return isSubFrame ? webView.provisionalFrame(forURL: url, parentFrameRefererString: parentFrameURLString) : frameOfParent
        } else {
            /*
             The above is logical and philosophically true, but practically not. One observed case
             is HTML5 pushState/replaceState where the resource requests arrive with a referer of the
             pushed URL, without getting the request for the pushed URL, the less a JSC creation
             for the pushed URL. Let's hope the JSC creation arrives later and let us purge the
             provisional map.
             */
            if isMainFrame {
                return webView.provisionalFrame(forURL: url, parentFrameRefererString: nil)
            } else if isSubFrame {
                return webView.provisionalFrame(forURL: url, parentFrameRefererString: parentFrameURLString)
            } else {
                // The request is a plain resource request, not a (sub) frame, but the frame of this request
                // is not known anyway. So the frame must be created.
                return webView.provisionalFrame(forURL: parentFrameURLString, parentFrameRefererString: nil)
            }
        }
    }
}
