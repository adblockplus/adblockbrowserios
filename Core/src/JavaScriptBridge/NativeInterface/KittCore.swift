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

protocol KittCoreProtocol {
    func log(_ message: JSAny) throws -> Any?

    func response(_ callbackId: String, _ message: JSAny) throws -> Any?

    func onHistoryEvent(_ type: Html5HistoryEventType, _ object: JSAny) throws -> Any?

    func open(_ parameter: JSAny) throws -> Any?

    func close() throws -> Any?

    func sendXMLHTTPRequest(_ parameters: JSObject<JSAny>, _ completion: StandardCompletion?) throws

    func addWebRequestRules(_ parameters: JSArray<JSAny>) throws -> Any?
}

struct KittCoreFactory: StandardHandlerFactory {
    typealias Handler = KittCore

    let bridgeContext: JSBridgeContext
}

struct KittCore: StandardHandler {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension KittCore: KittCoreProtocol {
    func log(_ json: JSAny) throws -> Any? {
        let message = json.any
        guard !(message is NSNull) else {
            Log.error("JS logging malformed parameter \(json.any)")
            return nil
        }

        #if DEBUG
            let extensionId = context.`extension`.extensionId
            let tabId = (context.source as? SAContentWebView)?.identifier ?? 0
            let originDescription = Utils.callbackOriginDescription(context.source.origin) ?? ""
            let messageString = "\(message)"

            Log.debug("\(extensionId)|\(originDescription)-\(tabId)|\(messageString)")
        #endif
        return nil
    }

    func response(_ callbackId: String, _ message: JSAny) throws -> Any?
    {
        if let response = bridgeContext.take(callbackId) {
            response(.success(message.any))
            return true
        } else {
            // swiftlint:disable:next line_length
            Log.error("Cannot route onMessage listener response, message sender callback id does not exist. Multiple listeners to content script message?")
            return false
        }
    }

    func sendXMLHTTPRequest(_ parameters: JSObject<JSAny>, _ standardCompletion: StandardCompletion?) throws {
        let completion: (Error?, Any?) -> Void
        if let standardCompletion = standardCompletion {
            completion = completionHandler(from: standardCompletion)
        } else {
            completion = { _, _ in }
        }
        let request = XMLHTTPRequest()
        request.sendParameters(toDictionary(parameters),
                               from: context.`extension`,
                               withCompletion: completion)
    }

    func addWebRequestRules(_ parameters: JSArray<JSAny>) throws -> Any? {
        guard let factory = context.source.bridgeSwitchboard?.ruleActionFactory else {
            throw NSError(message: "RuleActionFactory cannot be used!")
        }

        NSObject.addWebRequestRules(parameters.compactMap { $0.any },
                                    from: context.`extension`,
                                    to: factory)
        return nil
    }
}

func registerKittCoreHandlers<F>(_ dispatcher: CommandDispatcher, withFactory factory: F) where F: HandlerFactory, F.Handler: KittCoreProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.log, forName: "core.log")
    dispatcher.register(factory, handler: Handler.response, forName: "core.response")
    dispatcher.register(factory, handler: Handler.onHistoryEvent, forName: "core.html5History")
    dispatcher.register(factory, handler: Handler.open, forName: "core.open")
    dispatcher.register(factory, handler: Handler.close, forName: "core.close")
    dispatcher.register(factory, handler: Handler.sendXMLHTTPRequest, forName: "core.XMLHTTPRequest")
    dispatcher.register(factory, handler: Handler.addWebRequestRules, forName: "core.addWebRequestRules")
}
