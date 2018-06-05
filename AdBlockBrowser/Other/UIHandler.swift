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

import WebKit

final class UIHandler: NSObject, WKUIDelegate {
    let presenting: UIViewController

    init(presenting: UIViewController) {
        self.presenting = presenting
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: frame.request.url?.absoluteString, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizationResources.alertOKText(), style: .default, handler: { _ in
            completionHandler()
        }))
        UIHandler.presentModal(alert, inController: presenting)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: frame.request.url?.absoluteString, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizationResources.alertCancelText(), style: .cancel, handler: { _ in
            completionHandler(false)
        }))
        alert.addAction(UIAlertAction(title: LocalizationResources.alertOKText(), style: .default, handler: { _ in
            completionHandler(true)
        }))
        UIHandler.presentModal(alert, inController: presenting)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: frame.request.url?.absoluteString, message: prompt, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { textField -> Void in
            textField.text = defaultText
        })
        alert.addAction(UIAlertAction(title: LocalizationResources.alertCancelText(), style: .cancel, handler: { _ in
            completionHandler(nil)
        }))
        alert.addAction(UIAlertAction(title: LocalizationResources.alertOKText(), style: .default, handler: { _ in
            let textField = alert.textFields?.first
            let text = textField?.text ?? ""
            completionHandler(text)
        }))
        UIHandler.presentModal(alert, inController: presenting)
    }

    static func presentModal(_ viewController: UIViewController, inController: UIViewController) {
        var presenting = inController
        while let presentedVC = presenting.presentedViewController {
            presenting = presentedVC
        }
        presenting.present(viewController, animated: true, completion: nil)
    }
}
