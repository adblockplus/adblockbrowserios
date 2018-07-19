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

public final class SAPopupWebView: SAWebView {
    @objc public weak var `extension`: BrowserExtension?
    private weak var _bridgeSwitchboard: BridgeSwitchboard?
    public override weak var bridgeSwitchboard: BridgeSwitchboard? {
        get { return _bridgeSwitchboard }
        set { _bridgeSwitchboard = newValue }
    }

    public override var origin: CallbackOriginType {
        return .popup
    }
}
