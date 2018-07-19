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

// Support classes incognito tabs and window,
// which suppose to be stored just in memory.

/// This class mock function of ChromeWindowData which is stored just in memory
@objc
final class ChromeWindowDataMemory: NSObject, ChromeWindowDataProtocolEx {

    typealias ChromeTabDataType = ChromeTabDataMemory

    var identifier: NSNumber? = 0
    var tabs: NSOrderedSet? = NSOrderedSet()

    required init(identifier: Int32) {
        self.identifier = NSNumber(value: identifier)
        super.init()
    }
}

/// This class mock function of ChromeTabData which is stored just in memory
@objc
final class ChromeTabDataMemory: NSObject, ChromeTabDataProtocolEx {
    typealias ChromeWindowDataType = ChromeWindowDataMemory

    var documentTitle: String?
    var url: String?
    var active: NSNumber? = NSNumber(value: false)
    var opening: NSSet? = NSSet()
    var activityTimestamp: Date? = Date()
    var restorableState: Data?
    var window: ChromeWindowDataType
    var opener: ChromeTabDataMemory?

    required init(window: ChromeWindowDataType) {
        self.window = window
        super.init()
    }
}

extension ChromeWindowDataMemory {
    static func addTabData<W>(_ window: W, withURL URL: URL?, atIndex index: Int) -> ChromeTabDataType?
        where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowDataMemory {
            let tabData = ChromeTabDataType(window: window.windowDataEx)
            tabData.url = URL?.absoluteString

            if index == NSNotFound {
                window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
                    .add(tabData)
            } else {
                window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
                    .insert(tabData, at: index)
            }

            return tabData
    }

    static func moveTabData<W>(_ window: W, fromPosition: Int, toPosition: Int) -> Bool
        where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowDataMemory {
            let set = window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
            let object = set[fromPosition]
            set.removeObject(at: fromPosition)
            set.insert(object, at: toPosition)
            return true
    }

    static func deleteTabDatas<W>(_ window: W, _ data: [ChromeTabDataType]) -> Bool
        where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowDataMemory {
            window.windowDataEx.mutableOrderedSetValue(forKey: "tabs").removeObjects(in: data)
            return true
    }
}
