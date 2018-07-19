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

protocol ChromeRuntimeProtocol {
    func sendMessage(_ extensionId: JSOptional<String>, _ message: JSAny, _ completion: StandardCompletion?) throws
}

struct ChromeRuntimeFactory: StandardHandlerFactory {
    var bridgeContext: JSBridgeContext

    typealias Handler = ChromeRuntime
}

struct ChromeRuntime: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension ChromeRuntime: ChromeRuntimeProtocol {
    func sendMessage(_ extensionId: JSOptional<String>, _ message: JSAny, _ completion: StandardCompletion?) throws {
        let callbacks = context.`extension`.callbacks(for: .content, event: .runtimeMessage)
        dispatch(callbacks, message: message.any, completion: completion)
    }
}

func registerChromeRuntimeHandlers<F>(_ dispatcher: CommandDispatcher,
                                      withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeRuntimeProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.sendMessage, forName: "runtime.sendMessage")
}
