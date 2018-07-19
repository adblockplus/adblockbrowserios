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

/// Activity wrapper for "add to bookmarks" button
open class AddBookmarkActivity: UIActivity {
    override open class var activityCategory: UIActivityCategory {
        return UIActivityCategory.action
    }

    override open var activityType: UIActivityType {
        return UIActivityType("AddBookmarkActivityType")
    }

    override open var activityTitle: String? {
        return bundleLocalizedString("Add to Bookmarks", comment: "Browser window activity")
    }

    override open var activityImage: UIImage? {
        return UIImage(named: "add_to_bookmarks.png")
    }

    override open func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }

    override open func perform() {
        self.activityDidFinish(true)
    }
}
