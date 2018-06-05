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

enum BookmarksModelChange {
    case deleteItems([IndexPath])
    case insertItems([IndexPath])
    case reloadItems([IndexPath])
    case moveItem(IndexPath, IndexPath)
}

protocol BookmarksBaseViewModel: class {
    var model: [BookmarkExtras] { get set }
    var modelChanges: PublishSubject<[BookmarksModelChange]> { get }
}

extension BookmarksBaseViewModel {
    func process(bookmarksChanges: SimpleFetchedResultsAdapterChanges<BookmarkExtras>) {
        var changes = bookmarksChanges
        for (indexPath, newIndexPath, item) in changes.movedItems {
            changes.deletedItems.append((indexPath, item))
            changes.insertedItems.append((newIndexPath, item))
        }
        changes.movedItems.removeAll()

        model.merge(changes: changes)
        let filter = { (item: (IndexPath, Any?)) in return item.0 }
        modelChanges.onNext([
            .deleteItems(changes.deletedItems.compactMap(filter)),
            .insertItems(changes.insertedItems.compactMap(filter)),
            .reloadItems(changes.updatedItems.compactMap(filter))
            ])
    }

    func merge(with adapter: SimpleFetchedResultsAdapter<BookmarkExtras>?) {
        CONTINUE: if model.count == adapter?.fetchedResultsController.sections?[0].numberOfObjects ?? 0 {
            for index in model.indices {
                if model[index] != adapter?.fetchedResultsController.object(at: IndexPath(row: index, section: 0)) {
                    break CONTINUE
                }
            }
            return
        }

        let bookmarks = adapter?.fetchedResultsController.fetchedObjects ?? []

        let sequence = longestCommonSubsequence(model, bookmarks)

        let set1 = IndexSet(sequence.map { $0.0 })
        let deletedItems = model
            .enumerated()
            .filter { !set1.contains($0.0) }
            .map { IndexPath(row: $0.0, section: 0) }

        let set2 = IndexSet(sequence.map { $0.1 })
        let insertItems = bookmarks
            .enumerated()
            .filter { !set2.contains($0.0) }
            .map { IndexPath(row: $0.0, section: 0) }

        model = bookmarks
        modelChanges.onNext([
            .deleteItems(deletedItems),
            .insertItems(insertItems)
            ])
    }
}

extension Array {
    mutating func merge(changes: SimpleFetchedResultsAdapterChanges<Element>) {
        let removedIndices = IndexSet(changes.deletedItems.map { $0.indexPath.row })
        remove(at: removedIndices)

        var elements = [Int: Element]()
        for (indexPath, bookmark) in changes.insertedItems {
            elements[indexPath.row] = bookmark
        }

        insert(elements)
    }
}
