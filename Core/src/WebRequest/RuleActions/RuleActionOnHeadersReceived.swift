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

open class RuleActionOnHeadersReceived: AbstractRuleActionBlockable {
    open override func applyToDetails(_ details: WebRequestDetails,
                                      modifyingResponse response: BlockingResponse,
                                      completionBlock: (() -> Void)?) {
        guard let sListener = listenerCallback else {
            Log.error("RuleAction_OnHeadersReceived trying to call listener already removed")
            completionBlock?()
            return
        }

        var requestProperties = details.dictionaryForListenerEvent()

        if let responseHeaders = details.responseHeaders {
            requestProperties["responseHeaders"] = responseHeaders as NSObject?
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
                        // => Don't care if redirectUrl was already set, replace it.
                        response.redirectUrl = result.redirectUrl
                        response.responseHeaders = result.responseHeaders
                    case .failure(let error):
                        Log.error("RuleAction_OnHeadersReceived dispatch: \(error.localizedDescription)")
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
        return "\(super.debugDescription) OnHeadersReceived"
    }
}
