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

private var documentTitleHandle = "DocumentTitleHandle"

extension SAContentWebView {

    // MARK: - UIWebView

    open override func layoutSubviews() {
        super.layoutSubviews()
        if curtain != nil {
            curtain?.frame = CGRect(origin: CGPoint.zero, size: scrollView.contentSize)
        }
    }

    @objc
    open func navigationHistoryDidChange() {
        // Notify KVO
        willChangeValue(forKey: #keyPath(canGoBack))
        didChangeValue(forKey: #keyPath(canGoBack))
        willChangeValue(forKey: #keyPath(canGoForward))
        didChangeValue(forKey: #keyPath(canGoForward))
    }

    // MARK: - Public interface

    open override var bridgeSwitchboard: BridgeSwitchboard? {
        return contentScriptLoaderDelegate?.bridgeSwitchboard()
    }

    @objc public var historyManager: BrowserHistoryManager? {
        return chromeTab?.window.historyManager
    }

    @objc dynamic public var documentTitle: String? {
        get {
            return objc_getAssociatedObject(self, &documentTitleHandle) as? String
        }
        set {
            objc_setAssociatedObject(self, &documentTitleHandle, newValue?.trimmedDocumentTitle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc
    public func favicon(for url: URL?) -> FaviconFacade? {
        guard let url = url else {
            return nil
        }

        return historyManager?.faviconFor(urls: [url])
    }

    /// During swipe transitions, it usally take several seconds, until webView rerender itself.
    /// White curtain will hide this transition
    public func openCurtain() {
        if curtain == nil {
            let curtain = UIView()
            curtain.frame = CGRect(origin: .zero, size: scrollView.contentSize)
            curtain.backgroundColor = UIColor.white
            scrollView.addSubview(curtain)
            self.curtain = curtain
        }
    }

    @objc
    public func closeCurtain() {
        curtain?.removeFromSuperview()
        curtain = nil
    }

    func loadFaviconsWith(_ array: Any?) -> Bool {
        guard let array = array as? [Any] else {
            Log.warn("Unsupported type of properties")
            return false
        }
        if let currentRequest = currentRequest {
            faviconLoader?.load(array.compactMap { FaviconSource(object: $0) }, fromRequest: currentRequest)
        }
        return true
    }
}
