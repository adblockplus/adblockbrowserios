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

import UIKit

private let tabHibernationThreshold = 2

public struct ChromeWindowOptions: OptionSet {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let Persistent = ChromeWindowOptions(rawValue: 1 << 0)
    public static let Incognito = ChromeWindowOptions(rawValue: 1 << 1)
    public static let ZeroTabsAllowed = ChromeWindowOptions(rawValue: 1 << 2)
}

@objc
public final class Chrome: NSObject {
    @objc public static var sharedInstance: Chrome!

    public var mainWindow: ChromeWindow!

    public var incognitoWindow: ChromeWindow?

    /// This property will contain only 1-2 windows,
    /// one regular and one incognito. It does not make sense,
    /// to have more windows.
    public fileprivate(set) var windows = [ChromeWindow]()
    public let coreData: BrowserStateCoreData
    public let historyManager: BrowserHistoryManager?
    // swiftlint:disable:next weak_delegate
    public let commandDelegate: NativeActionCommandDelegate?

    @objc dynamic public internal(set) var focusedWindow: ChromeWindow? {
        didSet {
            if focusedWindow != oldValue {
                oldValue?.focused = false
            }
        }
    }

    public subscript(windowId: UInt) -> ChromeWindow? {
        return windows.lazy.filter { $0.identifier == windowId }.first
    }

    public func findTab(_ identifier: UInt) -> (Int, ChromeTab)? {
        for window in windows.lazy {
            for (index, tab) in window.tabs.lazy.compactMap({ $0 as? ChromeTab }).enumerated() where tab.identifier == identifier {
                return (index, tab)
            }
        }
        return nil
    }

    public func prune() {
        for window in windows {
            for tab in window.tabs {
                if let tab = tab as? ChromeTab, focusedWindow != window || window.activeTab != tab {
                    tab.hibernate()
                }
            }
        }
    }

    public init?(coreData: BrowserStateCoreData,
                 andHistoryManager historyManager: BrowserHistoryManager? = nil,
                 commandDelegate: NativeActionCommandDelegate? = nil,
                 incognitoWindow: Bool = false) {
        self.coreData = coreData
        self.historyManager = historyManager
        self.commandDelegate = commandDelegate
        super.init()

        guard let window = add(windowWithIdentifier: 0, historyManager: historyManager, windowOptions: .Persistent) else {
            return nil
        }

        mainWindow = window
        focusedWindow = window

        if incognitoWindow {
            let window = add(windowWithIdentifier: 1, historyManager: historyManager, windowOptions: [.Incognito, .ZeroTabsAllowed])
            self.incognitoWindow = window
        }
    }

    public init?(coreData: BrowserStateCoreData,
                 andHistoryManager historyManager: BrowserHistoryManager? = nil,
                 commandDelegate: NativeActionCommandDelegate? = nil,
                 options: [ChromeWindowOptions]) {
        self.coreData = coreData
        self.historyManager = historyManager
        self.commandDelegate = commandDelegate
        super.init()

        var first = true
        for (identifier, windowOptions) in options.enumerated() {
            guard let window = add(windowWithIdentifier: UInt(identifier), historyManager: historyManager, windowOptions: windowOptions) else {
                return nil
            }

            if first {
                mainWindow = window
                focusedWindow = window
                first = false
            }

            if window.incognito {
                incognitoWindow = window
            }
        }
    }

    // MARK: - Load Favicon

    func createFaviconLoader(_ delegate: FaviconLoadingDelegate?) -> SAWebViewFaviconLoader {
        return SAWebViewFaviconLoader(delegate: delegate, historyManager: historyManager)
    }

    fileprivate func add(windowWithIdentifier identifier: UInt,
                         historyManager: BrowserHistoryManager?,
                         windowOptions: ChromeWindowOptions) -> ChromeWindow? {
        let incognito = windowOptions.contains(.Incognito)
        let historyManager = incognito ? nil : historyManager
        let window: ChromeWindow
        if !windowOptions.contains(.Persistent) {
            let windowData = ChromeWindowDataMemory(identifier: Int32(identifier))
            window = ChromeWindowEx(chrome: self,
                                    identifier: identifier,
                                    windowDataEx: windowData,
                                    historyManager: historyManager,
                                    incognito: incognito)
        } else {
            let predicate = NSPredicate(format: "identifier = \(identifier)")
            let windowDatas: [ChromeWindowData]? = coreData.fetch(predicate)

            let windowData: ChromeWindowData

            if windowDatas == nil {
                return nil // Failure, alert has been displayed
            } else if let uwWindowData = windowDatas?.first {
                windowData = uwWindowData
            } else if let uwWindowData: ChromeWindowData = coreData.createObject() {
                uwWindowData.identifier = NSNumber(value: identifier)
                if !coreData.saveContextWithErrorAlert() {
                    return nil
                }
                windowData = uwWindowData
            } else {
                return nil
            }

            window = ChromeWindowEx(chrome: self,
                                    identifier: identifier,
                                    windowDataEx: windowData,
                                    historyManager: historyManager,
                                    incognito: incognito)

            if !windowOptions.contains(.ZeroTabsAllowed) && window.tabs.count == 0 {
                let tab = window.add(tabWithURL: nil)
                tab?.active = true // The first tab should be active
                assert(tab != nil)
            }
        }

        windows.append(window)
        return window
    }

    func hibernateOldest() {
        let newestAlive = windows
            .map { $0.typedTabs }
            .joined()
            .filter {
                let hasDummyURL = $0.URL?.shouldBeHidden() ?? true
                let isNotHibernated = !$0.hibernated || ($0.active && $0.window.focused)
                return !hasDummyURL && isNotHibernated
            }
            .sorted {
                $0.fresher(than: $1)
            }

        if newestAlive.count > tabHibernationThreshold {
            for tab in newestAlive[tabHibernationThreshold..<newestAlive.count] {
                tab.hibernate()
            }
        }
    }

    // MARK: - WebView quering

    private let lock = NSLock()

    @inline(__always)
    private func synchronized<R>(_ block: () throws -> R ) rethrows -> R {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try block()
    }

    private var tabIdToWebView = [UInt: ContentWebView]()

    func set(webView: ContentWebView, forTabId tabId: UInt) {
        synchronized {
            tabIdToWebView[tabId] = webView
        }
    }

    func removeWebView(forTabId tabId: UInt) {
        synchronized {
            _ = tabIdToWebView.removeValue(forKey: tabId)
        }
    }

    @objc
    public func findContentWebView(_ tabId: UInt) -> ContentWebView? {
        return synchronized {
            return tabIdToWebView[tabId]
        }
    }
}
