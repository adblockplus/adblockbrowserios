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
import RxSwift

typealias FetchedResultsAdapterChanges<Item> = (
    deletedSections: IndexSet,
    insertedSections: IndexSet,
    deletedItems: [(indexPath: IndexPath, item: Item?)],
    insertedItems: [(indexPath: IndexPath, item: Item?)],
    updatedItems: [(indexPath: IndexPath, item: Item?)]
)

final class FetchedResultsAdapter<ResultType>: NSObject, NSFetchedResultsControllerDelegate where ResultType: NSFetchRequestResult {
    private var deletedSections = IndexSet()
    private var insertedSections = IndexSet()
    private var deletedItems = [(indexPath: IndexPath, item: ResultType?)]()
    private var insertedItems = [(indexPath: IndexPath, item: ResultType?)]()
    private var updatedItems = [(indexPath: IndexPath, item: ResultType?)]()

    let changes = PublishSubject<FetchedResultsAdapterChanges<ResultType>>()
    let fetchedResultsController: NSFetchedResultsController<ResultType>

    init(fetchedResultsController: NSFetchedResultsController<ResultType>) {
        self.fetchedResultsController = fetchedResultsController
        super.init()
        self.fetchedResultsController.delegate = self
    }

    // MARK: - NSFetchedResultsControllerDelegate

    // Inspired by
    // http://fruitstandsoftware.com/blog/2013/02/19/uitableview-and-nsfetchedresultscontroller-updates-done-right/
    // and
    // https://gist.github.com/TonnyTao/314fe120ceaf702c0aa9

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange sectionInfo: NSFetchedResultsSectionInfo,
                    atSectionIndex sectionIndex: Int,
                    for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            insertedSections.insert(sectionIndex)
        case .update:
            break
        case .delete:
            deletedSections.insert(sectionIndex)
        case .move:
            // Not sent
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        // Unfortunately iOS9 manages to send incorrect/unexpected NSFetchedResultsChangeType
        // http://stackoverflow.com/questions/31383760/ios-9-attempt-to-delete-and-reload-the-same-index-path
        if !isValueValid(type, allValues: [.insert, .update, .delete, .move]) {
            return
        }

        switch type {
        case .delete:
            if let indexPath = indexPath {
                if !deletedSections.contains(indexPath.section) {
                    deletedItems.append((indexPath, anObject as? ResultType))
                }
                return
            }
        case .insert:
            if let indexPath = newIndexPath {
                if !insertedSections.contains(indexPath.section) {
                    insertedItems.append((indexPath, anObject as? ResultType))
                }
                return
            }
        case .update:
            if let indexPath = indexPath {
                if !insertedSections.contains(indexPath.section) && !deletedSections.contains(indexPath.section) {
                    updatedItems.append((indexPath, anObject as? ResultType))
                }
                return
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath /**/ {
                if indexPath != newIndexPath { //fix iOS9 bug
                    if !deletedSections.contains(indexPath.section) {
                        deletedItems.append((indexPath, anObject as? ResultType))
                    }
                    if !insertedSections.contains(newIndexPath.section) {
                        insertedItems.append((newIndexPath, anObject as? ResultType))
                    }
                }
                // DO NOT USE:
                // tableView?.moveRowAtIndexPath(atIndexPath, toIndexPath: newIndexPath)
                // It was causing crashes in certain circumstances (move indexPath then reload it)
                // Reference implementation uses solution above
                return
            }
            return
        }

        assert(false, "atIndexPath or indexPath is nil, but it is required not to be")
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let isEmpty = deletedSections.isEmpty
            && insertedSections.isEmpty
            && deletedItems.isEmpty
            && insertedItems.isEmpty
            && updatedItems.isEmpty

        //fix iOS9 bug: count might be equal to zero
        if !isEmpty {
            changes.onNext((
                deletedSections,
                insertedSections,
                deletedItems,
                insertedItems,
                updatedItems
            ))
        }

        deletedSections.removeAll()
        insertedSections.removeAll()
        deletedItems.removeAll()
        insertedItems.removeAll()
        updatedItems.removeAll()
    }
}
