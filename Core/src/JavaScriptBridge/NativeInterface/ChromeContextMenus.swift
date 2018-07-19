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

protocol ChromeContextMenusProtocol {
    func create(_ menuId: String, _ parameters: JSObject<JSAny>) throws -> Any?

    func update(_ menuId: String, _ parameters: JSObject<JSAny>) throws -> Any?

    func remove(_ menuIds: JSArray<String>) throws -> Any?
}

struct ChromeContextMenusFactory: StandardHandlerFactory {
    var bridgeContext: JSBridgeContext

    typealias Handler = ChromeContextMenus
}

struct ChromeContextMenus: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension ChromeContextMenus: ChromeContextMenusProtocol {
    func getContextMenuDelegate() throws -> ContextMenuDelegate {
        if let delegate = context.source.bridgeSwitchboard?.contextMenuDelegate {
            return delegate
        } else {
            throw KittCoreError.chromeStorageIsNull
        }
    }

    // MARK: - ChromeContextMenusProtocol

    func create(_ menuId: String, _ parameters: JSObject<JSAny>) throws -> Any? {
        let delegate = try getContextMenuDelegate()
        delegate.onContextMenuCreateId(menuId, withProperties: toDictionary(parameters), from: context.`extension`)
        return nil
    }

    func update(_ menuId: String, _ parameters: JSObject<JSAny>) throws -> Any? {
        let delegate = try getContextMenuDelegate()
        delegate.onContextMenuUpdateId(menuId, withProperties: toDictionary(parameters))
        return nil
    }

    func remove(_ menuIds: JSArray<String>) throws -> Any? {
        let delegate = try getContextMenuDelegate()
        for menuId in menuIds {
            delegate.onContextMenuRemoveId(menuId)
        }
        return nil
    }
}

func registerChromeContextMenusHandlers<F>(_ dispatcher: CommandDispatcher,
                                           withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeContextMenusProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.create, forName: "contextMenus.create")
    dispatcher.register(factory, handler: Handler.update, forName: "contextMenus.update")
    dispatcher.register(factory, handler: Handler.remove, forName: "contextMenus.remove")
}
