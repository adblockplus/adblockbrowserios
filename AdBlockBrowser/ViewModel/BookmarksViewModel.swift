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

final class BookmarksViewModel: ViewModelProtocol, BookmarksBaseViewModel {
    let components: ControllerComponents
    let isGhostModeEnabled: Variable<Bool>
    let browserSignalSubject: PublishSubject<BrowserControlSignals>
    let adapter: SimpleFetchedResultsAdapter<BookmarkExtras>?

    var model = [BookmarkExtras]()
    let modelChanges = PublishSubject<[BookmarksModelChange]>()

    let isEditing = Variable(false)

    private let disposeBag = DisposeBag()

    init(components: ControllerComponents,
         isGhostModeEnabled: Variable<Bool>,
         browserSignalSubject: PublishSubject<BrowserControlSignals>) {
        self.components = components
        self.isGhostModeEnabled = isGhostModeEnabled
        self.browserSignalSubject = browserSignalSubject

        do {
            let fetchedResultsController = try createForBookmarks(components.browserStateData)
            self.adapter = SimpleFetchedResultsAdapter(fetchedResultsController: fetchedResultsController)
        } catch let error {
            self.adapter = nil
            let alert = Utils.alertViewWithError(error, title: "History loading has failed!", delegate: nil)
            alert?.show()
        }

        if let adapter = adapter {
            adapter.changes
                .subscribe(onNext: { [weak self] changes in
                    self?.process(changes: changes)
                })
                .addDisposableTo(disposeBag)

            isEditing.asObservable()
                .distinctUntilChanged()
                .subscribe(onNext: { [weak self] isEditing in
                    self?.process(isEditing: isEditing)
                })
                .addDisposableTo(disposeBag)
        }
    }

    // MARK: -

    func bookmarksCount() -> Int {
        return model.count
    }

    func bookmark(for indexPath: IndexPath) -> BookmarkExtras? {
        return model[indexPath.row]
    }

    func didMoveBookmark(at indexPath: IndexPath, to toIndexPath: IndexPath) {
        assert(isEditing.value)

        let bookmark = model[indexPath.row]
        model.remove(at: indexPath.row)
        model.insert(bookmark, at: toIndexPath.row)
    }

    func delete(bookmark: BookmarkExtras) {
        components.browserStateData.deleteManagedObjects([bookmark])
    }

    func load(bookmark: BookmarkExtras) {
        if let urlString = bookmark.url, let url = URL(string: urlString) {
            components.browserController?.load(url)
            browserSignalSubject.onNext(.dismissModal)
        }
    }

    func enterEditMode() {
        isEditing.value = true
    }

    func leaveEditMode() {
        for (index, bookmark) in model.enumerated() {
            // New bookmarks have order number set to 0 and they are put at the end of the list
            let order = Int64(index - model.count)
            if bookmark.abp_order != order {
                bookmark.abp_order = order
            }
        }
        // Commit changes in ordering before leaving edit mode
        components.browserStateData.saveContextWithErrorAlert()

        isEditing.value = false
    }

    // MARK: - Private

    private func process(changes: SimpleFetchedResultsAdapterChanges<BookmarkExtras>) {
        if isEditing.value {
            let deletedItems = Set(changes.deletedItems.compactMap { $0.item })
            let deletedIndices = IndexSet(model.lazy
                .enumerated()
                .filter { deletedItems.contains($0.element) }
                .map { $0.offset })
            model.remove(at: deletedIndices)
            modelChanges.onNext([
                .deleteItems(deletedIndices.map { IndexPath(row: $0, section: 0) })
                ])
        } else {
            process(bookmarksChanges: changes)
        }
    }

    private func process(isEditing: Bool) {
        if isEditing {
            model = adapter?.fetchedResultsController.fetchedObjects ?? []
        } else {
            merge(with: adapter)
        }
    }
}

///
/// Create default instance of NSFetchedResultsController for BookmarksController.
///
private func createForBookmarks(_ browserStateData: BrowserStateCoreData)
    throws -> NSFetchedResultsController<BookmarkExtras> {
    let request: NSFetchRequest<BookmarkExtras> = browserStateData.fetchRequest(with: nil)
    let created = NSSortDescriptor(key: #keyPath(BookmarkExtras.abp_order), ascending: true)
    request.sortDescriptors = [created]
    request.fetchBatchSize = 20

    // Do not use cache!
    // NSFetchedResultsController has to be instantialized in order to update cache file.
    // Otherwise changes are not reflected in cache and it might be causing crashes or invalid data are shown.
    let fetchedResultsController = browserStateData.fetchController(for: request, withCacheName: nil)

    try fetchedResultsController.performFetch()
    return fetchedResultsController
}
