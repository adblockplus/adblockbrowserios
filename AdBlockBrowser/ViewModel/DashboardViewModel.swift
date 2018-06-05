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

typealias DashboardModelChange = BookmarksModelChange

final class DashboardViewModel: ViewModelProtocol, BookmarksBaseViewModel {
    let components: ControllerComponents
    let isGhostModeEnabled: Variable<Bool>
    let browserSignalSubject: PublishSubject<BrowserControlSignals>
    let adapter: SimpleFetchedResultsAdapter<BookmarkExtras>?

    var model = [BookmarkExtras]()
    let modelChanges = PublishSubject<[DashboardModelChange]>()

    let isReordering = Variable(false)

    private let disposeBag = DisposeBag()

    init(components: ControllerComponents,
         isGhostModeEnabled: Variable<Bool>,
         browserSignalSubject: PublishSubject<BrowserControlSignals>) {
        self.components = components
        self.isGhostModeEnabled = isGhostModeEnabled
        self.browserSignalSubject = browserSignalSubject

        do {
            let fetchedResultsController = try createForDashboard(components.browserStateData)
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

            isReordering.asObservable()
                .distinctUntilChanged()
                .subscribe(onNext: { [weak self] isReordering in
                    self?.process(isReordering: isReordering)
                })
                .addDisposableTo(disposeBag)
        }
    }

    // MARK: -

    func load(bookmark: BookmarkExtras) {
        if let urlString = bookmark.url, let url = URL(string: urlString) {
            components.browserController?.load(url)
        }
    }

    func didMoveItem(at indexPath: IndexPath, to toIndexPath: IndexPath) {
        assert(isReordering.value)

        let bookmark = model[indexPath.row]
        model.remove(at: indexPath.row)
        model.insert(bookmark, at: toIndexPath.row)
        modelChanges.onNext([.moveItem(indexPath, toIndexPath)])

        for (index, bookmark) in model.enumerated() {
            // Indexing start from negative values
            // and every new incomming dashboard item will have order set to possitive number
            // so that it will always go behind current content.
            let order = Int64(index - model.count)
            if bookmark.abp_dashboardOrder != order {
                bookmark.abp_dashboardOrder = order
            }
        }

        components.browserStateData.saveContextWithErrorAlert()
    }

    // MARK: - Private

    private func process(changes: SimpleFetchedResultsAdapterChanges<BookmarkExtras>) {
        if isReordering.value {
            return
        }

        process(bookmarksChanges: changes)
    }

    private func process(isReordering: Bool) {
        if isReordering {
            model = adapter?.fetchedResultsController.fetchedObjects ?? []
        } else {
            merge(with: adapter)
        }
    }
}

private func createForDashboard(_ browserStateData: BrowserStateCoreData)
    throws -> NSFetchedResultsController<BookmarkExtras> {
    let predicate = NSPredicate(format: "abp_showInDashboard = TRUE")
    let request: NSFetchRequest<BookmarkExtras> = browserStateData.fetchRequest(with: predicate)
    let dashboardOrder = NSSortDescriptor(key: #keyPath(BookmarkExtras.abp_dashboardOrder), ascending: true)
    request.sortDescriptors = [dashboardOrder]
    request.fetchBatchSize = 20
    let fetchedResultsController = browserStateData.fetchController(for: request, withCacheName: nil)
    try fetchedResultsController.performFetch()
    return fetchedResultsController
}

func hintDashboardOrder() -> Int64 {
    return abs(Int64(Date().timeIntervalSince1970))
}
