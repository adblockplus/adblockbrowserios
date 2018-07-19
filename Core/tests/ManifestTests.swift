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

let test = "test"

final class ManifestTests: XCTestCase {
    func readManifest(_ name: String) -> Data? {
        let path = Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")!
        return try? Data(contentsOf: path)
    }

    func testManifestCreation() {
        guard let manifestData1 = readManifest("Manifests/manifest1") else {
            XCTFail("Unable to read Manifest1")
            return
        }
        if let manifest1 = try? Manifest(data: manifestData1) {
            assert(manifest1.name == test)
            assert(manifest1.manifestDescription == test)
            assert(manifest1.author == nil)
            assert(manifest1.version == "0.0.0")
            assert(manifest1.contentScripts.isEmpty)
            assert(manifest1.defaultLocale == "cs")
            assert(!manifest1.hasDefinedBrowserAction())
        } else {
            XCTFail("Unable to parse Manifest1")
        }

        guard let manifestData2 = readManifest("Manifests/manifest2") else {
            XCTFail("Unable to read Manifest2")
            return
        }
        if let manifest2 = try? Manifest(data: manifestData2) {
            assert(manifest2.name == test)
            assert(manifest2.defaultLocale == "en")
            assert(manifest2.contentScripts.count == 2)
            assert(manifest2.contentScripts[1].allFrames)
            assert(manifest2.contentScripts[1].filenames == ["test.js"])
            assert(manifest2.backgroundFilenames()! == ["test.js"])
        } else {
            XCTFail("Unable to parse Manifest2")
        }

        guard let manifestData3 = readManifest("Manifests/manifest3") else {
            XCTFail("Unable to read Manifest3")
            return
        }
        if let manifest3 = try? Manifest(data: manifestData3) {
            assert(manifest3.name == test)
            assert(manifest3.defaultLocale == "en")
            assert((manifest3.iconPaths(for: .wholeExtension)!["16"] as? String) == "images/icon16.png")
            assert((manifest3.iconPaths(for: .browserAction)!["16"] as? String) == "images/icon16.png")
            assert(manifest3.iconPaths(for: .pageAction) == nil)
            assert(manifest3.browserActionFilename() == "popup.html")
        } else {
            XCTFail("Unable to parse Manifest3")
        }
    }
}
