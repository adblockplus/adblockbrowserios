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

@testable import KittCore
import XCTest

class InjectionTests: XCTestCase {
    func testContentInjection() {
        let bundleName = "KittCoreBundle"
        let bundlePath = Bundle(for: JSInjectorReporter.self).path(forResource: bundleName, ofType: "bundle")!
        let bundle = Bundle(path: bundlePath)!
        let reporter = JSInjectorReporter(bundle: bundle)
        let extensionId = "TestExtensionId"
        let tabId = UInt(12345)
        let script = "console.log('It works!')"
        let output1 = reporter.stringWithContentScriptAPI(forExtensionId: extensionId,
                                                          tabId: tabId,
                                                          runAt: "document_start",
                                                          wrappingScript: script)
        assert(output1.contains(extensionId))
        assert(output1.contains("\(tabId)"))
        assert(output1.contains(script))

        let output2 = reporter.stringWithContentDOMAPI(forExtensionId: extensionId, tabId: tabId)

        assert(output2.contains(extensionId))
        assert(output2.contains("\(tabId)"))
    }

}
