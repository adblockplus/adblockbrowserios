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

@objc(HistoryUrl)
open class HistoryUrl: NSManagedObject {
    @NSManaged open var hidden: Bool
    @NSManaged open var lastVisited: Date?
    @NSManaged open var title: String?
    @NSManaged open var url: String?
    @NSManaged open var visitCounter: Int64
    @NSManaged open var icon: UrlIcon?
    @NSManaged open var tab: NSSet?

    open override var debugDescription: String {
        return "\(String(describing: url)) last \(visitCounter) \(String(describing: lastVisited))"
    }
}
