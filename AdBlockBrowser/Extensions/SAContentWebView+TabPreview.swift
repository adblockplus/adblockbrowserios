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

// MARK: - Rendering preview

let tabPreviewPreferredWidth = CGFloat(88)
let tabPreviewPreferredHeight = CGFloat(67)

extension SAContentWebView {
    func updatePreview() {
        if let tab = chromeTab {
            let contextSize = CGSize(width: tabPreviewPreferredWidth, height: tabPreviewPreferredHeight)
            UIGraphicsBeginImageContextWithOptions(contextSize, false, UIScreen.main.scale)

            // We want to preserve aspect ratio of scrollview and fill entire context
            let size = scrollView.frame.size

            if abs(size.width) < 1 || abs(size.height) < 1 {
                return
            }

            let frameHeight = size.height - scrollView.contentInset.top
            let ratio = size.width / frameHeight

            let width: CGFloat
            let height: CGFloat

            if ratio < tabPreviewPreferredWidth / tabPreviewPreferredHeight {
                width = tabPreviewPreferredWidth
                height = ceil(tabPreviewPreferredWidth / ratio)
            } else {
                height = tabPreviewPreferredHeight
                width = ceil(tabPreviewPreferredHeight * ratio)
            }

            assert(width >= tabPreviewPreferredWidth && height >= tabPreviewPreferredHeight)

            let overflow = ceil(scrollView.contentInset.top / frameHeight * height)

            UIColor.white.setFill()
            UIRectFill(CGRect(origin: CGPoint.zero, size: contextSize))
            scrollView.drawHierarchy(in: CGRect(x: 0, y: -overflow, width: width, height: height + overflow), afterScreenUpdates: false)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            tab.preview = image
        }
    }
}

extension SAContentWebView {
    // We need to update after certain events. Subclassing of SAContentWebView is not possible.
    // SAContentWebView does not provides way to attach persistent event handler.
    // Method swizzling is reasonable solution in this limited time.
    static func swizzleWebViewDelegateMethods() {
        SAContentWebView.self.swizzle(method: #selector(UIWebViewDelegate.webViewDidStartLoad(_:)),
                                      for: #selector(SAContentWebView.abp_webViewDidStartLoad(_:)))
        SAContentWebView.self.swizzle(method: #selector(UIWebViewDelegate.webViewDidFinishLoad(_:)),
                                      for: #selector(SAContentWebView.abp_webViewDidFinishLoad(_:)))
    }

    // MARK: - Method Swizzling

    @objc
    fileprivate func abp_webViewDidStartLoad(_ webView: UIWebView) {
        self.abp_webViewDidStartLoad(webView)

        // Update screenshot (also to clear it when loading a new page)
        if let contentWebView = webView as? SAContentWebView {
            contentWebView.updatePreview()
        }
    }

    @objc
    fileprivate func abp_webViewDidFinishLoad(_ webView: UIWebView) {
        self.abp_webViewDidFinishLoad(webView)

        // Update screenshot
        if let contentWebView = webView as? SAContentWebView {
            contentWebView.updatePreview()
        }
    }
}
