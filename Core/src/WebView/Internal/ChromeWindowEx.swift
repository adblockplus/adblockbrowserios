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

final class ChromeWindowEx<T>: ChromeWindow, ChromeWindowExProtocol where T: ChromeWindowDataProtocolEx,
    T.ChromeTabDataType: ChromeTabDataProtocolEx,
    T.ChromeTabDataType.ChromeWindowDataType == T,
    T.ChromeTabDataType: Hashable {
    typealias WindowDataType = T
    typealias ChromeTabDataType = T.ChromeTabDataType

    fileprivate var dirty = false
    var windowDataEx: WindowDataType

    required init(chrome: Chrome,
                  identifier: UInt,
                  windowDataEx: T,
                  historyManager: BrowserHistoryManager?,
                  incognito: Bool) {
        self.windowDataEx = windowDataEx
        super.init(chrome: chrome,
                   identifier: identifier,
                   windowData: windowDataEx,
                   historyManager: historyManager,
                   incognito: incognito)
        // swiftlint:disable:next force_cast
        let tabs = (windowData.tabs?.array as! [ChromeTabDataType]).map { data in
            return ChromeTabEx(window: self, tabDataEx: data)
        }

        let map = tabs.reduce([ChromeTabDataType: ChromeTabEx<ChromeTabDataType>]()) { dict, tab in
            var dict = dict
            if let tabData = tab.tabDataEx {
                dict[tabData] = tab
            }
            return dict
        }

        for tab in tabs {
            if let openerData = tab.tabDataEx?.opener,
                let opener = map[openerData] {
                tab.openerTab = opener
            }
        }

        self.tabs = tabs as NSArray
        self.activeTab = ChromeWindow.findActiveTab(tabs)
    }

    override func add(tabWithURL: URL?, atIndex index: Int = NSNotFound) -> ChromeTab? {
        guard let tabData: ChromeTabDataType = T.addTabData(self, withURL: tabWithURL, atIndex: index) else {
            return nil
        }

        let tab = ChromeTabEx(window: self, tabDataEx: tabData)

        let tabCount: Int
        if index == NSNotFound {
            tabCount = tabs.count
            mutableArrayValue(forKey: "tabs").add(tab)
        } else {
            tabCount = index
            mutableArrayValue(forKey: "tabs").insert(tab, at: index)
        }

        chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnCreated, tab.chromeTabObjectWithIndex(tabCount))

        return tab
    }

    override func remove(tab: ChromeTab) -> Bool {
        guard let tab = tab as? ChromeTabEx<ChromeTabDataType> else {
            return false
        }

        let index = tabs.index(of: tab)

        if index == NSNotFound {
            return false
        }

        guard let tabDataEx = tab.tabDataEx else {
            return false
        }

        // Remove tab from database
        if !T.deleteTabDatas(self, [tabDataEx]) {
            return false
        }
        tab.tabDataEx = nil

        // Notify observers
        chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnRemoved, tab.chromeTabObjectWithIndex(index))

        historyManager?.onDeletedTabId(tab.identifier)

        // Remove tab from array
        mutableArrayValue(forKey: "tabs").remove(tab)

        if activeTab == tab {
            let newActiveTab: ChromeTab?
            // Find new active tab if removed was active
            if let tabs = tabs as? [ChromeTab] {
                newActiveTab = index < tabs.count ? tabs[index] : tabs.last
            } else {
                newActiveTab = nil
            }

            if let tab = newActiveTab {
                tab.active = true
            } else {
                activeTab = nil
            }
        }

        assert(activeTab != tab, "Removed tab must not be active tab")
        assert(activeTab != nil || tabs.count == 0, "Active tab must be set, if tabs array is not empty")
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity
    override func remove(tabs tabsToRemove: [ChromeTab]) -> Bool {
        // Remove tabs from database
        if !T.deleteTabDatas(self, tabsToRemove.compactMap { ($0 as? ChromeTabEx<ChromeTabDataType>)?.tabDataEx }) {
            return false
        }

        for tab in tabsToRemove {
            // Remove observers on webView
            tab.internalWebView = nil
            // Remove managed object reference
            (tab as? ChromeTabEx<ChromeTabDataType>)?.tabDataEx = nil
        }

        // Notify observers
        for tab in tabsToRemove {
            let index = tabs.index(of: tab)
            assert(index != NSNotFound, "Tab with identifier \(tab.identifier) not found in tabs")
            chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnRemoved, tab.chromeTabObjectWithIndex(index))
            historyManager?.onDeletedTabId(tab.identifier)
        }

        // Find active tab
        var newActiveTab: ChromeTab? = nil

        if let tab = activeTab, tabsToRemove.contains(tab) {
            // Try to find nearest tab to active tab
            let index = tabs.index(of: tab)
            let set = Set(tabsToRemove)

            for tabIndex in index..<tabs.count {
                if let tab = tabs[tabIndex] as? ChromeTab, !set.contains(tab) {
                    newActiveTab = tab
                    break
                }
            }

            if newActiveTab == nil {
                for tabIndex in (0..<index).reversed() {
                    if let tab = tabs[tabIndex] as? ChromeTab, !set.contains(tab) {
                        newActiveTab = tab
                        break
                    }
                }
            }
        } else {
            newActiveTab = activeTab
        }

        // Remove tab from array
        mutableArrayValue(forKey: "tabs").removeObjects(in: tabsToRemove)

        // Set new active tab
        if activeTab != newActiveTab {
            if let tab = newActiveTab {
                tab.active = true
            } else {
                activeTab = nil
            }
        }

        return true
    }

    override func moveTab(fromPosition: Int, toPosition: Int) -> Bool {
        if fromPosition == toPosition {
            return true
        }

        if !T.moveTabData(self, fromPosition: fromPosition, toPosition: toPosition) {
            return false
        }

        let tabs = mutableArrayValue(forKey: "tabs")

        // KVO does not support moving elements.
        // This limitation is fixed by using replacing element in moved range.
        let range = NSRange(location: min(fromPosition, toPosition), length: abs(toPosition - fromPosition) + 1)
        var changedTabs = tabs.subarray(with: range)

        // Move tab to new position
        if toPosition > fromPosition {
            let tab = changedTabs.remove(at: 0)
            changedTabs.append(tab)
        } else {
            let tab = changedTabs.remove(at: changedTabs.count - 1)
            changedTabs.insert(tab, at: 0)
        }

        // Range must be converted to indexSet, do not use range directly.
        let indexSet = IndexSet(integersIn: Range(range) ?? 0..<0)
        tabs.replaceObjects(at: indexSet, with: changedTabs)

        let json = ["windowId": identifier, "fromIndex": fromPosition, "toIndex": toPosition] as [String: Any]
        chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnMoved, json)

        return true
    }

    override func setNeedsCommit() {
        if !dirty {
            DispatchQueue.main.async { () -> Void in
                for item in self.tabs.enumerated() {
                    if let tab = item.element as? ChromeTab, tab.updatedProperties != .None {

                        let object = tab.chromeTabObjectWithIndex(item.offset)

                        var changeInfo = [String: Any]()

                        if tab.updatedProperties.contains(.Status) {
                            changeInfo["status"] = object["status"]
                        }

                        if tab.updatedProperties.contains(.Url) {
                            changeInfo["url"] = object["url"]
                        }

                        if tab.updatedProperties.contains(.Favicon) {
                            changeInfo["faviconUrl"] = object["faviconUrl"]
                        }

                        let json = ["tab": object, "changeInfo": changeInfo]
                        self.chrome.commandDelegate?.eventDispatcher.dispatch(.tabs_OnUpdated, json)

                        tab.updatedProperties = .None
                    }
                }

                self.chrome.coreData.saveContextWithErrorAlert()
                self.dirty = false
            }
            dirty = true
        }
    }
}
