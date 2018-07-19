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
 The localized texts needed in both Core and main app, and in Swift as well as ObjC.
 The correct place for such UI-specific resource would be in the main app,
 but Core does not "see" the main app (correctly!) so the only applicable
 place currently is Core.
 
 @todo proper design of an interface declared and imported by Core and implemented by main app.
 Needs to be done in both ABB and Kitt.
 */
public func bundleLocalizedString(_ key: String, comment: String) -> String {
    return NSLocalizedString(key, bundle: Settings.coreBundle(), comment: comment)
}

@objcMembers
open class LocalizationResources: NSObject {
    open static func alertCancelText() -> String {
        return bundleLocalizedString("Cancel", comment: "Generic alert Popup button")
    }

    open static func alertOKText() -> String {
        return bundleLocalizedString("OK", comment: "Generic alert Popup button")
    }

    open static func downloadFailureAlertTitle() -> String {
        return bundleLocalizedString("Download failed", comment: "Web download failure alert title")
    }

    // Awkward accessor for the above convenience global func to be accessible from Objc
    open static func bundleString(_ key: String, comment: String) -> String {
        return bundleLocalizedString(key, comment: comment)
    }
}
