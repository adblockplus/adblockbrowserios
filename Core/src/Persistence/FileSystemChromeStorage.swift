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

private let extensionsDirectoryName = "extensions"
private let mappingFileName = "keys.plist"

// Helpers for chrome storage file names
private let fileNamePrefix = "cs_"
private let fileNameSuffix = ".txt"

func chromeStorageFileName(`for` key: String) -> String {
    return "\(fileNamePrefix)\(key)\(fileNameSuffix)"
}

func isChromeStorageFileName(fileName: String) -> Bool {
    return fileName.hasPrefix(fileNamePrefix) && fileName.hasSuffix(fileNameSuffix)
}

func chromeStorageLocation(`for` extensionId: String, fileManager manager: FileManager = .default) throws -> URL {
    let document = try manager.url(for: .documentDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)

    return document
        .appendingPathComponent(extensionsDirectoryName)
        .appendingPathComponent(extensionId)
        .appendingPathComponent("storage")
}

/**
 FileSystemChromeStorage
 
 Provides functionality of chrome storage. Mapping file maintains relations
 between storage keys (any arbitrary string) to file names. Values are stored in separated files.
 All storage modifications are done in transactions which are committed by overwriting mapping file.
 */
public final class FileSystemChromeStorage: NSObject, ChromeStorageProtocol {
    private let storageLocation: URL
    private let mappingLocation: URL
    private var fileNamesToRemove = [String]()
    private var fileMapping: [String: String]

    public var keyFilter: NSRegularExpression?
    public weak var mutationDelegate: ChromeStorageMutationDelegate?

    public init(extensionId: String) throws {
        let manager = FileManager.default

        let storageLocation = try chromeStorageLocation(for: extensionId, fileManager: manager)
        let storagePath = storageLocation.path

        var isDirectory: ObjCBool = false
        if !manager.fileExists(atPath: storagePath, isDirectory: &isDirectory) {
            try manager.createDirectory(at: storageLocation, withIntermediateDirectories: true, attributes: nil)
        }

        let mappingLocation = storageLocation.appendingPathComponent(mappingFileName)
        let mappingPath = mappingLocation.path

        self.storageLocation = storageLocation
        self.mappingLocation = mappingLocation

        // Create mapping file if it does not exists
        let updateMapping: Bool
        if manager.fileExists(atPath: mappingPath) {
            if let uwFileMapping = NSDictionary(contentsOf: mappingLocation) as? [String: String] {
                fileMapping = uwFileMapping
                updateMapping = false
            } else {
                Log.critical(ChromeStorageError.mappingRead)
                fileMapping = [:]
                updateMapping = true
            }
        } else {
            fileMapping = [:]
            updateMapping = true
        }

        super.init()

        if updateMapping {
            try self.store(fileMapping: fileMapping)
        }

        // Remove files, which does not conform to existing mapping
        let allFileNames: [String]
        do {
            allFileNames = try manager.contentsOfDirectory(atPath: storagePath)
        } catch let error {
            Log.critical(ChromeStorageError.directoryEnumeration)
            throw error
        }

        let storageFileNames = allFileNames.lazy
            .filter { isChromeStorageFileName(fileName: $0) }
            .filter { fileName in !self.fileMapping.contains(where: { $1 == fileName }) }
            .enumerated()
            .map { $1 }
        removeFiles(fileNames: storageFileNames)
    }

    // MARK: - ChromeStorageProtocol

    public func values(`for` keys: [String]?) throws -> [String: String] {
        let mapping = fileMapping
        var values = [String: String]()
        if let keys = keys {
            for key in keys {
                if let fileName = mapping[key] {
                    values[key] = try content(of: fileName)
                }
            }
        } else {
            for (key, fileName) in mapping {
                values[key] = try content(of: fileName)
            }
        }
        return values
    }

    public func merge(_ newValues: [String: String]) throws {
        // Read the mapping
        var mapping = fileMapping

        var mutations = [String: [String: String]]()

        for (key, value) in newValues {
            let range = NSRange(location: 0, length: key.count)
            let options = NSRegularExpression.MatchingOptions()

            // Apply filter
            if let keyFilter = keyFilter, keyFilter.numberOfMatches(in: key, options: options, range: range) > 0 {
                continue
            }

            if let fileName = mapping[key] {
                mutations[key] = [
                    kKeyNewValue: value,
                    kKeyOldValue: try content(of: fileName)
                ]
            } else {
                mutations[key] = [
                    kKeyNewValue: value,
                    kKeyOldValue: ""
                ]
            }
        }

        let filesToRemove = newValues.compactMap { mapping[$0.0] }

        // Write new values into new files
        for (key, value) in newValues {
            let guid = ProcessInfo.processInfo.globallyUniqueString
            let uniqueFileName = chromeStorageFileName(for: guid)
            mapping[key] = uniqueFileName
            try write(content: value, to: uniqueFileName)
        }

        // Commit the changes
        try store(fileMapping: mapping)

        // Remove old files
        removeFiles(fileNames: filesToRemove)

        // Notify observers
        if let mutationDelegate = mutationDelegate {
            mutationDelegate.storageDataChanged([
                kKeyAreaName: "local",
                kKeyChangesObject: mutations
                ])
        }
    }

    public func remove(keys: [String]) throws {
        var mapping = fileMapping
        var filesToRemove = [String]()
        for key in keys {
            if let fileName = mapping[key] {
                mapping.removeValue(forKey: key)
                filesToRemove.append(fileName)
            }
        }
        try store(fileMapping: mapping)
        removeFiles(fileNames: filesToRemove)
    }

    public func clear() throws {
        // Just store empty mapping and remove all files
        let mapping = fileMapping
        try store(fileMapping: [:])
        removeFiles(fileNames: mapping.values)
    }

    // MARK: - Private

    private func store(fileMapping: [String: String]) throws {
        if !(fileMapping as NSDictionary).write(to: mappingLocation, atomically: true) {
            throw ChromeStorageError.mappingSave
        }
        self.fileMapping = fileMapping
    }

    private func content(of file: String) throws -> String {
        let url = storageLocation.appendingPathComponent(file)
        do {
            return try String(contentsOf: url, encoding: String.Encoding.utf8)
        } catch let error {
            throw CodeRelatedError(ChromeStorageError.valueRead, error: error)
        }
    }

    private func write(content: String, to file: String) throws {
        let url = storageLocation.appendingPathComponent(file)
        do {
            try content.write(to: url, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            throw CodeRelatedError(ChromeStorageError.valueSave, error: error)
        }
    }

    private func removeFiles<T: Sequence>(fileNames: T) where T.Iterator.Element == String {
        let manager = FileManager.default

        for fileName in fileNames {
            let url = storageLocation.appendingPathComponent(fileName)
            do {
                try manager.removeItem(at: url)
            } catch let error {
                Log.critical(CodeRelatedError(ChromeStorageError.valueRemove, error: error))
            }
        }
    }
}
