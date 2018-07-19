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

/*
 When a webpage URL is provided as activity item,
 there is two ways of adding a textual context to it:

 A. a subject delegate of the activity item
 B. another plaintext activity item

 The default iOS extensions like Message or Mail use A.
 Some extensions use B. and ignore A., like Twitter or Facebook.
 This could be covered by simply adding the website title as plain string to the activity items.
 However the default extensions tend to be helpful and serialize everything found in all
 provided activity items - so the subject appears twice.
 */
open class TitleTextItemProvider: UIActivityItemProvider {
    // to be extended whenever a subject duplication appears in some other extension integration
    fileprivate let subjectAwareActivities = [UIActivityType.mail, UIActivityType.message]

    public init(title: String) {
        super.init(placeholderItem: title)
    }

    open override var item: Any {
        if let activityType = activityType, !subjectAwareActivities.contains(activityType),
            let title = placeholderItem {
            return title
        }
        return NSNull()
    }
}
