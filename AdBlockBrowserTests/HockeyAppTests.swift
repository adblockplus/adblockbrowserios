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

import XCTest

class HockeyAppTests: XCTestCase {

    func testAPIKeys() {
        let hockeyAppIdentifier = MacroSettingsExpander.hockeyAppIdentifier() as String

        #if DEBUG
            XCTAssert(hockeyAppIdentifier == "DEBUG" || hockeyAppIdentifier.count == 32,
                      """
                          API Key should be 'DEBUG' or filled with a
                          valid API key (32 char length), according to the build configuration.
                      """)
        #elseif DEVBUILD
            XCTAssert(hockeyAppIdentifier == "DEVBUILD" || hockeyAppIdentifier.count == 32,
                      """
                          API Key should be 'DEVBUILD' or filled with a
                          valid API key (32 char length), according to the build configuration.
                      """)
        #elseif RELEASE
            XCTAssert(hockeyAppIdentifier == "RELEASE" || hockeyAppIdentifier.count == 32,
                      """
                          API Key should be 'RELEASE' or filled with a
                          valid API key (32 char length), according to the build configuration.
                      """)
        #endif
    }
}
