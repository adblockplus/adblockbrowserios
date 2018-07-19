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

extension String: Error {
}

struct MinimalBrowser {
    let extensionUnpacker: ExtensionUnpacker
    let historyManager: BrowserHistoryManager
    let bridgeSwitchboard: BridgeSwitchboard
    let injectorReporter: JSInjectorReporter
    let browserStateModel: BrowserStateModel
    let backgroundContext: ExtensionBackgroundContext
    let contextMenuProvider: ContextMenuProvider
    let ruleActionFactory: RuleActionFactory
    let browserStateData: BrowserStateCoreData

    init() throws {
        Settings.configureTestEnviroment()
        if !Settings.testLaunchOptions([:], contains: nil) {
            throw "Test launch options failed"
        }

        browserStateData = BrowserStateCoreData()

        try? FileManager.default.removeItem(at: browserStateData.storeURL())
        var storeCreated: ObjCBool = false
        guard browserStateData.succeededStoreSetup(withFeedback: &storeCreated) else {
            throw "CoreData store setup failed"
        }

        // ABP extension requires webView with custom user agent, otherwise it will crash on multiplace places.
        // (The extension is expecting, that it is running in Chrome.)
        TabIdCodec.prepareNextWebViewForTabId(0)

        URLProtocol.registerClass(ProtocolHandlerChromeExt.self)
        URLProtocol.registerClass(ProtocolHandlerJSBridge.self)

        historyManager = BrowserHistoryManager(coreData: browserStateData)
        bridgeSwitchboard = BridgeSwitchboard()

        extensionUnpacker = ExtensionUnpacker()
        injectorReporter = JSInjectorReporter()

        bridgeSwitchboard.injector = injectorReporter
        browserStateModel = BrowserStateModel(switchboard: bridgeSwitchboard,
                                              persistence: browserStateData,
                                              bundleUnpacker: extensionUnpacker,
                                              jsInjector: injectorReporter)!

        bridgeSwitchboard.webNavigationDelegate = browserStateModel

        backgroundContext = ExtensionBackgroundContext(switchboard: bridgeSwitchboard, jsInjector: injectorReporter)!
        contextMenuProvider = ContextMenuProvider(commandDelegate: bridgeSwitchboard)!
        bridgeSwitchboard.contextMenuDelegate = contextMenuProvider
        // set up command handler factory
        ruleActionFactory = RuleActionFactory(commandDelegate: bridgeSwitchboard)
        // subscribe data browserStateModel observers
        browserStateModel.subscribe(backgroundContext)
        browserStateModel.subscribe(WebRequestEventDispatcher.sharedInstance())

        let options: [ChromeWindowOptions] = [.Persistent]

        guard let chrome = Chrome(coreData: browserStateData,
                                  andHistoryManager: historyManager,
                                  commandDelegate: bridgeSwitchboard,
                                  options: options) else {
            throw "Chrome not instantiated"
        }

        Chrome.sharedInstance = chrome
        bridgeSwitchboard.ruleActionFactory = ruleActionFactory

        // Load test extension
        backgroundContext.skipInitialScriptLoad = true
    }
}
