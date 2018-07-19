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

let extensionId = "test"

final class ChromeStorageTests: XCTestCase {
    func finalizeAndCheckStorageDirectory(storage: FileSystemChromeStorage) {
        let manager = FileManager.default
        do {
            let location = try chromeStorageLocation(for: extensionId, fileManager: manager)
            try storage.clear()
            XCTAssertEqual(try storage.values(for: nil), [:])
            let contents = try manager.contentsOfDirectory(at: location,
                                                           includingPropertiesForKeys: nil,
                                                           options: .skipsHiddenFiles)
            for file in contents {
                XCTAssert(!isChromeStorageFileName(fileName: file.lastPathComponent))
            }
        } catch let error {
            XCTFail("ChromeStorage failed - Error: \(error)")
        }
    }

    func testFileSystemStorage() {
        do {
            let localValues = ["a": "a", "b": "b", "c": "c", "d": "d"]

            let storage = try FileSystemChromeStorage(extensionId: extensionId)

            try storage.clear()

            try storage.merge(localValues)

            let values = try storage.values(for: Array(localValues.keys))
            XCTAssertEqual(localValues, values)

            try storage.remove(keys: Array(localValues.keys))

            let noValues = try storage.values(for: Array(localValues.keys))
            XCTAssertTrue(noValues.isEmpty)

            finalizeAndCheckStorageDirectory(storage: storage)

        } catch let error {
            XCTAssert(false, "ChromeStorage failed \(error)")
        }
    }

    func testFileSystemStoragePersistence() {
        do {
            let localValues = ["a": "a", "b": "b", "c": "c", "d": "d"]

            do {
                let storage = try FileSystemChromeStorage(extensionId: extensionId)
                try storage.clear()
                try storage.merge(localValues)
            }

            do {
                let storage = try FileSystemChromeStorage(extensionId: extensionId)
                let values = try storage.values(for: Array(localValues.keys))
                XCTAssertEqual(localValues, values)

                finalizeAndCheckStorageDirectory(storage: storage)
            }
        } catch let error {
            XCTFail("ChromeStorage failed \(error)")
        }
    }

    func testRandomStorageOperations() {
        do {
            let storage = try FileSystemChromeStorage(extensionId: extensionId)
            try storage.clear()

            var activeKeyValues = [String: String]()
            var inactiveKeys = [String]()

            for index in 0..<32 {
                inactiveKeys.append("key\(index)")
            }

            for _ in 0...100 {
                switch arc4random_uniform(2) {
                case 0:
                    var inputKeys = Array(activeKeyValues.keys)

                    let keys1 = (0..<arc4random_uniform(8)).compactMap { _ in return removeRandomElement(array: &inputKeys) }
                    let keys2 = (0..<arc4random_uniform(8)).compactMap { _ in return removeRandomElement(array: &inactiveKeys) }

                    var newValues = [String: String]()

                    for key in keys1 + keys2 {
                        let newValue = "Value \(arc4random_uniform(512))"
                        newValues[key] = newValue
                        activeKeyValues[key] = newValue
                    }

                    try storage.merge(newValues)
                default:
                    var inputKeys = Array(activeKeyValues.keys)
                    let keys = (0..<arc4random_uniform(8)).compactMap { _ in return removeRandomElement(array: &inputKeys) }
                    inactiveKeys += keys
                    for key in keys {
                        activeKeyValues.removeValue(forKey: key)
                    }

                    try storage.remove(keys: keys)
                }

                let values = try storage.values(for: Array(activeKeyValues.keys))
                XCTAssertEqual(activeKeyValues, values)
            }

            finalizeAndCheckStorageDirectory(storage: storage)

        } catch let error {
            XCTFail("ChromeStorage failed \(error)")
        }
    }

    func testFileNameChecking() {
        XCTAssert(!isChromeStorageFileName(fileName: extensionId))
        let fileName = chromeStorageFileName(for: extensionId)
        XCTAssert(isChromeStorageFileName(fileName: fileName) && !fileName.isEmpty)
    }
}

private func removeRandomElement<T>( array: inout [T]) -> T? {
    if array.count > 0 {
        let index = arc4random_uniform(UInt32(array.count))
        return array.remove(at: Int(index))
    } else {
        return nil
    }
}
