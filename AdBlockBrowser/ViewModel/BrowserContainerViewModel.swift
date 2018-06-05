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

enum BrowserControlSignals {
    case dismissModal
    case goBack
    case goForward
    case presentBookmarks
    case presentEditBookmark(BookmarkExtras)
}

enum BrowserContainerActions {
    case none
    case hideAllPopups
    case showBookmarksView
    case showTabsView
}

enum BrowserContainerTouchEvents {
    case bottomBar
    case tabsButton
    case favoriteButton
}

final class BrowserContainerViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents
    let tabsModel: TabsModel
    let ghostTabsModel: TabsModel
    let currentTabsModel: Variable<TabsModel>
    let signalSubject = PublishSubject<BrowserControlSignals>()

    let canGoBack: Observable<Bool>
    let canGoForward: Observable<Bool>
    let tabsCount: Observable<Int>
    let isAnyPopupShown: Observable<Bool>
    let isTabsButttonEnabled: Observable<Bool>
    let isFavoriteButtonEnabled: Observable<Bool>
    let isTabsButttonVisuallyEnabled: Observable<Bool>
    let isFavoriteButtonVisuallyEnabled: Observable<Bool>

    let isGhostModeEnabled = Variable(false)
    let isBrowserNavigationEnabled = Variable(false)
    let isTabsViewShown = Variable(false)
    let isBookmarksViewShown = Variable(false)
    let isHistoryViewShown = Variable(false)

    let searchPhrase = Variable(String?.none)
    let toolbarProgress = Variable(CGFloat(0))
    let actions = PublishSubject<Observable<BrowserContainerActions>>()
    let events = PublishSubject<BrowserContainerTouchEvents>()

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(components: ControllerComponents) {
        UserDefaults.standard.register(defaults: [ shouldDisplayGhostModeLeaveNotification: true ])

        self.components = components
        self.tabsModel = TabsModel(window: components.chrome.mainWindow)
        self.ghostTabsModel = TabsModel(window: components.chrome.incognitoWindow ?? components.chrome.mainWindow)
        self.currentTabsModel = Variable(self.tabsModel)

        let activeTab = components.chrome.rx
            .observe(ChromeTab.self, #keyPath(Chrome.focusedWindow.activeTab))

        self.canGoBack = activeTab
            .flatMapLatest { tab -> Observable<Bool> in
                if let tab = tab {
                    return tab.webView.rx
                        .observe(Bool.self, #keyPath(UIWebView.canGoBack))
                        .map { $0 ?? false }
                } else {
                    return Observable.just(false)
                }
            }
            .distinctUntilChanged()

        self.canGoForward = activeTab
            .flatMapLatest { tab -> Observable<Bool> in
                if let tab = tab {
                    return tab.webView.rx
                        .observe(Bool.self, #keyPath(UIWebView.canGoForward))
                        .map { $0 ?? false }
                } else {
                    return Observable.just(false)
                }
            }
            .distinctUntilChanged()

        components.chrome.rx
            .observe(ChromeWindow.self, #keyPath(Chrome.focusedWindow))
            .map { $0?.incognito ?? false }
            .distinctUntilChanged()
            .bind(to: isGhostModeEnabled)
            .addDisposableTo(disposeBag)

        isGhostModeEnabled.asObservable()
            .map { [ghostTabsModel, tabsModel] isGhostModeEnabled in
                if isGhostModeEnabled {
                    return ghostTabsModel
                } else {
                    return tabsModel
                }
            }
            .bind(to: currentTabsModel)
            .addDisposableTo(disposeBag)

        self.tabsCount = currentTabsModel.asObservable()
            .flatMapLatest { (tabs) -> Observable<Int> in
                let tabs = tabs
                return tabs.events.asObservable().map { [weak tabs] (_) in
                    return tabs?.count ?? 0
                }
            }
            .distinctUntilChanged()

        let isBookmarksViewShown = self.isBookmarksViewShown.asObservable()
        let isTabsViewShown = self.isTabsViewShown.asObservable()

        self.isAnyPopupShown = Observable
            .combineLatest(isBookmarksViewShown, isTabsViewShown, isHistoryViewShown.asObservable()) { $0 || $1 || $2 }
            .distinctUntilChanged()

        self.isTabsButttonVisuallyEnabled = Observable
            .combineLatest(isAnyPopupShown, isTabsViewShown) { !$0 || $1 }
            .distinctUntilChanged()

        self.isFavoriteButtonVisuallyEnabled = Observable
            .combineLatest(isAnyPopupShown, isBookmarksViewShown) { !$0 || $1 }
            .distinctUntilChanged()

        self.isTabsButttonEnabled = isHistoryViewShown.asObservable().map { !$0 }

        self.isFavoriteButtonEnabled = self.isTabsButttonEnabled

        events.asObserver()
            .filter { $0 == .bottomBar }
            .map { _ in return .just(.hideAllPopups) }
            .bind(to: actions)
            .addDisposableTo(disposeBag)

        events.asObserver()
            .filter { $0 == .tabsButton }
            .withLatestFrom(isTabsButttonVisuallyEnabled)
            .withLatestFrom(isTabsViewShown) { (isEnabled: $0, isTabsViewShown: $1) }
            .map { state in
                if state.isEnabled {
                    if state.isTabsViewShown {
                        return .just(.hideAllPopups)
                    } else {
                        return .just(.showTabsView)
                    }
                } else {
                    return Observable.just(.hideAllPopups)
                        .concat(Observable.just(.showTabsView).delay(animationDuration, scheduler: MainScheduler.instance))
                }
            }
            .bind(to: actions)
            .addDisposableTo(disposeBag)

        events.asObserver()
            .filter { $0 == .favoriteButton }
            .withLatestFrom(isFavoriteButtonVisuallyEnabled)
            .withLatestFrom(isBookmarksViewShown) { (isEnabled: $0, isBookmarksViewShown: $1) }
            .map { state in
                if state.isEnabled {
                    if state.isBookmarksViewShown {
                        return .just(.hideAllPopups)
                    } else {
                        return .just(.showBookmarksView)
                    }
                } else {
                    return Observable.just(.hideAllPopups)
                        .concat(Observable.just(.showBookmarksView).delay(animationDuration, scheduler: MainScheduler.instance))
                }
            }
            .bind(to: actions)
            .addDisposableTo(disposeBag)

        isHistoryViewShown.asObservable()
            .filter { $0 }
            .map { _ in return .just(.hideAllPopups) }
            .bind(to: actions)
            .addDisposableTo(disposeBag)

        self.actions.asObservable()
            .flatMapLatest { actions in
                return actions
            }
            .subscribe(onNext: { [weak self] action in
                switch action {
                case .none:
                    return
                case .hideAllPopups:
                    self?.isTabsViewShown.value = false
                    self?.signalSubject.onNext(.dismissModal)
                    return
                case .showBookmarksView:
                    self?.signalSubject.onNext(.presentBookmarks)
                    return
                case .showTabsView:
                    self?.isTabsViewShown.value = true
                    return
                }
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: -

    func switchToGhostMode() {
        components.chrome.incognitoWindow?.focused = true
    }

    func switchToNormalNode() {
        components.chrome.mainWindow?.focused = true
        if let window = components.chrome.incognitoWindow {
            let tabs = window.tabs as? [ChromeTab] ?? []
            window.remove(tabs: tabs)
        }
        UserDefaults.standard.set(false, forKey: shouldDisplayGhostModeLeaveNotification)
        UserDefaults.standard.synchronize()
    }

    func shouldDisplayLeaveGhostModeNotification() -> Bool {
        return UserDefaults.standard.bool(forKey: shouldDisplayGhostModeLeaveNotification)
    }
}

private let shouldDisplayGhostModeLeaveNotification = "ShouldDisplayGhostModeLeaveNotification"
