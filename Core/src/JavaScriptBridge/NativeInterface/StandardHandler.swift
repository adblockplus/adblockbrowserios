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

protocol StandardHandlerFactory: HandlerFactory where Handler: StandardHandler {
    var bridgeContext: JSBridgeContext { get }
}

extension StandardHandlerFactory {
    func create(_ context: CommandDispatcherContext) -> Handler {
        return Handler(context: context, bridgeContext: bridgeContext)
    }
}

protocol StandardHandler {
    var context: CommandDispatcherContext { get }
    var bridgeContext: JSBridgeContext { get }

    init(context: CommandDispatcherContext, bridgeContext: JSBridgeContext)
}

func standardHandlerRegisters(_ bridgeContext: JSBridgeContext) -> [String: (CommandDispatcher) -> Void] {
    return [
        "browserAction": { dispatcher in
            registerChromeBrowserActionHandlers(dispatcher, withFactory: ChromeBrowserActionFactory(bridgeContext: bridgeContext))
        },
        "tabs": { dispatcher in
            registerChromeTabsHandlers(dispatcher, withFactory: ChromeTabsFactory(bridgeContext: bridgeContext))
        },
        "storage": { dispatcher in
            registerChromeStorageAreaHandlers(dispatcher, withFactory: ChromeStorageAreaFactory(bridgeContext: bridgeContext))
        },
        "webNavigation": { dispatcher in
            registerChromeWebNavigationHandlers(dispatcher, withFactory: ChromeWebNavigationFactory(bridgeContext: bridgeContext))
        },
        "webRequest": { dispatcher in
            registerChromeWebRequestHandlers(dispatcher, withFactory: ChromeWebRequestFactory(bridgeContext: bridgeContext))
        },
        "windows": { dispatcher in
            registerChromeWindowsHandlers(dispatcher, withFactory: ChromeWindowsFactory(bridgeContext: bridgeContext))
        },
        "runtime": { dispatcher in
            registerChromeRuntimeHandlers(dispatcher, withFactory: ChromeRuntimeFactory(bridgeContext: bridgeContext))
        },
        "core": { dispatcher in
            registerKittCoreHandlers(dispatcher, withFactory: KittCoreFactory(bridgeContext: bridgeContext))
        },
        "autofill": { dispatcher in
            registerChromeAutofillHandlers(dispatcher, withFactory: ChromeAutofillFactory(bridgeContext: bridgeContext))
        },
        "contextMenus": { dispatcher in
            registerChromeContextMenusHandlers(dispatcher, withFactory: ChromeContextMenusFactory(bridgeContext: bridgeContext))
        },
        "listenerStorage": { dispatcher in
            registerEventListenerStorageHandlers(dispatcher, withFactory: EventListenerStorageFactory(bridgeContext: bridgeContext))
        }
    ]
}

extension CommandDispatcher {
    @objc
    public convenience init(bridgeContext: JSBridgeContext) {
        self.init(handlers: standardHandlerRegisters(bridgeContext))
    }
}
