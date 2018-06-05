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

let webViewBackgroundTag = 123123

extension UIScrollView {
    // Background should have same size as its parent
    static func swizzleLayoutMethod() {
        UIScrollView.self.swizzle(method: #selector(UIView.layoutSubviews),
                                  for: #selector(UIScrollView.abp_layoutSubviews))
    }

    // MARK: - Method Swizzling

    @objc
    fileprivate func abp_layoutSubviews() {
        self.abp_layoutSubviews()

        if superview is SAContentWebView {
            let backgroundView: UIView
            if let uwBackgroundView = self.backgroundView {
                backgroundView = uwBackgroundView
            } else {
                backgroundView = UIView()
                backgroundView.tag = webViewBackgroundTag
                backgroundView.backgroundColor = UIColor.white
                addSubview(backgroundView)
                sendSubview(toBack: backgroundView)
            }
            backgroundView.frame = CGRect(origin: CGPoint.zero, size: contentSize)
        }
    }

    // MARK: - Private

    fileprivate var backgroundView: UIView? {
        return viewWithTag(webViewBackgroundTag)
    }
}
