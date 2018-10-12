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

enum MenuItem: Int {
    case adblockingEnabled
    case openNewTab
    case addBookmark
    case share
    case history
    case settings
}

final class MenuViewModel: ViewModelProtocol {
    let components: ControllerComponents
    let extensionFacade: ABPExtensionFacadeProtocol
    var viewModel: BrowserViewModel
    let isBookmarked: Variable<Bool>
    let isHistoryViewShown: Variable<Bool>
    let isExtensionEnabled = Variable(false)
    let isPageWhitelisted = Variable(false)
    let isWhitelistable = Variable(false)

    private let disposeBag = DisposeBag()

    init(browserViewModel viewModel: BrowserViewModel) {
        self.components = viewModel.components
        self.extensionFacade = viewModel.components.extensionFacade
        self.viewModel = viewModel
        self.isBookmarked = viewModel.isBookmarked
        self.isHistoryViewShown = viewModel.isHistoryViewShown

        (self.extensionFacade as? NSObject)?.rx
            .observe(Bool.self, #keyPath(ABPExtensionFacade.extensionEnabled))
            .map({ $0 ?? false })
            .distinctUntilChanged()
            .bind(to: isExtensionEnabled)
            .addDisposableTo(disposeBag)

        let url = viewModel.url.asObservable()

        Observable.combineLatest(isExtensionEnabled.asObservable(), url) { enabled, url in
            return enabled && url != nil
        }
            .bind(to: isWhitelistable)
            .addDisposableTo(disposeBag)

        Observable.combineLatest(isExtensionEnabled.asObservable(), url) {
            (enabled: $0, url: $1)
        }
            .subscribe(onNext: { [weak self] combinedLatest in
                if combinedLatest.enabled, let url = combinedLatest.url {
                    self?.extensionFacade.isSiteWhitelisted(url.absoluteString) { boolValue, _ in
                        self?.isPageWhitelisted.value = boolValue
                    }
                } else {
                    self?.isPageWhitelisted.value = false
                }
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: -

    func shouldBeEnabled(_ menuItem: MenuItem) -> Bool {
        switch menuItem {
        case .adblockingEnabled, .addBookmark, .share:
            return isWhitelistable.value
        default:
            return true
        }
    }

    func handle(menuItem: MenuItem) {
        switch menuItem {
        case .adblockingEnabled:
            if let url = viewModel.currentURL.value?.absoluteString {
                let whitelisted = isPageWhitelisted.value
                extensionFacade.whitelistSite(url, whitelisted: !whitelisted) { [weak self] error in
                    self?.isPageWhitelisted.value = !whitelisted == (error == nil)
                }
            }
            return
        case .openNewTab:
            if let tab = components.chrome.focusedWindow?.add(tabWithURL: nil, atIndex: 0) {
                tab.active = true
                tab.window.focused = true
            }
        case .addBookmark:
            if isBookmarked.value {
                viewModel.removeBookmark()
            } else {
                viewModel.addBookmark()
            }
        case .share:
            viewModel.isShareDialogPresented.value = true
        case .history:
            isHistoryViewShown.value = true
        default:
            break
        }

        viewModel.isMenuViewShown.value = false
    }
}
