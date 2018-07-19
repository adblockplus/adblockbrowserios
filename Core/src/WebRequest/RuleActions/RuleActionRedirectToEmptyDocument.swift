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

open class RuleActionRedirectToEmptyDocument: AbstractRuleActionBlockable {
    open override func applyToDetails(_ details: WebRequestDetails,
                                      modifyingResponse response: BlockingResponse,
                                      completionBlock: (() -> Void)?) {
        response.fakeResponse = URLResponse(url: details.request.url!,
                                            mimeType: "text/plain",
                                            expectedContentLength: 1,
                                            textEncodingName: nil)
        response.fakeData = Data(bytes: UnsafePointer<UInt8>(" "), count: 1)
        completionBlock?()
    }

    open override var debugDescription: String {
        return "\(super.debugDescription) RedirectToEmpty"
    }
}
