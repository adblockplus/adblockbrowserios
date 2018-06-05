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

import UIKit

final class ClearDataViewController: SettingsTableViewController<ClearDataViewModel> {
    @IBOutlet weak var clearHistoryButton: UIButton?
    @IBOutlet weak var clearCacheButton: UIButton?
    @IBOutlet weak var clearCookiesButton: UIButton?
    @IBOutlet weak var clearAllButton: UIButton?

    private enum ClearMethod: Int {
        case history
        case cache
        case cookies
        case all

        static let allValues = [history, cache, cookies, all]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Clear Browsing Data",
                                                 comment: "Clear Browsing Data Screen Title")

        for method in ClearMethod.allValues {
            guard let button = clearMethodButton(method) else {
                continue
            }
            button.titleLabel?.numberOfLines = 2
            button.setTitle(clearMethodLabel(method), for: UIControlState.normal)
        }
    }

    @IBAction func onClearButtonClick(_ sender: UIButton) {
        for method in ClearMethod.allValues {
            guard let button = clearMethodButton(method) else {
                continue
            }
            if button == sender {
                confirmAndClear(method)
                break
            }
        }
    }

    // MARK: - Private

    private func confirmAndClear(_ method: ClearMethod) {
        let message = NSLocalizedString(
            "This action cannot be undone. Are you sure you want to continue?",
            comment: "Clear Browsing Data Confirmation")
        let alert = UIAlertController(
            title: clearMethodLabel(method),
            message: message,
            preferredStyle: .alert)

        let clearTitle = NSLocalizedString("Clear", comment: "Clear Browsing Data Confirmation")

        alert.addAction(UIAlertAction(
            title: clearTitle,
            style: .destructive, handler: { _ in
                self.clearMethodFunction(method)()
        }))
        // Buttons of type .Cancel are always on the first left position, but design requires it on the right
        alert.addAction(UIAlertAction(title: LocalizationResources.alertCancelText(), style: .default, handler: nil))
        UIHandler.presentModal(alert, inController: self)
    }

    private func clearMethodLabel(_ method: ClearMethod) -> String {
        switch method {
        case .history:
            return NSLocalizedString("Clear History", comment: "Clear Browsing Data Option")
        case .cache:
            return NSLocalizedString("Clear Cache", comment: "Clear Browsing Data Option")
        case .cookies:
            return NSLocalizedString("Clear Cookies & Site Data", comment: "Clear Browsing Data Option")
        case .all:
            return NSLocalizedString("Clear All", comment: "Clear Browsing Data Option")
        }
    }

    private func clearMethodButton(_ method: ClearMethod) -> UIButton? {
        switch method {
        case .history:
            return clearHistoryButton
        case .cache:
            return clearCacheButton
        case .cookies:
            return clearCookiesButton
        case .all:
            return clearAllButton
        }
    }

    private func clearMethodFunction(_ method: ClearMethod) -> () -> Void {
        switch method {
        case .history:
            return {
                self.viewModel?.clearHistory()
            }
        case .cache:
            return {
                self.clearCache()
            }
        case .cookies:
            return {
                self.clearCookies()
            }
        case .all:
            return {
                self.viewModel?.clearHistory()
                self.clearCookies()
                self.clearCache()
                // nothing else to do here, dismiss controller
                _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }

    private func clearCache() {
        let cache = URLCache.shared
        cache.removeAllCachedResponses()
    }

    private func clearCookies() {
        let cookieJar = HTTPCookieStorage.shared
        let hasSelector = cookieJar.responds(to: #selector(HTTPCookieStorage.removeCookies(since:)))
        /*
         removeCookiesSinceDate is in Cocoa headers since iOS 8.0 but still not in official
         Apple reference as of 9.1. Anyway works reliably only on iOS9+, appeared to be working
         in iOS 8.1 but crashes reported in iOS 8.4. Stacktrace:
         1. NSHTTPCookieStorage.removeCookiesSinceDate
         2. HTTPCookieStorage.deleteCookiesSinceDate
         3. DiskCookieStorage.deleteAllCookiesSinceDateLocked
         4. MemoryCookies.visitCookies EXC_BAD_ACCESS
         */
        let osMajorVersion = ProcessInfo().operatingSystemVersion.majorVersion
        if hasSelector && osMajorVersion >= 9 {
            let date = Date(timeIntervalSinceReferenceDate: 0.0)
            cookieJar.removeCookies(since: date)
        } else if let cookies = cookieJar.cookies {
            // swiftlint:disable:next unused_enumerated
            for (_, cookie) in cookies.enumerated() {
                cookieJar.deleteCookie(cookie)
            }
        }
    }
}
