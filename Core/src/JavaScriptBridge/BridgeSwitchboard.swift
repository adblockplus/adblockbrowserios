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

extension String {
    static func random(_ length: Int = 16) -> String {
        let charactersString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let charactersArray = Array(charactersString)

        var randomString = ""
        for _ in 0..<length {
            randomString.append(charactersArray[Int(arc4random_uniform(UInt32(charactersArray.count)))])
        }
        return randomString
    }
}

public final class JSBridgeContext: NSObject {
    typealias ResponseHandler = StandardCompletion

    var responseHandlers = [String: ResponseHandler]()

    func put(_ responseHandler: @escaping ResponseHandler) -> String {
        for _ in 0..<8 {
            let identifier = String.random()
            if responseHandlers[identifier] == nil {
                responseHandlers[identifier] = responseHandler
                return identifier
            }
        }
        return ""
    }

    func take(_ key: String) -> ResponseHandler? {
        if let handler = responseHandlers[key] {
            responseHandlers.removeValue(forKey: key)
            return handler
        } else {
            return nil
        }
    }
}

extension SAWebView {
    func frameJson(from frame: WebKitFrame) -> [String: Any]? {
        if let kittFrame = kittFrame(forWebKitFrame: frame), let fullURLString = kittFrame.fullURLString, let frameId = kittFrame.frameId {
            return ["url": fullURLString, "frameId": frameId]
        } else {
            return nil
        }
    }
}

@objc public protocol NativeActionCommandDelegate: class {
    /// The following is expected to be called from main thread.
    /// It's up to the caller to ensure this.
    /// The extension which is subscribed to this event is known from the calling environment
    var eventDispatcher: EventDispatcher! { get }
}

extension BridgeSwitchboard: NativeActionCommandDelegate {
}

extension BridgeSwitchboard {
    func browserExtension(for extensionId: String, from webView: WebViewFacade) -> BrowserExtension? {
        return getExtension(extensionId, origin: webView.origin, fromWebView: webView)
    }

    func handle(_ command: String, withData inputData: [AnyHashable: Any], fromWebView webView: WebViewFacade, frame: WebKitFrame?) {
        guard let messageString = inputData["message"] as? String else {
            return
        }

        let message: [AnyHashable: Any]?
        do {
            let object = try JSONSerialization.jsonObject(with: messageString, options: [])
            message = object as? [AnyHashable: Any]
        } catch let error {
            Log.error("Deserialization failed: \(error)")
            return
        }

        let context = message?["c"] as? [String: Any]
        var parameters = message?["d"]
        if parameters is NSNull {
            parameters = inputData["raw"]
        }

        let `extension`: BrowserExtension
        if let extensionId = context?["extensionId"] as? String {
            guard let browserExtension = browserExtension(for: extensionId, from: webView) else {
                Log.error("Cancelling bridge command '\(command)', extension not found")
                return
            }
            `extension` = browserExtension
        } else {
            `extension` = virtualGlobalScopeExtension
        }

        let handler = ResultHandler(command: command, context: context)
        handler.injector = injector
        handler.`extension` = `extension`
        handler.webView = webView
        handler.frame = frame

        if let contentWebView = webView as? SAContentWebView, contentWebView.ignoreAllRequests {
            // Command Ignored
            handler.completion(.failure(NSError(code: .commandIgnored, message: "Command has been ignored")))
            return
        }
        dispatcher.dispatch(command, parameters, `extension`, webView, frame, handler.completion)
    }
}

final class ResultHandler {
    let command: String
    let context: [String: Any]?

    weak var injector: JSInjectorReporter?
    weak var `extension`: BrowserExtension?
    weak var webView: WebViewFacade?
    weak var frame: WebKitFrame?

    init(command: String, context: [String: Any]?) {
        self.command = command
        self.context = context
    }

    func completion(_ result: Result<Any?>) {
        switch result {
        case .success(let payload):
            executeCallback(payload)
        case .failure(let error as IgnorableError):
            Log.info("Command \(command) dispatch: \(error.innerError.localizedDescription)")
            executeCallback(error)
        case .failure(let stringConvertible as StringCodeConvertibleError):
            // catches also CodeRelatedError
            Log.critical(stringConvertible)
            executeCallback(stringConvertible)
            // Following converts ErrorType back to NSError which already exists as "e"
            // but it's needed to go AFTER stringConvertible match to filter out
            // error codes equal to ChromeBrowserActionNotAvailable
        case .failure(let error as NSError) where error.code == KittCoreErrorCode.chromeBrowserActionNotAvailable.rawValue:
            // Ignore this type of error
            Log.debug("ChromeBrowserActionNotAvailable, command was \(command)")
            executeCallback(error)
        case .failure(let error):
            Log.error("Command \(command) dispatch: \(error.localizedDescription)")
            executeCallback(error)
        }
    }

    func executeCallback(_ payload: Any?) {
        guard context?["callbackId"] is String else {
            return
        }

        if let injector = injector, let `extension` = `extension`, let webView = webView, let context = context,
            let callback = BridgeCallback(webView: webView,
                                          frame: frame,
                                          origin: webView.origin,
                                          extension: `extension`,
                                          event: .undefined,
                                          context: context) {
            // In this case of executeForExtension, callback is created on the fly and doesn't
            // have a context, so the incoming context must be assigned to it.
            injector.call(callback, with: payload, completion: callbackCompletion)
        } else {
            Log.info("Callback has been discarded")
        }
    }
}

private func callbackCompletion(_ result: Result<Any?>) {
    if case .failure(let error) = result {
        Log.error("Callback dispatch: \(error.localizedDescription)")
    }
}
