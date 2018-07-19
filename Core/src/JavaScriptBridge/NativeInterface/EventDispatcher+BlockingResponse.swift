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

struct JSBlockingResponse: JSObjectConvertibleParameter {
    let cancel: Bool
    let redirectUrl: String?
    let requestHeaders: [Any]?
    let responseHeaders: [AnyHashable: Any]?

    init?(object: [AnyHashable: Any]) {
        cancel = object["cancel"] as? Bool ?? false
        redirectUrl = object["redirectUrl"] as? String
        requestHeaders = object["requestHeaders"] as? [Any]
        responseHeaders = object["responseHeaders"] as? [AnyHashable: Any]
    }
}

extension EventDispatcher {
    func handleBlockingResponse(_ callback: BridgeCallback,
                                _ json: Any,
                                _ completion: ((Result<JSOptional<JSBlockingResponse>>) -> Void)? = nil) {
        dispatch(callback, json, completion)
    }
}
