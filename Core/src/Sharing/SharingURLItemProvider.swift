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
 A proper method of sharing a webpage: an URL with title (aka subject)
 The popular hack of UIActivityViewController.setValue:forKey: is officially unsupported
 and does not work for some activities anyway (i.e. SMS subject in iOS9)
 
 The class will figure out the most user friendly textual description of the currently loaded webpage
 and provide it as subject to the activity.
 */
open class SharingURLItemProvider: UIActivityItemProvider {
    fileprivate let url: URL
    fileprivate let title: String

    public init?(url: URL, title: String?) {
        self.url = url
        guard let title = { () -> String? in
            // preferably the title
            if let title = title, !title.isEmpty {
                return title
            }
            // secondly display-friendly hostname
            if let host = url.host {
                return host
            }
            // fallback to full URL
            return url.absoluteString
            }() else {
                return nil
        }
        self.title = title
        super.init(placeholderItem: self.title)
    }

    open override var item: Any {
        return url as Any
    }

    open override func activityViewController(_ activityViewController: UIActivityViewController,
                                              subjectForActivityType activityType: UIActivityType?) -> String {
        return title
    }
}
