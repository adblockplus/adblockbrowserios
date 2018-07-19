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

private var tabIdentifier: UInt = 0

@objc protocol ChromeTabDataProtocol {
    var documentTitle: String? { get set }
    var url: String? { get set }
    var active: NSNumber? { get set }
    var opening: NSSet? { get set }
    var activityTimestamp: Date? { get set }
    var restorableState: Data? { get set }
}

protocol ChromeTabDataProtocolEx: ChromeTabDataProtocol {
    associatedtype ChromeWindowDataType

    var window: ChromeWindowDataType { get set }
    var opener: Self? { get set }
}

struct ContentWebViewUpdatedProperties: OptionSet {
    let rawValue: UInt

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    static var None = ContentWebViewUpdatedProperties(rawValue: 0)
    static var Status = ContentWebViewUpdatedProperties(rawValue: 1 << 0)
    static var Url = ContentWebViewUpdatedProperties(rawValue: 1 << 1)
    static var Favicon = ContentWebViewUpdatedProperties(rawValue: 1 << 2)
}

@objc
open class ChromeTab: NSObject {
    @objc open let identifier: UInt
    open unowned let window: ChromeWindow
    open let incognito: Bool
    open weak var openerTab: ChromeTab?
    open weak var openerFrame: KittFrame?

    @objc dynamic open var URL: NSURL? {
        didSet {
            if let tabData = tabData, URL != oldValue {
                tabData.url = URL?.absoluteString
                updatedProperties = [updatedProperties, .Url]
                window.setNeedsCommit()
            }
        }
    }

    @objc dynamic open var documentTitle: String? {
        get { return tabData?.documentTitle }
        set {
            if let tabData = tabData, documentTitle != newValue {
                tabData.documentTitle = newValue
                window.setNeedsCommit()
            }
        }
    }

    @objc dynamic open var active: Bool {
        get { return (tabData?.active as? Bool) ?? false }
        set {
            if let tabData = tabData, active != newValue {
                tabData.active = NSNumber(value: newValue)
                if newValue {
                    // refresh the activity timestamp 
                    tabData.activityTimestamp = Date()
                    window.activeTab = self
                }
                window.setNeedsCommit()
            }
        }
    }

    @objc dynamic open var status: ContentWebViewStatus {
        didSet {
            if status != oldValue {
                updatedProperties = [updatedProperties, .Status]
                window.setNeedsCommit()
            }
        }
    }

    @objc dynamic open var faviconURL: Foundation.URL? {
        didSet {
            if faviconURL != oldValue {
                updatedProperties = [updatedProperties, .Favicon]
                window.setNeedsCommit()
            }
        }
    }

    @objc dynamic open fileprivate(set) var hibernated: Bool
    @objc dynamic open var faviconImage: UIImage?
    @objc dynamic open var progress: Double
    @objc dynamic open var authenticationResult: AuthenticationResultProtocol?
    @objc dynamic open var webView: ContentWebView {
        if let internalWebView = internalWebView {
            return internalWebView
        } else {
            let webView = ContentWebView(frame: CGRect.zero)
            webView.chromeTab = self
            webView.faviconLoader = window.chrome.createFaviconLoader(webView)
            webView.identifier = identifier
            webView.pendingURL = URL as URL?

            if let restorableState = restorableState {
                let coder = NSKeyedUnarchiver(forReadingWith: restorableState as Data)
                webView.decodeRestorableState(with: coder)
                webView.wasRestored = true
            }

            internalWebView = webView
            hibernated = false
            return webView
        }
    }

    internal var internalSessionManager: SessionManager?

    @objc open var sessionManager: SessionManager {
        if window.incognito {
            let sessionManager = internalSessionManager ?? SessionManager()
            internalSessionManager = sessionManager
            return sessionManager
        } else {
            return SessionManager.defaultSessionManager
        }
    }

    open func chromeTabObjectWithIndex(_ index: Int) -> [String: Any] {
        // https://developer.chrome.com/extensions/tabs#type-Tab
        var chromeTabObject = [
            "id": identifier,
            "index": index,
            "windowId": window.identifier,
            "highlighted": true,
            "active": active,
            "pinned": false,
            "status": (status == .loading ? "loading" : "complete"),
            "incognito": incognito,
            // @todo real size if it is ever needed
            "width": 320,
            "height": 480 ,
            "sessionId": "KittTab-\(window.identifier)"
            ] as [String: Any]
        // optional members
        if let openerTab = openerTab {
            chromeTabObject["openerTabId"] = openerTab.identifier
        }
        // @todo url,title,favIconUrl only if "tabs" permission is declared
        if true {
            if let URL = URL, !URL.shouldBeHidden() {
                chromeTabObject["url"] = URL.absoluteString ?? ""
            } else {
                chromeTabObject["url"] = "chrome://newtab/"
            }
            chromeTabObject["title"] = documentTitle

            if let string = faviconURL?.absoluteString {
                chromeTabObject["faviconUrl"] = string
            } else {
                chromeTabObject["faviconUrl"] = NSNull()
            }
        }
        return chromeTabObject
    }

    @objc
    open func saveState() {
        if let webView = internalWebView {
            let data = NSMutableData()
            let coder = NSKeyedArchiver(forWritingWith: data)
            webView.encodeRestorableState(with: coder)
            coder.finishEncoding()
            restorableState = data as Data
        }
    }

    open func fresher(than otherTab: ChromeTab) -> Bool {
        guard let tabTimestamp = self.tabData?.activityTimestamp,
            let otherTabTimestamp = otherTab.tabData?.activityTimestamp else {
                return false
        }
        return tabTimestamp.compare(otherTabTimestamp) == .orderedDescending
    }

    deinit {
        internalWebView = nil
    }

    // MARK: - Internal

    @objc dynamic var restorableState: Data? {
        get { return tabData?.restorableState }
        set {
            if let tabData = tabData {
                tabData.restorableState = newValue
                window.setNeedsCommit()
            }
        }
    }

    init(window: ChromeWindow, tabData: ChromeTabDataProtocol) {
        tabIdentifier += 1
        self.identifier = tabIdentifier
        self.progress = 0
        self.authenticationResult = nil
        self.window = window
        self.tabData = tabData
        self.status = .complete
        self.hibernated = true
        self.incognito = window.incognito
        super.init()

        guard let url = tabData.url, let savedURL = Foundation.URL(string: url) else {
            return
        }
        // Set only pending request, which doesn't invoke reload of Webview.
        // It will not be used because wasRestored has higher priority.
        // But it is needed to display in tab listing for tabs which weren't loaded yet
        self.URL = savedURL as NSURL?

        // Query an existing history entry only if it was a real URL, not a "New Tab" meta URL.
        if savedURL.shouldBeHidden() {
            return
        }

        if let iconData = window.historyManager?.faviconFor(urls: [savedURL])?.iconData, let iconImage = UIImage(data: iconData) {
            faviconImage = iconImage
        }
    }

    var updatedProperties = ContentWebViewUpdatedProperties.None
    var tabData: ChromeTabDataProtocol?
    fileprivate var _internalWebView: ContentWebView?
    var internalWebView: ContentWebView? {
        get { return _internalWebView }
        set {
            if _internalWebView != nil {
                window.chrome.removeWebView(forTabId: identifier)
            }

            typealias ContentWebView = SAContentWebView

            let keyPath = [
                #keyPath(ContentWebView.currentFavicon),
                #keyPath(ContentWebView.currentURL),
                #keyPath(ContentWebView.documentTitle),
                #keyPath(ContentWebView.mainFrameAuthenticationResult),
                #keyPath(ContentWebView.networkLoadingProgress),
                #keyPath(ContentWebView.status)
            ]

            for keyPath in keyPath {
                _internalWebView?.removeObserver(self, forKeyPath: keyPath, context: nil)
            }
            _internalWebView?.bridgeSwitchboard?.unregisterExtensions(in: _internalWebView)
            _internalWebView = newValue
            for keyPath in keyPath {
                _internalWebView?.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
            }
            if let webView = _internalWebView {
                window.chrome.set(webView: webView, forTabId: identifier)
            }
            NetworkActivityObserver.sharedInstance().unregisterActivityDelegate(forTabId: identifier)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity block_based_kvo
    open override func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey: Any]?,
                                    context: UnsafeMutableRawPointer?) {
        let value = change?[NSKeyValueChangeKey.newKey]

        typealias ContentWebView = SAContentWebView

        switch keyPath {
        case .some(#keyPath(ContentWebView.mainFrameAuthenticationResult)):
            authenticationResult = value as? AuthenticationResultProtocol
        case .some(#keyPath(ContentWebView.currentFavicon)):
            let favicon = (value as? FaviconFacade)

            if let iconData = favicon?.iconData {
                setIfNotEqual(&faviconImage, value: UIImage(data: iconData))
            } else {
                setIfNotEqual(&faviconImage, value: nil)
            }

            if let urlString = favicon?.iconUrl {
                setIfNotEqual(&faviconURL, value: Foundation.URL(string: urlString))
            } else {
                setIfNotEqual(&faviconURL, value: nil)
            }
        case .some(#keyPath(ContentWebView.currentURL)):
            setIfNotEqual(&URL, value: value)
        case .some(#keyPath(ContentWebView.documentTitle)):
            setIfNotEqual(&documentTitle, value: value)
        case .some(#keyPath(ContentWebView.networkLoadingProgress)):
            DispatchQueue.main.async {
                setIfNotEqual(&self.progress, value: value, defaultValue: 0)
            }
        case .some(#keyPath(ContentWebView.status)):
            if let statusNumber = value as? UInt,
                let value = ContentWebViewStatus(rawValue: statusNumber) {
                if status != value {
                    status = value
                }
            }
        default:
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
    }

    open func hibernate() {
        saveState()
        internalWebView?.removeFromSuperview()
        internalWebView = nil
        hibernated = true
    }
}

func setIfNotEqual<T>(_ input: inout T?, value: Any?) where T: Equatable {
    let value = value as? T
    if input != value {
        input = value
    }
}

func setIfNotEqual<T>(_ input: inout T, value: Any?, defaultValue: T) where T: Equatable {
    if let value = value as? T {
        if input != value {
            input = value
        }
    } else {
        input = defaultValue
    }
}
