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

let kittCoreErrorDomain = "KittCoreErrorDomain"

enum KittCoreErrorCode: Int {
    case none
    case commandNotFound
    case commandParametersDidNotMatch
    case commandIgnored
    case eventResultDidNotMatch
    case chromeBrowserActionNotAvailable
    case chromeMessageCallbackNotFound
}

enum KittCoreError: String, StringCodeConvertibleError {
    case chromeStorageIsNull
    case chromeTabNotFound
    case coreDataFetch
    case generatingBackgroundPage

    var shortCode: String {
        return "KittCore_\(rawValue)Error"
    }
}

extension NSError {
    convenience init(code: KittCoreErrorCode = .none, message: String) {
        self.init(domain: kittCoreErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
    }

    var message: String? {
        return self.userInfo[NSLocalizedDescriptionKey] as? String
    }
}
