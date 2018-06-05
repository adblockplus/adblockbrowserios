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
import RxCocoa
import RxSwift

enum AddressTrustState: Equatable {
    case none
    case broken
    case trusted
    case extended(holderName: String?)
}

func == (lhs: AddressTrustState, rhs: AddressTrustState) -> Bool {
    switch(lhs, rhs) {
    case (.none, .none):
        return true
    case (.broken, .broken):
        return true
    case (.trusted, .trusted):
        return true
    case (.extended(let lholder), .extended(let rholder)):
        return lholder == rholder
    default:
        return false
    }
}

final class BrowserViewModel: ViewModelProtocol {
    let components: ControllerComponents
    let chrome: Chrome
    weak var contextMenuDataSource: ContextMenuDataSource?
    weak var webNavigationEventsDelegate: WebNavigationEventsDelegate?
    weak var contentScriptLoaderDelegate: ContentScriptLoaderDelegate?
    let browserStateData: BrowserStateCoreData
    let historyManager: BrowserHistoryManager
    let autocompleteDataSource: OmniboxDataSource
    let currentTabsModel: Variable<TabsModel>
    let signalSubject: PublishSubject<BrowserControlSignals>
    let isGhostModeEnabled: Variable<Bool>
    let isBrowserNavigationEnabled: Variable<Bool>
    let isTabsViewShown: Variable<Bool>
    let isBookmarksViewShown: Variable<Bool>
    let isHistoryViewShown: Variable<Bool>
    let searchPhrase: Variable<String?>
    let toolbarProgress: Variable<CGFloat>
    let tabsCount: Observable<Int>

    // Owned properties
    let activeTab = Variable(ChromeTab?.none)
    let addressTrustState = Variable(AddressTrustState.none)
    let currentURL = Variable(URL?.none)
    let progress = Variable(Double(0))
    let url = Variable(URL?.none)
    let bookmarksViewWillBeDismissed = PublishSubject<Void>()

    // UI Variables
    let isMenuViewShown = Variable(false)
    let isBookmarked = Variable(false)
    let isShareDialogPresented = Variable(false)
    let isAddressBarEdited = Variable(false)

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next function_body_length
    init(browserContainerViewModel viewModel: BrowserContainerViewModel) {
        self.components = viewModel.components
        self.chrome = components.chrome
        self.contextMenuDataSource = components.contextMenuProvider
        self.webNavigationEventsDelegate = components.browserStateModel
        self.contentScriptLoaderDelegate = components.browserStateModel
        self.browserStateData = components.browserStateData
        self.historyManager = components.historyManager
        self.autocompleteDataSource = components.autocompleteDataSource
        self.currentTabsModel = viewModel.currentTabsModel
        self.signalSubject = viewModel.signalSubject
        self.isGhostModeEnabled = viewModel.isGhostModeEnabled
        self.isBrowserNavigationEnabled = viewModel.isBrowserNavigationEnabled
        self.isTabsViewShown = viewModel.isTabsViewShown
        self.isBookmarksViewShown = viewModel.isBookmarksViewShown
        self.isHistoryViewShown = viewModel.isHistoryViewShown
        self.searchPhrase = viewModel.searchPhrase
        self.toolbarProgress = viewModel.toolbarProgress
        self.tabsCount = viewModel.tabsCount

        components.chrome.rx
            .observe(ChromeTab.self, #keyPath(Chrome.focusedWindow.activeTab))
            .distinctUntilChanged(==)
            .bind(to: activeTab)
            .addDisposableTo(disposeBag)
        components.chrome.rx
            .observe(AuthenticationResultProtocol.self, #keyPath(Chrome.focusedWindow.activeTab.authenticationResult))
            .map { result in
                if let result = result {
                    switch result.level {
                    case .trustExtended:
                        return .extended(holderName: result.evOrgName)
                    case .trustImplicit:
                        return .trusted
                    case .trustForced:
                        return .broken
                    default:
                        return .none
                    }
                } else {
                    return .none
                }
            }
            .bind(to: addressTrustState)
            .addDisposableTo(disposeBag)
        components.chrome.rx
            .observe(NSURL.self, #keyPath(Chrome.focusedWindow.activeTab.URL))
            .map({ $0 as URL? })
            .distinctUntilChanged(==)
            .bind(to: currentURL)
            .addDisposableTo(disposeBag)
        components.chrome.rx
            .observe(Double.self, #keyPath(Chrome.focusedWindow.activeTab.progress))
            .map({ $0 ?? 0.0 })
            .distinctUntilChanged(==)
            .bind(to: progress)
            .addDisposableTo(disposeBag)

        currentURL.asObservable()
            .map({ url -> URL? in
                if let url = url, !(url as NSURL).shouldBeHidden() {
                    return url
                } else {
                    return nil
                }
            })
            .distinctUntilChanged(==)
            .bind(to: url)
            .addDisposableTo(disposeBag)

        let isAnyBookmarkChanged = NotificationCenter.default.rx
            .notification(.NSManagedObjectContextDidSave)
            .map { notification in
                for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
                    if let objects = notification.userInfo?[key] as? Set<AnyHashable> {
                        for object in objects where object is Bookmark {
                            return true
                        }
                    }
                }
                return false
            }
            .filter { isAnyBookmarkChanged in isAnyBookmarkChanged }
            .startWith(true)

        Observable.combineLatest(url.asObservable(), isAnyBookmarkChanged) { (url: $0, $1) }
            .map({ [weak self] status in
                if let url = status.url {
                    return self?.fetchBookmarks(for: url)?.count ?? 0 > 0
                } else {
                    return false
                }
            })
            .distinctUntilChanged()
            .bind(to: isBookmarked)
            .addDisposableTo(disposeBag)

        bookmarksViewWillBeDismissed
            .map { _ in false }
            .bind(to: isBookmarksViewShown)
            .addDisposableTo(disposeBag)

        viewModel.events.asObserver()
            .map { _ in false }
            .bind(to: isMenuViewShown)
            .addDisposableTo(disposeBag)
    }

    // MARK: -

    func didBecomeRootView() {
        if isHistoryViewShown.value {
            isHistoryViewShown.value = false
        }
    }

    func fetchBookmarks(for url: URL) -> [BookmarkExtras]? {
        if !(url as NSURL).shouldBeHidden() {
            let urlString = url.absoluteString
            let predicate = NSPredicate(format: "url == %@", urlString)
            return browserStateData.fetch(predicate)
        }
        return nil
    }

    func addBookmark() {
        if let bookmark = browserStateData.insertNewObject(forEntityClass: BookmarkExtras.self) as? BookmarkExtras {

            bookmark.url = currentURL.value?.absoluteString

            var title: String? = nil
            if let documentTitle = activeTab.value?.documentTitle {
                title = documentTitle
            } else {
                title = activeTab.value?.URL?.host
            }

            // I somehow managed to store title with leading spaces
            // and new line characters. It does not behaved well.
            title = title?.replacingOccurrences(of: "\\n", with: "")
            title = title?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            bookmark.title = title
            bookmark.icon = activeTab.value?.webView.currentFavicon as? UrlIcon

            browserStateData.saveContextWithErrorAlert()
        }
    }

    func removeBookmark() {
        if let url = currentURL.value {
            if let result = fetchBookmarks(for: url) {
                browserStateData.deleteManagedObjects(result)
                browserStateData.saveContextWithErrorAlert()
            }
        }
    }

    func changeBookmarkedStatus() {
        if isBookmarked.value {
            removeBookmark()
        } else {
            addBookmark()
        }
    }

    func toggleMenu() {
        isMenuViewShown.value = !isMenuViewShown.value
    }
}
