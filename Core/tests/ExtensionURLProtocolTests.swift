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
@testable import KittCore
import XCTest

final class ExtensionURLProtocolTests: XCTestCase {
    func testChromeExtensionResourceApi() {
        let url1 = URL(string: "chrome-extension://\(extensionId)/image.png")!
        XCTAssert(ProtocolHandlerChromeExt.isBundleResource(url1))
        let url2 = URL(string: "http://test/image.png")!
        XCTAssert(!ProtocolHandlerChromeExt.isBundleResource(url2))
        XCTAssert(ProtocolHandlerChromeExt.extensionId(of: URLRequest(url: url1)) == extensionId)
        XCTAssert(ProtocolHandlerChromeExt.url(forRequestResource: "image.png", extensionId: extensionId) == url1)
        XCTAssert(ProtocolHandlerChromeExt.url(forRequestResource: "/image.png", extensionId: extensionId) == url1)
    }
}
