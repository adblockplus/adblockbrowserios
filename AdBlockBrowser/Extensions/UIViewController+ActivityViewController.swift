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

extension UIViewController {
    func presentActivityViewController(_ url: NSURL?,
                                       title: String?,
                                       anchorView: UIView?,
                                       webView: SAContentWebView?,
                                       completion: @escaping (Bool) -> Void) {
        guard let webView = webView, let url = webView.currentURL else {
            completion(false)
            return
        }

        let factory = SharingIntentFactory()
        // function needed, the controller is possibly presented asynchronously
        let makeAndPresent = {[weak self] (activityItems: [AnyObject]) -> Void in
            let controller = SharingIntentFactory.makeController(
                factory,
                activityItems: activityItems,
                excludedActivities: [
                    UIActivityType.assignToContact,
                    UIActivityType.postToWeibo,
                    UIActivityType.addToReadingList],
                completion: { completed, _ -> Void in
                    // error was ignored in the original code too
                    completion(completed)
            }
            )
            // iPad implements activity controller as popover and it needs positioning anchor.
            // The anchoring makes no visual difference on iPhone but prevents iPad from crashing.
            if let menuButton = anchorView {
                controller.popoverPresentationController?.sourceView = menuButton
                // align to middle of top edge
                controller.popoverPresentationController?.sourceRect = CGRect(x: menuButton.bounds.midX, y: 0, width: 0, height: 0)
            } else {
                // menu button outlet not connected, emergency setting
                // iPad popover will appear in wrong place but will not crash
                controller.popoverPresentationController?.sourceView = self?.view
            }
            self?.present(controller, animated: true, completion: nil)
        }
        var items = [AnyObject]()
        if let title = webView.documentTitle {
            items.append(TitleTextItemProvider(title: title))
        }
        guard let defaultProvider = SharingURLItemProvider(url: url, title: webView.documentTitle) else {
            completion(false)
            return
        }
        // It's needed to add EITHER url OR the password item provider, but not both
        // Otherwise some sharing activities will be missing. @see PasswordMgrItemProvider
        if PasswordMgrItemProvider.isPasswordMgrAvailable() {
            PasswordMgrItemProvider.create(webView, defaultProvider: defaultProvider, completionHandler: { itemSource, error -> Void in
                // read the doc for explanation of this pattern
                if error == nil, let itemSource = itemSource {
                    factory.add(matcher: itemSource.matches, handler: itemSource.handles, activity: nil)
                    items.append(itemSource)
                }
                makeAndPresent(items)
            })
        } else {
            items.append(defaultProvider)
            makeAndPresent(items)
        }
    }
}
