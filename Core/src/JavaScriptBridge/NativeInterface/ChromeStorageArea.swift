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

protocol ChromeStorageAreaProtocol {
    func get(_ keys: JSArray<String>) throws -> [String: String]?

    func set(_ items: JSObject<String>) throws -> Any?

    func remove(_ keys: JSArray<String>) throws -> Any?

    func clear() throws -> Any?
}

extension ChromeStorageAreaProtocol {
    func get_1(_ key: String) throws -> Any? {
        return try get([key])
    }

    func get_2(_ keys: JSObject<JSAny>) throws -> Any? {
        return try get(JSArray(keys.contents.keys))
    }

    func remove_1(_ key: String) throws -> Any? {
        return try remove([key])
    }
}

struct ChromeStorageAreaFactory: StandardHandlerFactory {
    typealias Handler = ChromeStorageArea

    let bridgeContext: JSBridgeContext
}

struct ChromeStorageArea: StandardHandler, ChromeStorageAreaProtocol {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext

    func getChromeStorage() throws -> ChromeStorageProtocol {
        if let storage = context.`extension`.storage {
            return storage
        } else {
            throw KittCoreError.chromeStorageIsNull
        }
    }

    // MARK: - ChromeStorageAreaProtocol

    func get(_ keys: JSArray<String>) throws -> [String: String]? {
        let storage = try getChromeStorage()
        return try? storage.values(for: keys.contents)
    }

    func set(_ items: JSObject<String>) throws -> Any? {
        let storage = try getChromeStorage()
        try storage.merge(items.contents)
        return nil
    }

    func remove(_ keys: JSArray<String>) throws -> Any? {
        let storage = try getChromeStorage()
        try storage.remove(keys: keys.contents)
        return nil
    }

    func clear() throws -> Any? {
        let storage = try getChromeStorage()
        try storage.clear()
        return nil
    }
}

func registerChromeStorageAreaHandlers<F>(_ dispatcher: CommandDispatcher,
                                          withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeStorageAreaProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.get, forName: "storage.get")
    dispatcher.register(factory, handler: Handler.get_1, forName: "storage.get")
    dispatcher.register(factory, handler: Handler.get_2, forName: "storage.get")
    dispatcher.register(factory, handler: Handler.set, forName: "storage.set")
    dispatcher.register(factory, handler: Handler.remove, forName: "storage.remove")
    dispatcher.register(factory, handler: Handler.remove_1, forName: "storage.remove")
    dispatcher.register(factory, handler: Handler.clear, forName: "storage.clear")
}
