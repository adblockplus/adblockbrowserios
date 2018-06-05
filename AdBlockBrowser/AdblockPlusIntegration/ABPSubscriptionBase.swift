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

open class ABPSubscriptionBase: Hashable {
    let url: String
    let title: String
    let homepage: String?
    private let urlHash: Int

    init(url: String, title: String, homepage: String?) {
        self.url = url
        self.title = title
        self.homepage = homepage
        self.urlHash = url.hash
    }

    open var hashValue: Int {
        return urlHash
    }
}

public func == (lhs: ABPSubscriptionBase, rhs: ABPSubscriptionBase) -> Bool {
    return lhs.url == rhs.url
}
