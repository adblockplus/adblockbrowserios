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

/**
 A persistent callback. When extension script adds an event listener, it results in
 a JS callback, which must be remembered and kept around on both sides (native
 and JS). Contrary to one-shot callbacks (like XSXHR), which are kept only for
 the time of invocation on native side.
 
 <NSCopying> needs to be implemented because the one and same BridgeCallback acts as
 a carrier for parameter data going from origin to listener and back. This is
 async environment, so making a copy for each call is necessary, so that the
 calls underway are not hijacked with data from newer calls.
 */
public final class BridgeCallback: NSObject {
    /// originating UIWebView. Needed for callback evaluation
    public weak var webView: WebViewFacade?
    /// originating extension
    public weak var `extension`: BrowserExtension?
    /// The frame that this callback originated in
    public weak var frame: WebKitFrame?
    // see above
    public let origin: CallbackOriginType
    // see above
    public let event: CallbackEventType
    /// callback context object. De/serialized directly from JS parameter.
    /// @see api-content.js function callNative
    public let context: [String: Any]
    /// if callback origin has tabbed context (content script)
    public var tab: Int {
        if let tabId = tabId {
            return Int(tabId)
        } else {
            return NSNotFound
        }
    }

    public var tabId: UInt? {
        switch context["tabId"] {
        case .some(let tabIdString as String):
            return UInt(tabIdString)
        case .some(let tabIdInt as UInt):
            return tabIdInt
        default:
            return nil
        }
    }

    @objc public let callbackId: String

    public var conditions = [RuleConditionMatchable]()

    public convenience init?(webView: WebViewFacade?,
                             frame: WebKitFrame?,
                             origin: CallbackOriginType,
                             extension: BrowserExtension?,
                             event: CallbackEventType,
                             context: [String: Any]) {
        guard let callbackId = context["callbackId"] as? String else {
            return nil
        }

        self.init(webView: webView, frame: frame, origin: origin, extension: `extension`, event: event, callbackId: callbackId, context: context)
    }

    public init(webView: WebViewFacade?,
                frame: WebKitFrame?,
                origin: CallbackOriginType,
                extension: BrowserExtension?,
                event: CallbackEventType,
                callbackId: String,
                context: [String: Any]) {
        self.webView = webView
        self.frame = frame
        self.`extension` = `extension`
        self.origin = origin
        self.event = event
        self.context = context
        self.callbackId = callbackId
    }

    public func conditionsMatchURL(_ url: URL) -> Bool {
        if conditions.isEmpty {
            // webNavigation.*.addListener filters are optional parameter,
            // and guessing from the example extensions, no filters mean allow all
            // https://developer.chrome.com/extensions/samples#webnavigation-tech-demo
            // https://developer.chrome.com/extensions/samples#google-mail-checker
            return true
        }

        // All what's needed for applicable conditions (UrlFilter for WebNavigation)
        let mockup = WebRequestDetails(request: URLRequest(url: url), resourceType: .other, fromTabId: 0)
        // "array of events.UrlFilter url Conditions that the URL being navigated to must satisfy"
        // which sounds like AND condition but chrome is observed to implement OR condition.
        // Also makes more sense with practical usability.

        for condition in conditions {
            if condition.matchesDetails(mockup) {
                return true
            }
        }

        return false
    }

    @objc public var isValid: Bool {
        return webView != nil && `extension` != nil
    }

    public override var description: String {
        let eventString = BridgeCallback.eventString(for: event)
        return "BridgeCallback{event: \(String(describing: eventString)), tabId: \(tabId ?? 0)"
    }

    public static func eventTypeForEventString(_ eventString: String) -> CallbackEventType {
        return eventTypeToStringMap.first { $1 == eventString }?.key ?? .undefined
    }

    @objc
    public static func eventString(for eventType: CallbackEventType) -> String? {
        return eventTypeToStringMap[eventType]
    }

    /**
     This map is being searched both ways (by key and by value) but by value
     only initially when extension is subscribing to event (JS bridge sent string
     and the enum type is needed). When the events are happening later, enum type is
     known and string is needed to look up the event handler. So keying by enum type
     is more efficient.
     */
    fileprivate static let eventTypeToStringMap: [CallbackEventType: String] = [
        .undefined: "undefined",
        .runtimeStartup: "runtime.onStartup",
        .runtimeInstall: "runtime.onInstall",
        .runtimeSuspend: "runtime.onSuspend",
        .runtimeMessage: "runtime.onMessage",
        .declarativeWebRequestMessage: "declarativeWebRequest.onMessage",
        .contextMenuClicked: "contextMenus.onClicked",
        .browserActionClicked: "browserAction.onClicked",
        .webRequest_OnBeforeRequest: "webRequest.onBeforeRequest",
        .webRequest_OnBeforeSendHeaders: "webRequest.onBeforeSendHeaders",
        .webRequest_OnHeadersReceived: "webRequest.onHeadersReceived",
        .webRequest_HandlerBehaviorChanged: "webRequest.handlerBehaviorChanged",
        .webNavigation_OnCreatedNavTarget: "webNavigation.onCreatedNavigationTarget",
        .webNavigation_OnBeforeNavigate: "webNavigation.onBeforeNavigate",
        .webNavigation_OnCommitted: "webNavigation.onCommitted",
        .webNavigation_OnCompleted: "webNavigation.onCompleted",
        .tabs_OnActivated: "tabs.onActivated",
        .tabs_OnCreated: "tabs.onCreated",
        .tabs_OnUpdated: "tabs.onUpdated",
        .tabs_OnMoved: "tabs.onMoved",
        .tabs_OnRemoved: "tabs.onRemoved",
        .fullText_CountMatches: "fulltext.countMatches",
        .fullText_MarkMatches: "fulltext.markMatches",
        .fullText_UnmarkMatches: "fulltext.unmarkMatches",
        .fullText_MakeCurrent: "fulltext.makeCurrent",
        .storage_OnChanged: "storage.onChanged",
        .autofill_FillSuggestion: "autofill.fillSuggestion"
    ]
}
