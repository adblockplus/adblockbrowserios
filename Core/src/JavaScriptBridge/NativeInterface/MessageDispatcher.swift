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

protocol MessageDispatcher: StandardHandler {
}

extension MessageDispatcher {
    func dispatch(_ callbacks: [BridgeCallback], message: Any, completion: StandardCompletion?) {
        guard callbacks.count > 0 else {
            completion?(.failure(NSError(code: .chromeMessageCallbackNotFound, message: "No callbacks found")))
            return
        }

        let callbackId: String?
        if let completion = completion {
            callbackId = bridgeContext.put(completion)
        } else {
            callbackId = nil
        }

        let listener: MultipleResultsListener<Any?> = MultipleResultsListener {[weak bridgeContext] results in
            let anySuccessful = results.reduce(false) { $0 || $1.isSuccess }
            if !anySuccessful, let callbackId = callbackId {
                let completion = bridgeContext?.take(callbackId)
                completion?(.failure(NSError(message: "All callbacks has failed")))
            }
        }

        for callback in callbacks {
            assert(context.source.origin != .content
                || callback.webView is BackgroundFacade
                || callback.webView is SAPopupWebView)

            let completionListener = listener.createCompletionListener()

            // replace the callback parameters with those obtained from the command
            var callbackContext = callback.context
            callbackContext["callbackResponseId"] = callbackId

            if let originTab = context.source as? SAContentWebView {
                // tab is still defined, which means that the call has originated
                // in content script (see above) and must be set to the callback context
                // so that message can setup messageSender
                if let (index, tab) = context.chrome.findTab(originTab.identifier) {
                    callbackContext["tab"] = tab.chromeTabObjectWithIndex(index)
                } else {
                    assert(false, "Content webview with id \(originTab.identifier) expected to be found")
                }
            }

            if let frame = context.sourceFrame, let json = (context.source as? SAContentWebView)?.frameJson(from: frame) {
                callbackContext["frame"] = json
            }

            let callback = BridgeCallback(webView: callback.webView,
                                          frame: callback.frame,
                                          origin: callback.origin,
                                          extension: callback.extension,
                                          event: callback.event,
                                          callbackId: callback.callbackId,
                                          context: callbackContext)

            guard let injector = callback.webView?.bridgeSwitchboard?.injector else {
                completionListener(.failure(NSError(message: "Injector is not present")))
                continue
            }

            injector.call(callback, with: message, completion: completionListener)
        }
    }
}
