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

struct ChromeWindowsGetInfo: JSObjectConvertibleParameter {
    let populate: Bool?

    init?(object: [AnyHashable: Any]) {
        populate = object["populate"] as? Bool
    }
}

protocol ChromeWindowsProtocol {
    func getLastFocused(_ getInfo: ChromeWindowsGetInfo) throws -> Any?

    func getAll(_ getInfo: ChromeWindowsGetInfo) throws -> Any?
}

struct ChromeWindowsFactory: StandardHandlerFactory {
    typealias Handler = ChromeWindows

    let bridgeContext: JSBridgeContext
}

struct ChromeWindows: StandardHandler {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension ChromeWindows: ChromeWindowsProtocol {
    func getLastFocused(_ getInfo: ChromeWindowsGetInfo) throws -> Any? {
        return context.chrome.focusedWindow?.chromeWindowObject(getInfo.populate ?? false)
    }

    func getAll(_ getInfo: ChromeWindowsGetInfo) throws -> Any? {
        return context.chrome.windows.map { $0.chromeWindowObject(getInfo.populate ?? false) }
    }
}

func registerChromeWindowsHandlers<F>(_ dispatcher: CommandDispatcher,
                                      withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeWindowsProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.getAll, forName: "windows.getAll")
    dispatcher.register(factory, handler: Handler.getLastFocused, forName: "windows.getLastFocused")
}
