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

struct CreateProperties: JSObjectConvertibleParameter {
    var windowId: UInt?
    var index: Int?
    var url: String?
    var active: Bool?

    init?(object: [AnyHashable: Any]) {
        windowId = object["windowId"] as? UInt
        index = object["index"] as? Int
        url = object["url"] as? String
        active = object["active"] as? Bool
    }
}

struct UpdateProperties: JSObjectConvertibleParameter {
    var url: String?

    init?(object: [AnyHashable: Any]) {
        url = object["url"] as? String
    }
}

struct QueryProperties: JSObjectConvertibleParameter {
    var active: Bool?

    init?(object: [AnyHashable: Any]) {
        active = object["active"] as? Bool
    }
}

protocol ChromeTabsProtocol {
    // MARK: - JS Interface

    func get(_ tabId: UInt) throws -> Any?

    func query(_ properties: QueryProperties) throws -> Any?

    func create(_ createProperties: CreateProperties) throws -> Any?

    func update(_ tabId: UInt, _ updateProperties: UpdateProperties) throws -> Any?

    func remove(_ tabIds: JSArray<UInt>) throws -> Any?

    func sendMessage(_ tabId: UInt, _ message: JSAny/*, object options*/, _ completion: StandardCompletion?) throws
}

extension ChromeTabsProtocol {
    func remove_1(_ tabId: UInt) throws -> Any? {
        return try remove([tabId])
    }
}

struct ChromeTabsFactory: StandardHandlerFactory {
    typealias Handler = ChromeTabs

    let bridgeContext: JSBridgeContext
}

struct ChromeTabs: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext

    var chrome: Chrome {
        return context.chrome
    }
}

extension ChromeTabs: ChromeTabsProtocol {
    // MARK: - ChromeTabsProtocol

    func get(_ tabId: UInt) throws -> Any? {
        if let (index, tab) = chrome.findTab(tabId) {
            return tab.chromeTabObjectWithIndex(index)
        } else {
            // Chrome interface asking for tab which does not exist anymore (was removed)
            throw IgnorableError(with: CodeRelatedError(
                KittCoreError.chromeTabNotFound, message: "Tab with '\(index)' hasn't been found"))
        }
    }

    func query(_ properties: QueryProperties) throws -> Any? {
        return chrome.windows
            .map { $0.typedTabs.enumerated() }
            .joined()
            .filter { _, tab in
                if let active = properties.active {
                    return tab.active == active
                } else {
                    return true
                }
            }
            .map { index, tab in
                return tab.chromeTabObjectWithIndex(index)
            }
    }

    func create(_ createProperties: CreateProperties) throws -> Any? {
        let window: ChromeWindow
        if let uwId = createProperties.windowId, let uwWindow = chrome[uwId] {
            window = uwWindow
        } else if let uwWindow = context.sourceWindow {
            window = uwWindow
        } else {
            window = chrome.focusedWindow!
        }

        // "value will be clamped to between zero and the number of tabs in the window"
        // index parameter is optional but Google doesn't document where the new tab
        // should be when index isn't defined. Guessing from Chrome behavior, the last one.
        // Because NSNotFound is big positive number, it will get clamped to the last one.
        let index = max(0, min(window.tabs.count, createProperties.index ?? window.tabs.count))

        let url: URL?
        if let urlString = createProperties.url {
            url = URL(string: urlString)
        } else {
            url = nil
        }

        let tab = window.add(tabWithURL: url, atIndex: index)

        if let tab = tab, let active = createProperties.active, active {
            window.focused = true
            tab.active = true
        }

        return tab?.chromeTabObjectWithIndex(index)
    }

    func update(_ tabId: UInt, _ updateProperties: UpdateProperties) throws -> Any? {
        if let (index, tab) = chrome.findTab(tabId) {
            if let urlString = updateProperties.url, let url = URL(string: urlString) {
                // Is requested view active?
                if tab.active && tab.window.focused {
                    context.source.bridgeSwitchboard?.browserControlDelegate?.load(url)
                } else {
                    tab.URL = url as NSURL?
                }
            }
            return tab.chromeTabObjectWithIndex(index)
        } else {
            // Chrome interface asking for tab which does not exist anymore (was removed)
            throw IgnorableError(with: CodeRelatedError(
                KittCoreError.chromeTabNotFound, message: "Tab with '\(index)' hasn't been found"))
        }
    }

    func remove(_ tabIds: JSArray<UInt>) throws -> Any? {
        for window in chrome.windows {
            var tabsToRemove = [ChromeTab]()

            for tab in window.tabs.lazy.compactMap({ $0 as? ChromeTab }) {
                if tabIds.contains(tab.identifier) {
                    // tab to be removed
                    tabsToRemove.append(tab)
                }
            }

            window.remove(tabs: tabsToRemove)

            let tab: ChromeTab

            if let uwTab = chrome.focusedWindow?.activeTab {
                tab = uwTab
            } else if let uwTab = chrome.windows.compactMap({ $0.activeTab }).first {
                tab = uwTab
            } else if let uwTab = chrome.windows.compactMap({ Array($0.typedTabs.suffix(1)).first }).first {
                tab = uwTab
            } else {
                context.source.bridgeSwitchboard?.browserControlDelegate?.showNewTab(with: nil, fromSource: nil)
                return nil
            }

            tab.window.focused = true
            tab.active = true
        }

        return nil
    }

    func sendMessage(_ tabId: UInt, _ message: JSAny/*, object options*/, _ completion: StandardCompletion?) throws {
        let callbacks = context.`extension`.callbacksToContent(for: .runtimeMessage, andTab: Int(tabId))
        dispatch(callbacks, message: message.any, completion: { result in
            if case let .failure(error) = result, error._code == KittCoreErrorCode.chromeMessageCallbackNotFound.rawValue {
                completion?(.failure(IgnorableError(with: error)))
            } else {
                completion?(result)
            }
        })
    }

    // MARK: - fileprivate
}

func registerChromeTabsHandlers<F>(_ dispatcher: CommandDispatcher, withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeTabsProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.get, forName: "tabs.get")
    dispatcher.register(factory, handler: Handler.query, forName: "tabs.query")
    dispatcher.register(factory, handler: Handler.create, forName: "tabs.create")
    dispatcher.register(factory, handler: Handler.update, forName: "tabs.update")
    dispatcher.register(factory, handler: Handler.remove, forName: "tabs.remove")
    dispatcher.register(factory, handler: Handler.remove_1, forName: "tabs.remove")
    dispatcher.register(factory, handler: Handler.sendMessage, forName: "tabs.sendMessage")
}
