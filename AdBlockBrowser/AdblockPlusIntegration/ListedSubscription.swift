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

open class ListedSubscription: ABPSubscriptionBase {
    let disabled: Bool
    let lastSuccess: Date?
    let downloadStatus: String?

    init(url: String, title: String, homepage: String?, disabled: Bool = true, downloadStatus: String? = nil, lastSuccess: Date? = nil) {
        self.disabled = disabled
        self.downloadStatus = downloadStatus
        self.lastSuccess = lastSuccess
        super.init(url: url, title: title, homepage: homepage)
    }

    /// Deserializes object from JSON
    convenience init?(object: AnyObject) {
        // The only apparently mandatory fields are url, title and disabled
        // Everything else is optional, in the sense of probably being in the object but nil
        if let url = object.value(forKey: "url") as? String,
            let title = object.value(forKey: "title") as? String,
            let disabled = object.value(forKey: "disabled") as? Bool {
            // lastSuccess key may not be present at all, be present but nil and be present but zero.
            // It all means that it's unspecified
            let lastSuccess: Date?
            if let jsonValue = object.value(forKey: "lastSuccess"),
                let numberValue = jsonValue as? NSNumber, numberValue.doubleValue > 0 {
                lastSuccess = Date(timeIntervalSince1970: numberValue.doubleValue)
            } else {
                lastSuccess = nil
            }
            // Further optional values
            let homepage = object.value(forKey: "homepage") as? String
            let downloadStatus = object.value(forKey: "downloadStatus") as? String
            self.init(url: url, title: title, homepage: homepage, disabled: disabled, downloadStatus: downloadStatus, lastSuccess: lastSuccess)
            return
        }
        return nil
    }
}
