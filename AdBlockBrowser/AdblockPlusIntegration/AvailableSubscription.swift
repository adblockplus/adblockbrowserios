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

open class AvailableSubscription: ABPSubscriptionBase {
    let specialization: String
    let prefixes: String
    let listed: Bool

    init(url: String, title: String, specialization: String, homepage: String, prefixes: String, listed: Bool = false) {
        self.specialization = specialization
        self.prefixes = prefixes
        self.listed = listed
        super.init(url: url, title: title, homepage: homepage)
    }

    ///
    /// Deserializes object from JSON
    ///
    convenience init?(object: AnyObject) {
        if let url = object.value(forKey: "url") as? String,
            let title = object.value(forKey: "title") as? String,
            let homepage = object.value(forKey: "homepage") as? String,
            let specialization = object.value(forKey: "specialization") as? String,
            let prefixes = object.value(forKey: "prefixes") as? String,
            let listed = object.value(forKey: "listed") as? Bool {
            self.init(
                url: url,
                title: title,
                specialization: specialization,
                homepage: homepage,
                prefixes: prefixes,
                listed: listed)
            return
        }
        return nil
    }
}
