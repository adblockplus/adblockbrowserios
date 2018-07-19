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

extension JSInjectorReporter {
    private static let callbackObjectName = "KittCallbackCaller"
    private static let callbackFunctionName = "invoke"

    private func createObject(from javaScriptCallback: BridgeCallback, with payload: Any?) -> ([String: Any]) {
        var context = javaScriptCallback.context
        let object: [String: Any]
        if let error = payload as? NSError {
            context["lastError"] = ["message": error.localizedDescription]
            object = [
                "context": context
            ]
        } else {
            object = [
                "context": context,
                "data": payload as Any
            ]
        }
        return object
    }

    final func call(_ javaScriptCallback: BridgeCallback, with payload: Any?, completion: StandardCompletion?) {
        assert(Thread.isMainThread, "Must be run on main thread!")

        switch javaScriptCallback.webView {
        case .some(let webView as SAWebView):
            call(javaScriptCallback, with: payload, from: webView, completion: completion)
        case .some(let webView as BackgroundWebView):
            call(javaScriptCallback, with: payload, from: webView, completion: completion)
            /*case .Some(let webView as ContentWebView):
             call(javaScriptCallback, fromWebView: webView, completion: completion)
             break*/
        default:
            completion?(.failure(NSError(message: "WebView is not set")))
        }
    }

    private func call(_ javaScriptCallback: BridgeCallback,
                      with payload: Any?,
                      from webView: WebViewFacade,
                      completion: StandardCompletion?) {
        let object = createObject(from: javaScriptCallback, with: payload)
        let origin = javaScriptCallback.origin
        let extensionId = javaScriptCallback.extension?.extensionId
        let callbackId = javaScriptCallback.callbackId

        let properties: [String: Any] = [
            "context": "callback \(Utils.callbackOriginDescription(origin))",
            "extension": extensionId as Any,
            "parameters": object,
            "url": webView.url?.absoluteString as Any
        ]
        // swiftlint:disable:next force_try
        let json = try! JSONSerialization.string(withJSONObject: object, options: JSONSerialization.WritingOptions())
        let javascript = "window.\(JSInjectorReporter.callbackObjectName).\(JSInjectorReporter.callbackFunctionName)(\(json))"
        webView.evaluateJavaScript(javascript) { [weak self, weak webView] result, error in
            if let uwError = error {
                if let context = (webView as? BackgroundWebView)?.context, let extensionId = extensionId {
                    if shouldReloadBackground(for: uwError) {
                        context.reloadBackground(for: extensionId)
                    }
                }
                completion?(.failure(uwError))
            } else if let injector = self, let uwResult = result as? String {
                injector.handleInjectionResult(uwResult,
                                               withCallbackId: callbackId,
                                               with: origin,
                                               errorReportProperties: properties) { error, result in
                    if let uwError = error {
                        completion?(.failure(uwError))
                    } else {
                        completion?(.success(result))
                    }
                }
            } else {
                completion?(.failure(NSError(message: "Injector has not been found")))
            }
        }
    }

    private func call(_ javaScriptCallback: BridgeCallback,
                      with payload: Any?,
                      from webView: SAWebView,
                      completion: StandardCompletion?) {
        let callbackId = javaScriptCallback.callbackId
        guard let webThread = self.webThread else {
            completion?(.failure(NSError(message: "webThread is not set")))
            return
        }

        guard let frame = javaScriptCallback.frame else {
            let error = "Callback \(callbackId) KittFrame not found for WebKit frame \(String(describing: javaScriptCallback.frame))"
            completion?(.failure(NSError(message: error)))
            return
        }

        guard let kittFrame = webView.kittFrame(forWebKitFrame: frame), let jsContext = kittFrame.context else {
            let error = "Callback \(callbackId) KittFrame found for WebKit frame but has no JS context"
            completion?(.failure(NSError(message: error)))
            return
        }

        let object = createObject(from: javaScriptCallback, with: payload)
        let origin = javaScriptCallback.origin
        let properties: [String: Any] = [
            "context": "callback \(Utils.callbackOriginDescription(origin))",
            "extension": javaScriptCallback.extension?.extensionId as Any,
            "parameters": object,
            "url": webView.url?.absoluteString as Any
        ]

        // This completion block is called from Javascript.
        // Response contains either result or error.
        let jsCompletion: JSCompletion = { [weak self] (response) in
            // Dispatch from web thread to main thread
            DispatchQueue.main.async { [weak self] () -> Void in
                switch response {
                case .failure(let error):
                    completion?(.failure(error))
                case .success(let success):
                    if let injector = self {
                        injector.handleInjectionResult(success,
                                                       withCallbackId: callbackId,
                                                       with: origin,
                                                       errorReportProperties: properties) { error, result in
                            if let uwError = error {
                                completion?(.failure(uwError))
                            } else {
                                completion?(.success(result))
                            }
                        }
                    } else {
                        completion?(.failure(NSError(message: "Injector has not been found")))
                    }
                }
            }
        }

        // This dispatch to web thread is needed, otherwise callbacks are too unstable.
        let callbackContext = CallbackContext(context: jsContext, object: object, callbackId: callbackId, completion: jsCompletion)
        perform(#selector(callJavaScriptCallbackWith), on: webThread, with: callbackContext, waitUntilDone: false)
    }

    @objc
    public final func callJavaScriptCallback(_ callback: BridgeCallback, completion: CommandHandlerBackendCompletion?) {
        call(callback, with: nil) { result in
            switch result {
            case .success(let output):
                completion?(nil, output)
            case .failure(let error as IgnorableError):
                if completion == nil {
                    Log.info("Callback execution: \(error.localizedDescription)")
                }
                completion?(error, nil)
            case .failure(let error):
                if completion == nil {
                    Log.error("Callback execution: \(error.localizedDescription)")
                }
                completion?(error, nil)
            }
        }
    }

    // MARK: - Private

    private typealias JSCompletion = (Result<String>) -> Void

    private class CallbackContext: NSObject {
        let context: JSContext
        let object: Any
        let callbackId: String
        let completion: JSCompletion

        init(context: JSContext, object: Any, callbackId: String, completion: @escaping JSCompletion) {
            self.context = context
            self.object = object
            self.callbackId = callbackId
            self.completion = completion
            super.init()
        }
    }

    @objc
    private final func callJavaScriptCallbackWith(_ callbackContext: CallbackContext) {
        let context = callbackContext.context
        let completion = callbackContext.completion

        guard let window = context.globalObject,
            let callbackObject = window.objectForKeyedSubscript(JSInjectorReporter.callbackObjectName),
            !callbackObject.isUndefined && !callbackObject.isNull else {
                completion(.failure(NSError(message: "Callback \(callbackContext.callbackId) JS window does not contain the entry symbol")))
                return
        }

        guard let callbackFunction = callbackObject.objectForKeyedSubscript(JSInjectorReporter.callbackFunctionName),
            !callbackFunction.isUndefined && !callbackFunction.isNull else {
                completion(.failure(NSError(message: "JSC callback \(callbackContext.callbackId) fn not found")))
                return
        }

        let optionalResult = callbackFunction.call(withArguments: [callbackContext.object])

        guard let result = optionalResult, !result.isUndefined && !result.isNull, let string = result.toString() else {
            completion(.failure(NSError(message: "JSC callback must have a retval")))
            return
        }

        completion(.success(string))
    }
}

private func shouldReloadBackground(`for` error: Error) -> Bool {
    let codes = [WKError.unknown.rawValue,
                 WKError.webContentProcessTerminated.rawValue,
                 WKError.webViewInvalidated.rawValue]
    let error = error as NSError
    return error.domain == WKErrorDomain && codes.contains(error.code)
}
