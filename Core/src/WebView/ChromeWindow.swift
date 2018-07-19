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

private let kSessionWindowId = "KittWindow"

@objc protocol ChromeWindowDataProtocol {
    var identifier: NSNumber? { get set }
    var tabs: NSOrderedSet? { get set }
}

protocol ChromeWindowDataProtocolEx: ChromeWindowDataProtocol, NSObjectProtocol {
    associatedtype ChromeTabDataType

    static func addTabData<W>
        (_ window: W, withURL: URL?, atIndex: Int) -> ChromeTabDataType? where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == Self

    static func moveTabData<W>
        (_ window: W, fromPosition: Int, toPosition: Int) -> Bool where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == Self

    static func deleteTabDatas<W>
        (_ window: W, _ data: [ChromeTabDataType]) -> Bool where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == Self
}

protocol ChromeWindowExProtocol {
    associatedtype WindowDataType

    var windowDataEx: WindowDataType { get }
}

@objc
open class ChromeWindow: NSObject {
    open let identifier: UInt

    open unowned let chrome: Chrome

    open let incognito: Bool

    @objc dynamic open internal(set) var tabs: NSArray = []

    open var typedTabs: LazyMapSequence<NSArray, ChromeTab> {
        // swiftlint:disable:next force_cast
        return tabs.lazy.map {$0 as! ChromeTab}
    }

    @objc dynamic open internal(set) var activeTab: ChromeTab? {
        didSet {
            if activeTab != oldValue {
                oldValue?.active = false

                if let tab = activeTab {
                    let index = tabs.index(of: tab)
                    assert(index != NSNotFound, "Tab with identifier \(tab.identifier) not found in tabs")
                    chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnActivated, tab.chromeTabObjectWithIndex(index))
                }
                chrome.hibernateOldest()
            }
        }
    }

    @objc dynamic open var focused: Bool {
        didSet {
            if focused != oldValue && focused {
                chrome.focusedWindow = self
            }
        }
    }

    open func add(tabWithURL: URL?, atIndex index: Int = NSNotFound) -> ChromeTab? {
        return nil
    }

    @discardableResult
    open func remove(tab: ChromeTab) -> Bool {
        return false
    }

    @discardableResult
    open func remove(tabs tabsToRemove: [ChromeTab]) -> Bool {
        return false
    }

    @discardableResult
    open func moveTab(fromPosition: Int, toPosition: Int) -> Bool {
        return false
    }

    open func makeActiveTabNewest() {
        activeTab?.tabData?.activityTimestamp = Date()
        chrome.hibernateOldest()
        setNeedsCommit()
    }

    open var historyManager: BrowserHistoryManager?

    let windowData: ChromeWindowDataProtocol

    // MARK: - Internal

    init(chrome: Chrome,
         identifier: UInt,
         windowData: ChromeWindowDataProtocol,
         historyManager: BrowserHistoryManager?,
         incognito: Bool) {
        self.chrome = chrome
        self.identifier = identifier
        self.windowData = windowData
        self.historyManager = historyManager
        self.incognito = incognito
        self.focused = false
        super.init()
    }

    final func tabsAsObjects() -> [[String: Any]] {
        return typedTabs.enumerated().map { tab in
            return tab.element.chromeTabObjectWithIndex(tab.offset)
        }
    }

    final func chromeWindowObject(_ populate: Bool) -> [String: Any] {
        var chromeWindowObject = [
            "id": identifier,
            "focused": focused,
            // @todo real size if it is ever needed
            "top": 0,
            "left": 0,
            "width": 320,
            "height": 480,
            "incognito": incognito,
            "type": "normal", // @todo normal/popup/panel/app?
            "state": "fullscreen",
            "alwaysOnTop": false,
            "sessionId": kSessionWindowId
            ] as [String: Any]

        if populate {
            chromeWindowObject["tabs"] = tabsAsObjects()
        }

        return chromeWindowObject
    }

    func setNeedsCommit() {
    }

    public class final func findActiveTab<TabsCollection>(_ tabs: TabsCollection) -> ChromeTab?
        where TabsCollection: Collection, TabsCollection.Iterator.Element: ChromeTab {
        if let tab = tabs.first {
            return tabs.reduce(tab) { activeTab, tab -> ChromeTab in
                activeTab.fresher(than: tab) ? activeTab : tab
            }
        } else {
            return nil
        }
    }
}
