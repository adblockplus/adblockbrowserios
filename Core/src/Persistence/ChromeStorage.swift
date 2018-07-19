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

@objc public protocol ChromeStorageMutationDelegate: NSObjectProtocol {
    func storageIdentifier() -> String

    func storageDataChanged(_ dataDictionary: [AnyHashable: Any])
}

@objc public protocol ChromeStorageProtocol: NSObjectProtocol {
    var keyFilter: NSRegularExpression? { get set }

    weak var mutationDelegate: ChromeStorageMutationDelegate? { get set }

    /// chrome.storage.local.get
    /// @param collection array of keys. Keys are expected to
    /// be strings. Values will be filled with corresponding values from the storage,
    /// or left intact if not present in storage (hence providing 'default value')
    /// nil value for all keys
    func values(`for` keys: [String]?) throws -> [String: String]

    /// chrome.storage.local.set
    /// @param collection immutable key-value. Keys are expected to
    /// be strings. Values will be set to the storage, creating new k-v entry or
    /// replacing the existing value.
    /// @throws error if merging was not successful
    func merge(_ newValues: [String: String]) throws

    /// chrome.storage.local.remove
    /// @param keys array of key names (strings) to remove from the storage
    /// @throws error if removing was not successful
    func remove(keys: [String]) throws

    /// chrome.storage.local.clear
    /// Clears the whole storage (all keys)
    /// @throws error if merging was not successful
    func clear() throws
}

// @see JavaScriptBridge/API/chrome/storage.js
let kKeyChangesObject = "changes"
let kKeyAreaName = "areaName"
// https://developer.chrome.com/extensions/storage#type-StorageChange
let kKeyNewValue = "newValue"
let kKeyOldValue = "oldValue"

public class ChromeStorage: NSObject, CoreDataMutationDelegate, ChromeStorageProtocol {
    let dataSource: BrowserStateCoreData
    let extensionId: String

    open var keyFilter: NSRegularExpression?
    open weak var mutationDelegate: ChromeStorageMutationDelegate?

    public init(extensionId: String, dataSource: BrowserStateCoreData) {
        self.extensionId = extensionId
        self.dataSource = dataSource
        super.init()
        dataSource.add(self)
    }

    // MARK: - ChromeStorageProtocol

    public func values(`for` keys: [String]?) throws -> [String: String] {
        let request = NSFetchRequest<ExtensionStorage>(entityName: NSStringFromClass(ExtensionStorage.self))
        request.returnsObjectsAsFaults = false
        if let keys = keys {
            request.predicate = NSPredicate(format: "extension.extensionId = %@ and key in %@", extensionId, keys)
        } else {
            request.predicate = NSPredicate(format: "extension.extensionId = %@", extensionId)
        }

        guard let results = dataSource.resultsOfFetchWithErrorAlert(request) else {
            throw CodeRelatedError(KittCoreError.coreDataFetch, message: "Fetch for ExtensionStorage")
        }

        // Keys, which are not stored in the storage, have to be removed from results set.
        // That is how chrome storage works on Chrome. This bug was breaking ABP extension.
        return results.reduce([String: String]()) { data, extensionStore in
            var data = data
            if let key = extensionStore.key {
                data[key] = extensionStore.value
            }
            return data
        }
    }

    public func merge(_ newValues: [String: String]) throws {
        // Core Data needs to do two fetch requests in any case, one for Extension, one for ExtensionStorage
        guard let `extension` = dataSource.extensionObject(withId: extensionId) else {
            throw CodeRelatedError(KittCoreError.coreDataFetch, message: "Fetch for Extension")
        }

        let request = NSFetchRequest<ExtensionStorage>(entityName: NSStringFromClass(ExtensionStorage.self))
        // Retrieve all data from row cache (they are going to be retrieved anyway)
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "extension = %@", `extension`)

        guard let items = dataSource.resultsOfFetchWithErrorAlert(request) else {
            throw CodeRelatedError(KittCoreError.coreDataFetch, message: "Fetch for ExtensionStorage")
        }

        var newValues = newValues

        // Process new values and update existing items
        for storage in items {
            assert(!storage.isFault, "Data are not retrieved from row cache!")
            if let key = storage.key, let value = newValues[key] {
                storage.value = value
                newValues.removeValue(forKey: key)
            }
        }

        // Insert remaining values into storage
        for (key, newValue) in newValues {
            let inserted: ExtensionStorage? = dataSource.createObject()
            inserted?.`extension` = `extension`
            inserted?.key = key
            inserted?.value = newValue
        }

        dataSource.saveContextWithErrorAlert()
    }

    public func remove(keys: [String]) throws {
        let predicate = NSPredicate(format: "extension.extensionId = %@ AND key IN %@", extensionId, keys)
        let request: NSFetchRequest<ExtensionStorage> = dataSource.fetchRequest(with: predicate)
        dataSource.deleteObjectsResulting(fromFetch: request)
    }

    public func clear() throws {
        let predicate = NSPredicate(format: "extension.extensionId = %@", extensionId)
        let request: NSFetchRequest<ExtensionStorage> = dataSource.fetchRequest(with: predicate)
        dataSource.deleteObjectsResulting(fromFetch: request)
    }

    // MARK: CoreDataMutationDelegate

    open func managedObjectClassOfInterest() -> AnyObject.Type {
        return ExtensionStorage.self
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    open func instancesDidMutate(_ mutations: [Any]) {
        var mutationsById = [String: [Any]]()

        for mutation in mutations {
            guard let mutation = mutation as? [AnyHashable: Any],
                let object = mutation["instance"] as? ExtensionStorage,
                let key = object.key else {
                    continue
            }

            // Apply filter
            if let keyFilter = keyFilter, keyFilter.numberOfMatches(in: key,
                                                                    options: NSRegularExpression.MatchingOptions(),
                                                                    range: NSRange(location: 0, length: key.count)) > 0 {
                continue
            }

            let changeKey = mutation["changeKey"] as? String
            let oldValues = mutation["oldValues"] as? [String: Any]
            let newValues = mutation["newValues"] as? [String: Any]

            var extensionId = object.`extension`?.extensionId
            let oldValue = oldValues?["value"]
            let newValue = newValues?["value"]

            let storageChange: [String: Any]

            switch changeKey {
            case .some(NSInsertedObjectsKey):
                if let newValue = newValue {
                    // chrome.storage onChanged returns oldValue: undefined
                    storageChange = [kKeyNewValue: newValue]
                    break
                } else {
                    continue
                }
            case .some(NSUpdatedObjectsKey):
                if let newValue = newValue, let oldValue = oldValue {
                    // chrome.storage onChanged returns both oldValue and newValue
                    storageChange = [kKeyOldValue: oldValue, kKeyNewValue: newValue]
                    break
                } else {
                    continue
                }
            case .some(NSDeletedObjectsKey):
                let oldExtension = oldValues?["extension"] as? Extension
                extensionId = oldExtension?.extensionId
                // chrome.storage onChanged returns newValue: undefined
                storageChange = [kKeyOldValue: object.value ?? ""]
            default:
                assert(false, "Key \(String(describing: changeKey)) is not supported")
                continue
            }

            if let extensionId = extensionId {
                let entry = [key: storageChange]
                if let entries = mutationsById[extensionId] {
                    mutationsById[extensionId] = entries + [entry]
                } else {
                    mutationsById[extensionId] = [entry]
                }
            }
        }

        if let mutationDelegate = mutationDelegate {
            if let mutations = mutationsById[mutationDelegate.storageIdentifier()] {
                mutationDelegate.storageDataChanged([
                    kKeyAreaName: "local",
                    kKeyChangesObject: mutations
                    ])
            }
        }
    }
}
