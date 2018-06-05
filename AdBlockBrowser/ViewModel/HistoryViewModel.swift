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

final class HistoryViewModel: ViewModelProtocol {
    typealias HistoryModelChanges = (
        deletedSections: IndexSet,
        insertedSections: IndexSet,
        deletedItems: [IndexPath],
        insertedItems: [IndexPath],
        updatedItems: [IndexPath]
    )

    let components: ControllerComponents
    let historyManager: BrowserHistoryManager
    let isHistoryViewShown: Variable<Bool>
    let adapter: FetchedResultsAdapter<HistoryUrl>?

    let changes = PublishSubject<HistoryModelChanges>()

    private let disposeBag = DisposeBag()

    init(viewModel: MenuViewModel) {
        self.components = viewModel.components
        self.historyManager = components.historyManager
        self.isHistoryViewShown = viewModel.isHistoryViewShown

        do {
            let fetchedResultsController = try createForHistory(components.browserStateData)
            self.adapter = FetchedResultsAdapter(fetchedResultsController: fetchedResultsController)
        } catch let error {
            self.adapter = nil
            let alert = Utils.alertViewWithError(error, title: "History loading has failed!", delegate: nil)
            alert?.show()
        }

        if let adapter = adapter {
            adapter.changes
                .map { changes in
                    let reduce = { (items: [(indexPath: IndexPath, HistoryUrl?)]) in
                        return items.compactMap { $0.indexPath.section == 0  ? $0.indexPath : nil }
                    }
                    return (
                        changes.deletedSections,
                        changes.insertedSections,
                        reduce(changes.deletedItems),
                        reduce(changes.insertedItems),
                        reduce(changes.updatedItems)
                    )
                }
                .bind(to: changes)
                .addDisposableTo(disposeBag)
        }
    }

    // MARK: -

    func load(historyUrl: HistoryUrl) {
        if let urlString = historyUrl.url, let url = URL(string: urlString) {
            components.browserController?.load(url)
        }
    }
}

extension HistoryUrl {
    ///
    /// Custom section identifier allows items to be group by days
    ///
    @objc var sectionIdentifier: String {
        // Another unexpected crash on production, lastVisited can be nil in some situations.
        let lastVisited = self.lastVisited ?? Date()
        let date = BrowserHistoryManager.calendar.date(bySettingHour: 0, minute: 0, second: 0, of: lastVisited)
        return "\(date?.timeIntervalSince1970 ?? 0)"
    }
}

///
/// Create default instance of NSFetchedResultsController for HistoryController.
///
private func createForHistory(_ browserStateData: BrowserStateCoreData) throws -> NSFetchedResultsController<HistoryUrl> {
    let request: NSFetchRequest<HistoryUrl> = browserStateData.fetchRequest(with: nil)
    let created = NSSortDescriptor(key: #keyPath(HistoryUrl.lastVisited), ascending: false)
    request.sortDescriptors = [created]
    request.fetchBatchSize = 20

    let fetchedResultsController = browserStateData.fetchController(for: request,
                                                                    sectionNameKeyPath: #keyPath(HistoryUrl.sectionIdentifier),
                                                                    cacheName: nil)

    try fetchedResultsController.performFetch()
    return fetchedResultsController
}
