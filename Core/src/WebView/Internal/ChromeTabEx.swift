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

final class ChromeTabEx<T> : ChromeTab where T: ChromeTabDataProtocolEx {
    var tabDataEx: T? {
        didSet {
            // If tabDataEx is being nilled in attempt to release the reference,
            // the underlying reference must be released too.
            if tabDataEx == nil {
                tabData = nil
            }
        }
    }

    override weak var openerTab: ChromeTab? {
        didSet {
            // update opener in tab data, if tab data still exists
            // and is different from the already known opener
            if let localData = tabDataEx, openerTab?.tabData !== localData.opener {
                localData.opener = openerTab?.tabData as? T
                window.setNeedsCommit()
            }
        }
    }

    required init(window: ChromeWindow, tabDataEx: T) {
        self.tabDataEx = tabDataEx
        super.init(window: window, tabData: tabDataEx)
    }
}
