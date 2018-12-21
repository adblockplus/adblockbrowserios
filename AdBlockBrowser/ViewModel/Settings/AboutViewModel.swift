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

final class AboutViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents

    init(components: ControllerComponents) {
        self.components = components
    }

    /// Open a URL in Safari using the appropriate call for the current iOS version.
    /// - Parameter url: A URL.
    func openURL(_ url: URL) {
        if let tab = components.chrome.focusedWindow?.add(tabWithURL: url, atIndex: 0) {
            tab.active = true
            tab.window.focused = true
        }
    }
}
