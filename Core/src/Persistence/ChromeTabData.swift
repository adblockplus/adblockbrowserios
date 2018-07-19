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

@objc(ChromeTabData)
public final class ChromeTabData: NSManagedObject, ChromeTabDataProtocolEx {
    typealias ChromeWindowDataType = ChromeWindowData

    @NSManaged var documentTitle: String?
    @NSManaged var url: String?
    @NSManaged var active: NSNumber?
    @NSManaged var window: ChromeWindowData
    @NSManaged var opener: ChromeTabData?
    @NSManaged var opening: NSSet?
    @NSManaged var activityTimestamp: Date?
    @NSManaged var restorableState: Data?

    // CoreData designer is incapable of setting a default value reasonably
    // equivalent to "now". This is a workaround.
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setValue(Date(), forKey: "activityTimestamp")
    }
}
