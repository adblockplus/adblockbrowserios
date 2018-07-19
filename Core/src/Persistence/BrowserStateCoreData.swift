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

import CoreData

// Throwable types must be in global scope
// otherwise linker spills cryptic errors in random object files
public struct InvalidStoreURLError: Error {
}

public extension BrowserStateCoreData {
    func fetch<T: NSManagedObject>(_ predicate: NSPredicate? = nil) -> [T]? {
        let request = NSFetchRequest<T>(entityName: NSStringFromClass(T.self))
        request.predicate = predicate
        return resultsOfFetchWithErrorAlert(request)
    }

    func createObject<T: NSManagedObject>() -> T? {
        return insertNewObject(forEntityClass: T.self) as? T
    }

    /*
     WARNING: Swift 2.2 (Xcode 7.3) refuses to create bridging header for function with optional return value.
     A function with nonoptional retval will be bridged but translated as _Nullable !!! (may be a compiler bug even)
     */
    @objc
    public func metadataIfMigrationNeeded(_ sourceStoreURL: URL, destinationModel: NSManagedObjectModel) throws -> [String: Any] {
        let options: [AnyHashable: Any] = [
            NSInferMappingModelAutomaticallyOption: true,
            NSMigratePersistentStoresAutomaticallyOption: true]
        // Load store metadata (this will contain information about the versions of the models this store was created with)
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: sourceStoreURL, options: options)
        let isCompatible = destinationModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        // Metadata not needed if the persistent store is compatible with destination model
        // Must return empty dict instead of nil - see warning above
        return isCompatible ? [:] as [String: Any] : metadata
    }

    @objc
    public func migrate(_ storeURL: URL, sourceModel: NSManagedObjectModel, destinationModel: NSManagedObjectModel) throws {
        // Compute the mapping between old model and new model
        let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
        // Backup old store
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        let storeBackupURL = storeURL.appendingPathExtension("\(dateFormatter.string(from: Date()))")

        try FileManager.default.moveItem(at: storeURL, to: storeBackupURL)
        // Apply the mapping to the backed up store, replace the current store
        let migrationMgr = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        try migrationMgr.migrateStore(
            from: storeBackupURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mapping,
            toDestinationURL: storeURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil)
    }

    @objc
    public func createContext(forStoreURL storeURL: URL, withModel model: NSManagedObjectModel, wasMigrated: Bool) throws -> NSManagedObjectContext {
        // Since iOS7 the default sqlite journaling mode is Write-Ahead-Log.
        // The mode must be turned off when adding a migrated (backed up) store
        // https://developer.apple.com/library/ios/qa/qa1809/_index.html
        let options: [AnyHashable: Any] = [
            NSInferMappingModelAutomaticallyOption: true,
            NSMigratePersistentStoresAutomaticallyOption: !wasMigrated,
            NSSQLitePragmasOption: ["journal_mode": wasMigrated ? "DELETE" : "WAL"]
        ]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        let context = NSManagedObjectContext()
        context.persistentStoreCoordinator = coordinator
        // Browser state doesn't need to be undone, don’t waste effort recording undo actions
        context.undoManager = nil
        return context
    }

    // the following functions needed to be rewritten from Objc so they can be used in Swift3
    func fetchRequest<T: NSFetchRequestResult> (with predicate: NSPredicate?) -> NSFetchRequest<T> {
        assert(Thread.isMainThread, "CoreData fetch not called on main thread")
        let request = NSFetchRequest<T>(entityName: NSStringFromClass(T.self))
        if let predicate = predicate {
            request.predicate = predicate
        }
        return request
    }

    func resultsOfFetchWithErrorAlert<T>(_ request: NSFetchRequest<T>) -> [T]? {
        do {
            return try context.fetch(request)
        } catch let error {
            let alert = Utils.alertViewWithError(error, title: "Core Data Fetch", delegate: nil)
            alert?.show()
        }
        return nil
    }

    func fetchController<T>(for request: NSFetchRequest<T>, withCacheName cacheName: String?) -> NSFetchedResultsController<T> {
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: cacheName)
    }

    func fetchController<T>(for request: NSFetchRequest<T>, sectionNameKeyPath: String, cacheName name: String?) -> NSFetchedResultsController<T> {
        return NSFetchedResultsController(fetchRequest: request,
                                          managedObjectContext: context,
                                          sectionNameKeyPath: sectionNameKeyPath,
                                          cacheName: name)
    }

    func deleteObjectsResulting<T: NSManagedObject> (fromFetch request: NSFetchRequest<T>) {
        let results = self.resultsOfFetchWithErrorAlert(request)
        if results?.count != 0 {
            self.deleteManagedObjects(results)
        }
    }
}
