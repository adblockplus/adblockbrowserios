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

/**
 When an existing tabview history is walked just by back/fwd arrows
 (which depends only on WebKit knowledge), the session authentication delegate
 is not called at all for HTTPS websites which were already loaded in history.
 But the BrowserController GUI still needs to know what lock icon it should display.
 Luckily the auth delegate seems to be skipped only in the immediate life of the current
 instance. I.e. when a tab is persisted and then loaded again, it calls the auth delegate
 again.
 
 So the current solution is to remember the security levels of previously visited HTTPS sites
 and serve that knowledge preferably.
 */
@objc
open class URLAuthCache: NSObject {
    @objc open static let sharedInstance = URLAuthCache()

    fileprivate let cache = NSCache<AnyObject, AnyObject>()

    @objc
    open func get(_ url: NSURL) -> AuthenticationResultProtocol? {
        guard let hostname = url.host else {
            return nil
        }
        /// Will check from the most specific domain down to least specific
        /// "x.y.z.com" => ["x.y.z.com", "y.z.com", "z.com"]
        var hosts: [String] = hostname.components(separatedBy: ".").reversed()
            .reduce([]) { prev, val in
                guard let last = prev.last else {
                    // initialize empty array
                    return [val]
                }
                var current = prev
                current.append([val, last].joined(separator: "."))
                return current
            }.reversed()
        hosts.removeLast() // don't need the TLD alone

        for host in hosts {
            var result: AuthenticationResultProtocol?
            synchronized(cache) {
                result = cache.object(forKey: host as AnyObject) as? AuthenticationResultProtocol
            }
            if let result = result {
                return result
            }
        }
        return nil
    }

    @objc
    open func set(_ auth: AuthenticationResultProtocol) {
        synchronized(cache) {
            cache.setObject(auth, forKey: auth.host as AnyObject)
        }
    }
}
