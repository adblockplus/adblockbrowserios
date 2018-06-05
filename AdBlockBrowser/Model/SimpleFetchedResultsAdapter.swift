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

struct SimpleFetchedResultsAdapterChanges<Item> {
    var deletedItems = [(indexPath: IndexPath, item: Item?)]()
    var insertedItems = [(indexPath: IndexPath, item: Item?)]()
    var updatedItems = [(indexPath: IndexPath, item: Item?)]()
    var movedItems = [(indexPath: IndexPath, newIndexPath: IndexPath, item: Item?)]()
}

final class SimpleFetchedResultsAdapter<ResultType>: NSObject, NSFetchedResultsControllerDelegate
    where ResultType: NSFetchRequestResult {
    private var currentChanges = SimpleFetchedResultsAdapterChanges<ResultType>()
    let changes = PublishSubject<SimpleFetchedResultsAdapterChanges<ResultType>>()
    let fetchedResultsController: NSFetchedResultsController<ResultType>

    init(fetchedResultsController: NSFetchedResultsController<ResultType>) {
        assert(fetchedResultsController.sectionNameKeyPath == nil, "Only one section is supported!")
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
        assert(false)
    }

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

        assert((indexPath?.section ?? 0) == 0 && (newIndexPath?.section ?? 0) == 0)

        switch (type, indexPath, newIndexPath) {
        case (.delete, .some(let indexPath), _):
            currentChanges.deletedItems.append((indexPath, anObject as? ResultType))
            return
        case (.insert, _, .some(let newIndexPath)):
            currentChanges.insertedItems.append((newIndexPath, anObject as? ResultType))
            return
        case (.update, .some(let indexPath), _):
            currentChanges.updatedItems.append((indexPath, anObject as? ResultType))
            return
        case (.move, .some(let indexPath), .some(let newIndexPath)):
            currentChanges.movedItems.append((indexPath, newIndexPath, anObject as? ResultType))
            return
        default:
            assert(false, "atIndexPath or indexPath is nil, but it is required not to be")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let count = currentChanges.deletedItems.count
            + currentChanges.insertedItems.count
            + currentChanges.updatedItems.count
            + currentChanges.movedItems.count
        //fix iOS9 bug: count might be equal to zero
        if count > 0 {
            changes.onNext(currentChanges)
        }

        currentChanges.deletedItems.removeAll()
        currentChanges.insertedItems.removeAll()
        currentChanges.updatedItems.removeAll()
        currentChanges.movedItems.removeAll()
    }
}
