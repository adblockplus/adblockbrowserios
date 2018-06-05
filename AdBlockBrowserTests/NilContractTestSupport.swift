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
 @see Utils.isObjectReferenceNil

 This stub be called from ObjC with nil parameter, simulating broken nilness contract on annotated
 Swift interface of legacy ObjC interface.
 */
@objc
open class NilContractTestSupport: NSObject {
    @objc
    open class func testNonOptionalObjectNil(_ parameter: AnyObject) -> Bool {
        return Utils.isObjectReferenceNil(parameter)
    }
}
