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

private let languageBundle: Bundle? = {
    if let path = Bundle.main.path(forResource: "en", ofType: "lproj") {
        return Bundle(path: path)
    } else {
        assert(false, "en.lproj cannot be found!")
        return nil
    }
}()

/**
 Fixes the issue with fallback language:
 https://stackoverflow.com/questions/3263859/localizing-strings-in-ios-default-fallback-language/8784451#8784451
 */
func localize(_ key: String, comment: String) -> String {
    let defaultValue = "<nil/>"
    var value = NSLocalizedString(key, value: defaultValue, comment: comment)
    if value == defaultValue {
        if Locale.preferredLanguages.first != "en", let bundle = languageBundle {
            value = bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        }
        if value == defaultValue {
            value = key
            assert(false, "Localized string does not exist for \(key)")
        }
    }
    return value
}
