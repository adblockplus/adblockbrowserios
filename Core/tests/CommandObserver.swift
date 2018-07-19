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
@testable import KittCore

final class CommandObserver: HandlerFactory {
    typealias Handler = CommandObserverHandler

    let bridgeContext: JSBridgeContext

    init(bridgeContext: JSBridgeContext) {
        self.bridgeContext = bridgeContext
    }

    func create(context: CommandDispatcherContext) -> Handler {
        return CommandObserverHandler(commandObserver: self,
                                      chromeTabs: ChromeTabs(context: context, bridgeContext: bridgeContext),
                                      chromeRuntime: ChromeRuntime(context: context, bridgeContext: bridgeContext),
                                      kittCore: KittCore(context: context, bridgeContext: bridgeContext))
    }

    typealias MessageHandler = MessageType -> Bool

    var messageCallbacks = [MessageHandler]()

    typealias WindowActionHandler = (WindowActionType) -> Bool

    var windowActionCallbacks = [WindowActionHandler]()

    typealias HistoryHandler = (Html5HistoryEventType, AnyObject?) -> Bool

    var historyHandlers = [HistoryHandler]()

    func attach(switchboard: BridgeSwitchboard) {
        var handlers = standardHandlerRegisters(bridgeContext)
        handlers["tabs"] = { dispatcher in
            registerChromeTabsHandlers(dispatcher, withFactory: self)
        }
        handlers["runtime"] = { dispatcher in
            registerChromeRuntimeHandlers(dispatcher, withFactory: self)
        }
        handlers["core"] = { dispatcher in
            registerKittCoreHandlers(dispatcher, withFactory: self)
        }
        switchboard.dispatcher = CommandDispatcher(handlers: handlers)
    }

    func dettach(switchboard: BridgeSwitchboard) {
        switchboard.dispatcher = CommandDispatcher(bridgeContext: switchboard.bridgeContext)
    }
}

enum WindowActionType {
    case open
    case close
}

enum MessageType {
    case tabs(UInt, AnyObject?)
    case runtime(AnyObject?)
    case response(String, AnyObject?)
}

struct CommandObserverHandler: ChromeRuntimeProtocol, ChromeTabsProtocol, KittCoreProtocol {
    let commandObserver: CommandObserver
    let chromeTabs: ChromeTabs
    let chromeRuntime: ChromeRuntime
    let kittCore: KittCore

    // MARK: - ChromeRuntimeProtocol

    func sendMessage(extensionId: JSOptional<String>, _ message: JSAny/*, object options*/, _ completion: StandardCompletion?) throws {
        for callback in commandObserver.messageCallbacks {
            if callback(.Runtime(message.any)) {
                completion?(.Failure(NSError(domain: "", code: 0, userInfo: nil)))
                return
            }
        }
        try chromeRuntime.sendMessage(extensionId, message, completion)
    }

    // MARK: - ChromeTabsProtocol

    func get(tabId: UInt) throws -> AnyObject? {
        return try chromeTabs.get(tabId)
    }

    func query(properties: QueryProperties) throws -> AnyObject? {
        return try chromeTabs.query(properties)
    }

    func create(createProperties: CreateProperties) throws -> AnyObject? {
        return try chromeTabs.create(createProperties)
    }

    func update(tabId: UInt, _ updateProperties: UpdateProperties) throws -> AnyObject? {
        return try chromeTabs.update(tabId, updateProperties)
    }

    func remove(tabIds: JSArray<UInt>) throws -> AnyObject? {
        return try chromeTabs.remove(tabIds)
    }

    func sendMessage(tabId: UInt, _ message: JSAny/*, object options*/, _ completion: StandardCompletion?) throws {
        for callback in commandObserver.messageCallbacks {
            if callback(.Tabs(tabId, message.any)) {
                completion?(.Failure(NSError(domain: "", code: 0, userInfo: nil)))
                return
            }
        }
        try chromeTabs.sendMessage(tabId, message, completion)
    }

    // MARK: - KittCoreProtocol

    func log(json: JSAny) throws -> AnyObject? {
        return try kittCore.log(json)
    }

    func response(callbackId: String, _ message: JSAny) throws -> AnyObject? {
        for callback in commandObserver.messageCallbacks {
            if callback(.Response(callbackId, message.any)) {
                throw NSError(domain: "", code: 0, userInfo: nil)
            }
        }
        return try kittCore.response(callbackId, message)
    }

    func onHistoryEvent(type: Html5HistoryEventType, _ object: JSAny) throws -> AnyObject? {
        for callback in commandObserver.historyHandlers {
            if callback(type, object.any) {
                throw NSError(domain: "", code: 0, userInfo: nil)
            }
        }
        return try kittCore.onHistoryEvent(type, object)
    }

    func open(parameter: JSAny) throws -> AnyObject? {
        for callback in commandObserver.windowActionCallbacks {
            if callback(.open) {
                throw NSError(domain: "", code: 0, userInfo: nil)
            }
        }
        return try kittCore.open(parameter)
    }

    func close() throws -> AnyObject? {
        for callback in commandObserver.windowActionCallbacks {
            if callback(.close) {
                throw NSError(domain: "", code: 0, userInfo: nil)
            }
        }
        return try kittCore.close()
    }

    func sendXMLHTTPRequest(parameters: JSObject<JSAnyObject>, _ completion: StandardCompletion?) throws {
        try kittCore.sendXMLHTTPRequest(parameters, completion)
    }

    func addWebRequestRules(parameters: JSArray<JSAnyObject>) throws -> AnyObject? {
        return try kittCore.addWebRequestRules(parameters)
    }
}
