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

import MessageUI
import UIKit
import WebKit

class ImprintViewController: UIViewController, WKNavigationDelegate, MFMailComposeViewControllerDelegate {

    var viewModel: ImprintViewModel!
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = ImprintViewModel()
        setupWebView()
    }

    // MARK: - MFMailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true,
                           completion: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let mailScheme = "mailto"
        switch navigationAction.request.url?.scheme {
        case mailScheme?:
            if let uwViewModel = viewModel {
                let composeVC = MFMailComposeViewController()
                composeVC.mailComposeDelegate = self
                composeVC.setToRecipients([uwViewModel.eyeoInfoEmail])
                composeVC.setSubject(uwViewModel.mailSubject)
                composeVC.setMessageBody(uwViewModel.mailBody,
                                         isHTML: false)
                if MFMessageComposeViewController.canSendText() {
                    self.present(composeVC,
                                 animated: true,
                                 completion: nil)
                }
                decisionHandler(.cancel)
            }
        default:
            decisionHandler(.allow)
        }
    }

    // MARK: - Private

    private func setupWebView() {
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addConstraints(webView.sideMarginFullVertical(to: view))
        if let uwViewModel = viewModel {
            guard let imprint = uwViewModel.imprint else {
                return
            }
            webView.load(imprint)
        }
    }
}
