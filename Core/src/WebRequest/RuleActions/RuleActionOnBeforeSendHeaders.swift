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

// https://developer.chrome.com/extensions/webRequest#type-HttpHeaders

/**
 NSURLRequest headers format: [String:String]
 Chrome headers format: [ ["name":String, "value":String], [,], ... ]
 */
let kChromeKey = "name"
let kChromeValue = "value"

extension Array {
    fileprivate func cocoaHeaders() -> [String: Any] {
        return reduce([String: Any]()) { result, element in
            var result = result
            if let oneHeader = element as? [String: Any], let key = oneHeader[kChromeKey] as? String {
                result[key] = oneHeader[kChromeValue]
            }
            return result
        }
    }
}

/// From WebRequestDetails to Chrome
private func chromeHeaders(_ headers: [String: String]) -> [[String: String]] {
    return headers.map { key, value in
        return [kChromeKey: key, kChromeValue: value]
    }
}

open class RuleActionOnBeforeSendHeaders: AbstractRuleActionBlockable {
    open override func applyToDetails(_ details: WebRequestDetails,
                                      modifyingResponse response: BlockingResponse,
                                      completionBlock: (() -> Void)?) {
        guard let sListener = listenerCallback else {
            Log.error("RuleAction_OnBeforeSendHeaders trying to call listener already removed")
            completionBlock?()
            return
        }

        var requestProperties = details.dictionaryForListenerEvent()
        // https://developer.chrome.com/extensions/webRequest#type-OnBeforeSendHeadersOptions
        if hasExtraProperty("requestHeaders") {
            // send at least an empty array, background script may not be checking the member existence
            requestProperties["requestHeaders"] = chromeHeaders(details.responseHeaders ?? [:]) as NSObject?
        }

        DispatchQueue.main.async {
            if self.blockingResponse {
                self.eventDispatcher.handleBlockingResponse(sListener, requestProperties) { output in
                    switch output {
                    case .success(.some(let result)):
                        // http://developer.chrome.com/extensions/webRequest#type-BlockingResponse
                        // if response already has cancel flag set by previous RuleAction, do not clear it
                        response.cancel = response.cancel || result.cancel
                        // "If more than one extension attempts to modify the request,
                        // the most recently installed extension wins and all others are ignored"
                        // => Don't care if requestHeaders was already set, replace it.
                        if let chromeHeaders = result.requestHeaders {
                            response.requestHeaders = chromeHeaders.cocoaHeaders()
                        }
                    case .failure(let error):
                        Log.error("RuleAction_OnBeforeSendHeaders dispatch: \(error.localizedDescription)")
                    default:
                        break
                    }
                    completionBlock?()
                }
            } else {
                self.eventDispatcher.handleBlockingResponse(sListener, requestProperties)
                // not blocking, return right away
                completionBlock?()
            }
        }
    }

    open override var debugDescription: String {
        return "\(super.debugDescription) OnBeforeSendHeaders"
    }
}
