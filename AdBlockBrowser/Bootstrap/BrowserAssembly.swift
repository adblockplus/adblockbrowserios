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

/**
 
 Browser core construction.
 Has no dependency on BrowserController.
 Has no public properties.
 Has single public method which produces a structure of fully set up browser components.
 */

import Foundation

class BrowserAssembly {
    required init() {
        SAContentWebView.swizzleWebViewDelegateMethods()
        UIScrollView.swizzleLayoutMethod()

        ReachabilityCentral.setUp()

        // ABP extension requires webView with custom user agent, otherwise it will crash on multiplace places.
        // (The extension is expecting, that it is running in Chrome.)
        TabIdCodec.prepareNextWebViewForTabId(0)

        URLProtocol.registerClass(URLProtocolWithCookies.self)
        URLProtocol.registerClass(ProtocolHandler.self)
        URLProtocol.registerClass(ProtocolHandlerChromeExt.self)
        URLProtocol.registerClass(ProtocolHandlerJSBridge.self)

        URLCache.shared = RequestFilteringCache()
    }

    // swiftlint:disable:next function_body_length
    func assemble() throws -> ControllerComponents {
        let browserStateData = BrowserStateCoreData()
        var storeCreated: ObjCBool = false
        guard browserStateData.succeededStoreSetup(withFeedback: &storeCreated) else {
            throw BootstrapError.assemblyCoreDataSetup
        }
        // Create default bookmarks, or do nothing if thery already exist
        createDefaultBookmarks(browserStateData, storeCreated: storeCreated.boolValue)

        let historyManager = BrowserHistoryManager(coreData: browserStateData)
        let bridgeSwitchboard = BridgeSwitchboard()

        let extensionBundleUnpacker = ExtensionUnpacker()
        let injectorReporter = JSInjectorReporter()

        bridgeSwitchboard.injector = injectorReporter
        guard let browserStateModel = BrowserStateModel(switchboard: bridgeSwitchboard,
                                                        persistence: browserStateData,
                                                        bundleUnpacker: extensionBundleUnpacker,
                                                        jsInjector: injectorReporter) else {

                                                            throw BootstrapError.unknown
        }

        bridgeSwitchboard.webNavigationDelegate = browserStateModel

        guard let backgroundContext = ExtensionBackgroundContext(switchboard: bridgeSwitchboard, jsInjector: injectorReporter) else {
            throw BootstrapError.unknown
        }

        guard let contextMenuProvider = ContextMenuProvider(commandDelegate: bridgeSwitchboard) else {
            throw BootstrapError.assemblyChromeInstance
        }

        bridgeSwitchboard.contextMenuDelegate = contextMenuProvider
        // set up command handler factory
        let ruleActionFactory = RuleActionFactory(commandDelegate: bridgeSwitchboard)
        // subscribe data model observers
        browserStateModel.subscribe(backgroundContext)
        browserStateModel.subscribe(WebRequestEventDispatcher.sharedInstance())

        let extensionFacade = ABPExtensionFacade(
            model: browserStateModel,
            unpacker: extensionBundleUnpacker,
            backgroundContext: backgroundContext)

        let options: [ChromeWindowOptions] = [.Persistent, .Incognito]

        guard let chrome = Chrome(coreData: browserStateData,
                                  andHistoryManager: historyManager,
                                  commandDelegate: bridgeSwitchboard,
                                  options: options) else {
                                    throw BootstrapError.assemblyChromeInstance
        }

        Chrome.sharedInstance = chrome

        let autocompleteDataSource = createAutocompleteSource(historyManager, chrome: chrome)

        guard let fulltextSearchObserver = FulltextSearchObserver(commandDelegate: bridgeSwitchboard, andChromeWindow: chrome.focusedWindow) else {
            throw BootstrapError.unknown
        }

        fulltextSearchObserver.searchToolBarBottomHeight = FindInPageControl.defaultHeight
        fulltextSearchObserver.matchFocusScrollViewInsets = UIEdgeInsets(top: 30, left: 50, bottom: 50, right: 50)

        guard let tabPreviewPersistence = TabPreviewPersistence(chrome: chrome) else {
            throw BootstrapError.assemblyTabPreviewPersistence
        }

        let isNewVersion = checkVersionBump()

        // We'll keep the next todo around while we investigate its relevance
        // swiftlint:disable:next todo
        // @TODO reinstall UIHandler once Adblock decides how to do it properly
        // https://www.pivotaltracker.com/story/show/100393038
        // extensionFacade?.backgroundContext.uiDelegate = UIHandler(presenting: browser)

        bridgeSwitchboard.ruleActionFactory = ruleActionFactory
        // Load theruleActionFactory extension
        extensionFacade.load(isNewVersion)

        return ControllerComponents(
            bridgeSwitchboard: bridgeSwitchboard,
            browserStateData: browserStateData,
            historyManager: historyManager,
            autocompleteDataSource: autocompleteDataSource,
            browserStateModel: browserStateModel,
            contextMenuProvider: contextMenuProvider,
            extensionFacade: extensionFacade,
            ruleActionFactory: ruleActionFactory,
            tabPreviewPersistence: tabPreviewPersistence,
            fulltextSearchObserver: fulltextSearchObserver,
            chrome: chrome,
            // this is a default initializer so browserController must be provided regardless of optionality
            browserController: nil,
            eventHandlingStatusAccess: nil,
            debugReporting: nil)
    }

    // MARK: - Private

    fileprivate func createAutocompleteSource(_ historyManager: BrowserHistoryManager, chrome: Chrome) -> OmniboxDataSource {
        let autocompleteDataSource = OmniboxDataSource()
        autocompleteDataSource.add(ProviderFindInPage(id: UInt(SuggestionProviderFindInPage.rawValue),
                                                      delegate: autocompleteDataSource,
                                                      chrome: chrome))
        let historyProvider = ProviderHistory(id: UInt(SuggestionProviderHistory.rawValue), delegate: autocompleteDataSource)
        historyProvider.historyManager = historyManager
        autocompleteDataSource.add(historyProvider)
        let ddgProvider = ProviderDuckDuckGo(id: UInt(SuggestionProviderDuckDuckGo.rawValue), delegate: autocompleteDataSource)
        ddgProvider.extraQueryParameters = ["t": "abpbrowser"]
        autocompleteDataSource.add(ddgProvider)
        autocompleteDataSource.add(ProviderGoogle(id: UInt(SuggestionProviderGoogle.rawValue), delegate: autocompleteDataSource))
        autocompleteDataSource.add(ProviderBaidu(id: UInt(SuggestionProviderBaidu.rawValue), delegate: autocompleteDataSource))
        return autocompleteDataSource
    }

    fileprivate func checkVersionBump() -> Bool {
        var isNewVersion = false
        let appVersion = Settings.applicationVersion()
        if let oldVersion = UserDefaults.standard.object(forKey: "version") as? String {
            isNewVersion = oldVersion != appVersion
        }
        UserDefaults.standard.set(appVersion, forKey: "version")
        return isNewVersion
    }

    fileprivate let defaultBookmarksLoaded =  "DefaultBookmarksLoaded"

    fileprivate func createDefaultBookmarks(_ browserStateData: BrowserStateCoreData, storeCreated: Bool) {
        let defaults = UserDefaults.standard
        if storeCreated {
            defaults.set(false, forKey: defaultBookmarksLoaded)
        }

        if defaults.bool(forKey: defaultBookmarksLoaded) {
            return
        }

        let installedBookmarks = [
            (title: "Acceptable Ads Manifesto",
             url: "https://acceptableads.org/",
             favicon: "Acceptableads_org",
             order: Int64(-2)),
            (title: "Adblock Plus",
             url: "https://adblockplus.org/",
             favicon: "Adblockplus_org",
             order: Int64(-1))
        ]

        for installedBookmark in installedBookmarks {
            if let bookmark = browserStateData.insertNewObject(forEntityClass: BookmarkExtras.self) as? BookmarkExtras {
                bookmark.title = installedBookmark.title
                bookmark.url = installedBookmark.url
                bookmark.abp_showInDashboard = true
                bookmark.abp_order = installedBookmark.order
                bookmark.abp_dashboardOrder = installedBookmark.order

                if let image = UIImage(named: installedBookmark.favicon),
                    let icon = browserStateData.insertNewObject(forEntityClass: UrlIcon.self) as? UrlIcon {
                    icon.iconData = UIImagePNGRepresentation(image)
                    icon.iconUrl = "adblockplus://\(installedBookmark.favicon).png"
                    icon.size = NSNumber(value: Int16(image.size.width))
                    bookmark.icon = icon
                }
            }
        }

        if browserStateData.saveContextWithErrorAlert() {
            // Set flag to true, if the saving was successful.
            defaults.set(true, forKey: defaultBookmarksLoaded)
            defaults.synchronize()
        }
    }
}
