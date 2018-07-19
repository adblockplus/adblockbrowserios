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

protocol ChromeWebRequestProtocol {
    func handlerBehaviorChanged() throws -> Any?
}

struct ChromeWebRequestFactory: StandardHandlerFactory {
    var bridgeContext: JSBridgeContext

    typealias Handler = ChromeWebRequest
}

struct ChromeWebRequest: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension ChromeWebRequest: ChromeWebRequestProtocol {
    func handlerBehaviorChanged() throws -> Any? {
        URLCache.shared.removeAllCachedResponses()
        return nil
    }
}

func registerChromeWebRequestHandlers<F>(_ dispatcher: CommandDispatcher,
                                         withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeWebRequestProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.handlerBehaviorChanged, forName: "webRequest.handlerBehaviorChanged")
}
