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

import CoreData

@objc(ChromeWindowData)
public final class ChromeWindowData: NSManagedObject, ChromeWindowDataProtocolEx {
    typealias ChromeTabDataType = ChromeTabData

    @NSManaged var identifier: NSNumber?
    @NSManaged var tabs: NSOrderedSet?
}

extension ChromeWindowData {
    static func addTabData<W>
        (_ window: W,
         withURL URL: Foundation.URL?,
         atIndex index: Int) -> ChromeTabDataType? where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowData {
        guard let tabData: ChromeTabDataType = window.chrome.coreData.createObject() else {
            return nil
        }

        if index == NSNotFound {
            window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
                .add(tabData)
        } else {
            window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
                .insert(tabData, at: index)
        }

        tabData.url = URL?.absoluteString

        if !window.chrome.coreData.saveContextWithErrorAlert() {
            return nil
        }

        return tabData
    }

    static func moveTabData<W>
        (_ window: W,
         fromPosition: Int,
         toPosition: Int) -> Bool where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowData {
        let set = window.windowDataEx.mutableOrderedSetValue(forKey: "tabs")
        let object = set[fromPosition]
        set.removeObject(at: fromPosition)
        set.insert(object, at: toPosition)

        return window.chrome.coreData.saveContextWithErrorAlert()
    }

    static func deleteTabDatas<W>
        (_ window: W, _ data: [ChromeTabDataType]) -> Bool where W: ChromeWindow, W: ChromeWindowExProtocol, W.WindowDataType == ChromeWindowData {
        window.chrome.coreData.deleteManagedObjects(data)
        return window.chrome.coreData.saveContextWithErrorAlert()
    }
}
