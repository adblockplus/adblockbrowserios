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

enum TabsEntry {
    case addNewTab
    case tab(ChromeTab)
    case tip
}

final class TabsViewModel: ViewModelProtocol {
    let components: ControllerComponents
    let currentTabsModel: Variable<TabsModel>
    let tabsEvents: Observable<TabsModelChangeEvent>
    let isGhostModeEnabled: Variable<Bool>
    let isShown: Variable<Bool>
    let isUndoToastShown = Variable(false)

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next function_body_length
    init(components: ControllerComponents,
         currentTabsModel: Variable<TabsModel>,
         isGhostModeEnabled: Variable<Bool>,
         isShown: Variable<Bool>) {
        self.components = components
        self.isGhostModeEnabled = isGhostModeEnabled
        self.isShown = isShown
        self.currentTabsModel = currentTabsModel

        self.tabsEvents = self.currentTabsModel.asObservable()
            .flatMapLatest { tabs in
                return tabs.events
            }
            .map { event in
                switch event {
                case .reload:
                    return .reload
                case .update(let set1, let set2):
                    let set1 = IndexSet(set1.map { $0 + 1 })
                    let set2 = IndexSet(set2.map { $0 + 1 })
                    return .update(set1, set2)
                }
            }
            .asObservable()

        let hiddenTabsObservable = self.currentTabsModel.asObservable()
            .flatMapLatest { tabs in
                return tabs.hiddenTabsObservable
            }
            .asObservable()

        let observable = hiddenTabsObservable
            .map { tabs -> Bool in
                return tabs.count > 0
            }
            .distinctUntilChanged()
            .flatMapLatest { isHidden -> Observable<Int> in
                if isHidden {
                    // Show toast
                    let hideAndRemove = Observable.just(1).delay(5.0, scheduler: MainScheduler.instance)
                    return Observable.just(0).concat(hideAndRemove)
                } else {
                    // Hide toast
                    return Observable.just(2)
                }
            }
            .shareReplayLatestWhileConnected()

        observable
            .subscribe(onNext: { [weak self] status in
                if status == 1 {
                    self?.removeHiddenTabs()
                } else if status == 2 {
                    self?.showHiddenTabs()
                }
            })
            .addDisposableTo(disposeBag)

        observable
            .map { $0 == 0 }
            .throttle(0.5, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bind(to: isUndoToastShown)
            .addDisposableTo(disposeBag)

        isShown.asDriver()
            .drive(onNext: { [weak self] isShown in
                if !isShown {
                    self?.removeHiddenTabs()
                }
            })
            .addDisposableTo(disposeBag)

        // Update active tab
        hiddenTabsObservable
            .subscribe(onNext: { [weak self] _ in
                self?.updateActiveTab()
            })
            .addDisposableTo(disposeBag)
    }

    func showNewTab() {
        if let tab = currentTabsModel.value.window.add(tabWithURL: nil, atIndex: 0) {
            tab.active = true
            tab.window.focused = true
            isShown.value = false
        }
    }

    func select(tab: ChromeTab) {
        // Select tab, update active status, use it as main webView and close popup.
        tab.active = true
        tab.window.focused = true
        isShown.value = false
    }

    func hide(tab: ChromeTab) {
        if !currentTabsModel.value.hiddenTabs.isEmpty {
            removeHiddenTabs()
        }
        currentTabsModel.value.update(hiddenTabs: [tab])
    }

    func showHiddenTabs() {
        currentTabsModel.value.update(hiddenTabs: Set<ChromeTab>())
    }

    func removeHiddenTabs() {
        currentTabsModel.value.window.remove(tabs: Array(currentTabsModel.value.hiddenTabs))
    }

    func entriesCount() -> Int {
        return currentTabsModel.value.count + 2
    }

    func entry(at indexPath: IndexPath) -> TabsEntry? {
        let index = indexPath.section
        if index == 0 {
            return .addNewTab
        } else if let chromeTab = currentTabsModel.value.element(at: index - 1) {
            return .tab(chromeTab)
        } else if index == currentTabsModel.value.count + 1 {
            return .tip
        } else {
            return nil
        }
    }

    // MARK: - private

    private func updateActiveTab() {
        if let activeTab = ChromeWindow.findActiveTab(currentTabsModel.value) {
            activeTab.active = true
        } else if !isGhostModeEnabled.value {
            DispatchQueue.main.async {
                self.showNewTab()
            }
        }
    }
}
