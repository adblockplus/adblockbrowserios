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

public final class EventDispatcher: NSObject {
    weak var bridgeSwitchboard: BridgeSwitchboard?

    @objc
    public init(bridgeSwitchboard: BridgeSwitchboard?) {
        self.bridgeSwitchboard = bridgeSwitchboard
    }

    typealias CallbackTransform = (BridgeCallback) -> BridgeCallback?

    func dispatch(_ event: CallbackEventType, extension: BrowserExtension, json: Any, transform: CallbackTransform = EventDispatcher.identity) {
        let callbacks = `extension`.callbacks(for: .content, event: event)
        guard  callbacks.count != 0 else {
            Log.error("Native event '\(event)' has no callbacks")
            return
        }

        dispatch(callbacks, json: json, transform: transform)
    }

    func dispatch(_ event: CallbackEventType, json: Any, transform: CallbackTransform = EventDispatcher.identity) {
        dispatch(callbacksFor(event), json: json, transform: transform)
    }

    func dispatch<R: JSParameter>(_ event: CallbackEventType, _ tabId: UInt, _ json: Any, _ completion: (([Result<R>]) -> Void)?) {
        let `extension` = bridgeSwitchboard?.virtualGlobalScopeExtension

        guard let callbacks = `extension`?.callbacksToContent(for: event, andTab: Int(tabId)), callbacks.count != 0 else {
            Log.error("Native event '\(event)' has no callbacks")
            completion?([])
            return
        }

        if let completion = completion {
            dispatch(callbacks, json: json) { (results) in
                completion(results.map { (input) -> Result<R> in
                    switch input {
                    case .success(let output):
                        if let result = R(json: output) {
                            return .success(result)
                        } else {
                            return .failure(NSError(code: .eventResultDidNotMatch, message: "Event result did not match"))
                        }
                    case .failure(let error):
                        return .failure(error)
                    }
                })
            }
        } else {
            dispatch(callbacks, json: json)
        }
    }

    func dispatch<R: JSParameter>(_ callback: BridgeCallback, _ json: Any, _ completion: ((Result<R>) -> Void)? = nil) {
        guard let injector = bridgeSwitchboard?.injector else {
            completion?(.failure(NSError(message: "Injector cannot be used")))
            return
        }

        if let completion = completion {
            injector.call(callback, with: json) { input in
                switch input {
                case .success(let output):
                    if let result = R(json: output) {
                        return completion(.success(result))
                    } else {
                        return completion(.failure(NSError(code: .eventResultDidNotMatch, message: "Event result did not match")))
                    }
                case .failure(let error):
                    return completion(.failure(error))
                }
            }
        } else {
            injector.call(callback, with: json, completion: nil)
        }
    }

    // MARK: - Objc

    @objc
    public func dispatch(_ event: CallbackEventType, extension: BrowserExtension, json: Any) {
        dispatch(event, json: json, transform: EventDispatcher.identity)
    }

    @objc
    public func dispatch(_ event: CallbackEventType, _ json: Any) {
        dispatch(event, json: json, transform: EventDispatcher.identity)
    }

    // MARK: - fileprivate

    fileprivate func dispatch(_ callbacks: [BridgeCallback],
                              json: Any,
                              transform: CallbackTransform = EventDispatcher.identity,
                              completion: (([Result<Any?>]) -> Void)? = nil) {
        guard let injector = bridgeSwitchboard?.injector else {
            Log.error("Injector cannot be used")
            completion?([])
            return
        }

        let listener: MultipleResultsListener<Any?>?
        if let completion = completion {
            listener = MultipleResultsListener(completion: completion)
        } else {
            listener = nil
        }

        for callback in callbacks {
            let completionListener = listener?.createCompletionListener()

            guard let finalCallback = transform(callback) else {
                completionListener?(.failure(NSError(message: "Callback has been discarded")))
                continue
            }

            injector.call(finalCallback, with: json, completion: completionListener)
        }
    }

    fileprivate func callbacksFor(_ event: CallbackEventType) -> [BridgeCallback] {
        Log.debug("Native event '\(event)' \(String(describing: BridgeCallback.eventString(for: event)))")
        assert(Thread.isMainThread, "handleNativeEvent called from background thread")
        // emulate call from content script
        // both background and popup callbacks will be returned

        let delegate = bridgeSwitchboard?.webNavigationDelegate

        if let callbacks = delegate?.arrayOfExtensionUnspecificCallbacks(of: event) as? [BridgeCallback], callbacks.count > 0 {
            return callbacks
        }

        let `extension` = bridgeSwitchboard?.virtualGlobalScopeExtension

        if let callbacks = `extension`?.callbacksToContent(for: event, andTab: NSNotFound), callbacks.count > 0 {
            return callbacks
        }

        Log.debug("Native event '\(event)' has no callbacks")
        return []
    }

    static func identity(_ callback: BridgeCallback) -> BridgeCallback? {
        return callback
    }
}
