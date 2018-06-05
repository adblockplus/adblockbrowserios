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

@testable import AdblockBrowser
import RxSwift
import XCTest

extension ControllersTests {
    class Box {
        var bookmarks = [BookmarkExtras]()
    }
    // swiftlint:disable:next function_body_length
    func testFetchedResultAdapterController() {
        let isExampleBookmark = { (bookmark: BookmarkExtras) -> Bool in
            bookmark.title?.hasPrefix("Example ") ?? false
        }

        let data = components.browserStateData
        let allBookmarks: [BookmarkExtras] = data.fetch() ?? []
        data.deleteManagedObjects(allBookmarks.filter(isExampleBookmark))

        // MARK: - Controllers

        let isGhostModeEnabled = Variable(false)
        let bookmarksViewModel = BookmarksViewModel(components: components,
                                                    isGhostModeEnabled: isGhostModeEnabled,
                                                    browserSignalSubject: PublishSubject<BrowserControlSignals>())
        XCTAssert(bookmarksViewModel.adapter != nil)
        let bookmarksViewController = loadController(with: bookmarksViewModel) as BookmarksViewController

        let dashboardViewModel = DashboardViewModel(components: components,
                                                    isGhostModeEnabled: isGhostModeEnabled,
                                                    browserSignalSubject: PublishSubject<BrowserControlSignals>())
        XCTAssert(dashboardViewModel.adapter != nil)
        let dashboardViewController = loadController(with: dashboardViewModel) as DashboardViewController

        _ = dashboardViewController.collectionView!.cellForItem(at: IndexPath(row: 0, section: 0))

        // MARK: - Checkers

        let checkBookmarksView = { (bookmarks: [BookmarkExtras]) in
            XCTAssert(bookmarksViewController.tableView!.numberOfRows(inSection: 0) == bookmarks.count)
            for (index, bookmark) in bookmarks.enumerated() {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = bookmarksViewController.tableView!.cellForRow(at: indexPath) {
                    // swiftlint:disable:next force_cast
                    XCTAssert((cell as! BookmarkCell).textLabel!.text == bookmark.title)
                }
            }
        }

        let checkDashboardView = { (bookmarks: [BookmarkExtras]) in
            XCTAssert(dashboardViewController.collectionView!.numberOfItems(inSection: 0) == bookmarks.count)
        }

        // MARK: - Tests

        let dashboardBox = Box()
        dashboardBox.bookmarks = (dashboardViewModel.adapter?.fetchedResultsController.fetchedObjects)!

        let bookmarksBox = Box()
        bookmarksBox.bookmarks = (bookmarksViewModel.adapter?.fetchedResultsController.fetchedObjects)!

        let disposable1 = dashboardViewModel.adapter!.changes.subscribe(onNext: { changes in
            dashboardBox.bookmarks.merge(changes: changes)
        })

        defer {
            disposable1.dispose()
        }

        let disposable2 = bookmarksViewModel.adapter!.changes.subscribe(onNext: { changes in
            bookmarksBox.bookmarks.merge(changes: changes)
        })

        defer {
            disposable2.dispose()
        }

        let createBookmark = { (index: Int) -> BookmarkExtras in
            let bookmark: BookmarkExtras? = data.createObject()
            bookmark!.title = "Example \(index)"
            bookmark!.url = "http://example.com"
            bookmark!.abp_showInDashboard = true
            bookmark!.abp_dashboardOrder = Int64(index)
            bookmark!.abp_order = Int64(index)
            return bookmark!
        }

        var bookmarks = [BookmarkExtras?](repeating: nil, count: 64)
        for counter in 0..<48 {
            var toRemove = [BookmarkExtras]()
            for index in 0..<bookmarks.count {
                if let bookmark = bookmarks[index] {
                    if arc4random_uniform(3) < 1 || counter == 16 {
                        toRemove.append(bookmark)
                        bookmarks[index] = nil
                    } else if arc4random_uniform(3) < 1 {
                        bookmark.dateLastOpened = Date().timeIntervalSince1970
                    }
                } else {
                    if arc4random_uniform(3) < 1 && counter != 16 {
                        bookmarks[index] = createBookmark(index)
                    }
                }
            }

            if toRemove.count > 0 {
                data.deleteManagedObjects(toRemove)
            } else {
                data.saveContextWithErrorAlert()
            }

            let bookmarks1 = bookmarks.compactMap { $0 }
            let bookmarks2 = bookmarksBox.bookmarks.filter(isExampleBookmark).compactMap { $0 }
            XCTAssert(bookmarks1 == bookmarks2)
            checkBookmarksView(bookmarksBox.bookmarks)
            checkDashboardView(dashboardBox.bookmarks)
        }

        data.deleteManagedObjects(bookmarks.compactMap { $0 })
    }
}
