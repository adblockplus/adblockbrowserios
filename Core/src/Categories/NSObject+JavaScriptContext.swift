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

let asyncSymbolString = "KittEntryPoint"
let kBrowserActionToBeClosedNotification = "BrowserActionToBeClosedNotification"

public extension NSObject {
    @objc
    dynamic func webView(_ webView: AnyObject?, didCreateJavaScriptContext context: JSContext!, forFrame frame: WebKitFrame!) {
        assert(webView === (frame as? NSObject)?.value(forKeyPath: "webView") as AnyObject)

        // find the frame originating webview
        /*let frameInternalWebView = frame.valueForKeyPath:("webView")*/
        var originatingWebView: UIWebView? = nil
        for knownWebView in WebViewManager.sharedInstance.webViews {
            // Skip views which are not UIWebView
            if knownWebView.value(forKeyPath: "documentView.webView") as AnyObject === webView {
                originatingWebView = knownWebView
                break
            }
        }

        if let originatingWebView = originatingWebView {
            assert(frame.responds(to: #selector(WebKitFrame.parentFrame)), "WebKit frame does not implemented the expected protocol")
            DispatchQueue.main.async {
                type(of: self).didCreateJavaScriptContext(context, forFrame: frame, inWebView: originatingWebView)
            }
        } else {
            Log.error("Frame originating webview not found")
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func createCallbackForWebView(_ wWebView: SAWebView, forFrame wFrame: WebKitFrame) -> @convention(block) (Any?, Any?) -> Any? {
        return { [weak wWebView, weak wFrame] (inputCommand: Any?, inputData: Any?) in
            guard let command = inputCommand as? String else {
                Log.error("Command should be defined")
                return nil
            }

            guard let inputData = inputData as? [AnyHashable: Any] else {
                Log.error("Data should be defined")
                return nil
            }

            // sync command - no need for special handling
            if command == "i18n.getMessage" {
                if let frame = wFrame {
                    return i18nGetMessage(wWebView, forFrame: frame, reqCommand: command, reqData: inputData)
                }
                return nil
            }

            if !Thread.isMainThread {
                // Store reference to web thread
                let injector = wWebView?.bridgeSwitchboard?.injector
                if injector?.webThread == nil {
                    injector?.webThread = Thread.current
                }
            }

            DispatchQueue.main.async {
                guard let sWebView = wWebView, let sFrame = wFrame else {
                    return
                }

                // Handle JS events
                if command == "JSContextEvent" {
                    if let contentWebView = sWebView as? ContentWebView {
                        let result = contentWebView.handleEvent(inputData["raw"], fromFrame: sFrame)
                        assert(result, "Event wasn't processed!")
                    }
                    return
                }

                // Handle window open/close
                if sWebView is SAPopupWebView && ["core.open", "core.close"].contains(command) {
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kBrowserActionToBeClosedNotification), object: nil)
                    return
                }

                guard let sBridgeSwitchboard = sWebView.bridgeSwitchboard else {
                    return
                }

                sBridgeSwitchboard.handle(command, withData: inputData, fromWebView: sWebView, frame: sFrame)
            }
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func didCreateJavaScriptContext(_ context: JSContext, forFrame frame: WebKitFrame, inWebView webView: UIWebView) {
        assert(Thread.isMainThread, "didCreateJavaScriptContext is expected to be run on main thread")

        guard let webView = webView as? SAWebView else {
            Log.warn("Unknown type of webView")
            return
        }

        if let symbol = context.globalObject?.forProperty(asyncSymbolString), !symbol.isUndefined && !symbol.isNull {
            Log.warn("Callback symbol already exists in JSContext global object")
        } else {
            let callback = createCallbackForWebView(webView, forFrame: frame)
            context.globalObject?.setValue(callback, forProperty: asyncSymbolString)
        }

        // We call this function to get reference to web thread.
        // Callback needs to be performed using setTimeout, otherwise it is executed on calling thread.
        weak var wBridgeSwitchboard = webView.bridgeSwitchboard
        if wBridgeSwitchboard?.injector.webThread == nil {
            let setWebThread: @convention(block) () -> Void = {
                assert(!Thread.isMainThread, "This function should not be run on main thread")
                wBridgeSwitchboard?.injector.webThread = Thread.current
            }
            _ = context.globalObject?.forProperty("setTimeout").call(withArguments: [unsafeBitCast(setWebThread, to: AnyObject.self), 0])
        }

        switch webView {
        case let contentWebView as SAContentWebView:
            contentWebView.changeCookieStorage(in: context)
            // Add frame context first. Frame hierarchy must be maintained regardless of
            // content script injection success or failure.
            let kittFrame = contentWebView.mainThreadAdd(context, from: frame)

            if let urlStr = kittFrame.fullURLString, let url = URL(string: urlStr) {
                if let frameId = kittFrame.frameId?.uintValue, let parentFrameId = kittFrame.parentFrameId?.intValue {
                    // @todo @fixme
                    // This is a wrong place for "onBeforeNavigate", basically it is too late. It should happen _before_ the
                    // navigation even starts. Correctly it should be in every single place which can initiate the navigation,
                    // per the TransitionType enumeration in "onCommitted" and equally for "history" API
                    // https://developer.chrome.com/extensions/history#transition_types
                    // But Adblock extension just wants to get the event, and does not care as much when it gets it,
                    // so this is Good Enough For Now(TM)
                    contentWebView.webNavigationEventsDelegate?.beforeNavigate(
                        to: url,
                        tabId: contentWebView.identifier,
                        frameId: frameId,
                        parentFrameId: parentFrameId)
                    // @todo @fixme
                    // This is a correct place for "onCommited" because the document is already downloading. However, the TransitionType
                    // and TransitionQualifiers are unknown. It would again require marking in every single place which can initiate the
                    // navigation, basically along all calls to "onBeforeNavigate" if it was correctly placed per the comment above.
                    // But Adblock extension just wants to get the event and is interested only in url, tabId and frameId, so let's
                    // fake the most common TransitionType and no qualifiers (it's optional)
                    contentWebView.webNavigationEventsDelegate?.committedNavigation(
                        to: url,
                        tabId: contentWebView.identifier,
                        frameId: frameId,
                        type: .TransitionTypeLink,
                        qualifiers: [])
                } else {
                    Log.error("Frame \(urlStr) has invalid (parent)frameId, not invoking webNavigation.onBeforeNavigate")
                }
                guard let model = contentWebView.contentScriptLoaderDelegate, model.injectContentScript(to: context,
                                                                                                        with: url,
                                                                                                        of: contentWebView) != -1 else {
                    Log.warn("Content script injection failed, removing callback entry symbol")
                    context.globalObject.setValue(JSValue(undefinedIn: context), forProperty: asyncSymbolString)
                    return // Swift static analysis doesn't know that this condition is the last in branch
                }
            } else {
                let frameId = String(describing: kittFrame.frameId)
                let parentId = String(describing: kittFrame.parentFrameId)
                let urlString = String(describing: kittFrame.fullURLString)
                Log.error("Frame \(frameId),\(parentId) has invalid URL '\(urlString)', content scripts not injected")
            }
        case let backgroundWebView as SABackgroundWebView:
            if let injector = backgroundWebView.bridgeSwitchboard?.injector {
                if let chrome = context.globalObject?.forProperty("chrome"), !chrome.isUndefined && !chrome.isNull {
                    Log.warn("Chrome symbol already exists in JSContext global object")
                } else {
                    backgroundWebView.loadBackgroundApi(with: injector)
                }
            }
            if let window = context.globalObject, window.isEqual(to: window.forProperty("top")) {
                webView.mainThreadAdd(context, from: frame)
            }
        default:
            // not a content webview, scripts are already injected
            // this jsc callback is a result of that injection
            if let window = context.globalObject, window.isEqual(to: window.forProperty("top")) {
                webView.mainThreadAdd(context, from: frame)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func i18nGetMessage(_ webView: SAWebView?,
                               forFrame: WebKitFrame,
                               reqCommand: String,
                               reqData: [AnyHashable: Any]) -> Any? {
        // here, we can always assume, that the json is in correct format
        guard let webView = webView else {
            assert(false, "Webview doesn't exist")
            return nil
        }

        guard let switchboard = webView.bridgeSwitchboard else {
            assert(false, "Webview did not provide bridgeSwitchboard")
            return nil
        }

        let context = reqData["c"] as? [AnyHashable: Any]

        guard let extensionId = context?["extensionId"] as? String else {
            assert(false, "No extensionId in reqData")
            return nil
        }

        let `extension` = switchboard.browserExtension(for: extensionId, from: webView)

        guard let json = `extension`?.translations else {
            assert(false, "The translation file in missing, or corrupt")
            return nil
        }

        let data = reqData["d"] as? [AnyHashable: Any]

        guard let messageName = data?["messageName"] as? String else {
            Log.warn("messageName is not set")
            return nil
        }

        // https://developer.chrome.com/extensions/i18n#overview-predefined
        if let predefRange = messageName.range(of: "@@"), predefRange.lowerBound == messageName.startIndex {
            func directionName(_ ltr: Bool) -> String {
                return ltr ? "ltr" : "rtl"
            }
            func directionEdge(_ ltr: Bool) -> String {
                return ltr ? "left" : "right"
            }
            let isLeftToRight = UIApplication.shared.userInterfaceLayoutDirection == .leftToRight
            switch messageName[predefRange.upperBound...] {
            case "extension_id":
                return extensionId
            case "ui_locale":
                return Locale.current.identifier
            case "bidi_dir":
                return directionName(isLeftToRight)
            case "bidi_reversed_dir":
                return directionName(!isLeftToRight)
            case "bidi_start_edge":
                return directionEdge(isLeftToRight)
            case "bidi_end_edge":
                return directionEdge(!isLeftToRight)
            default:
                Log.warn("Unknown predefined message \(messageName)")
                return ""
            }
        }
        guard let messageItem = (json as? [String: Any])?[messageName] as? [String: Any]  else {
            Log.warn("Message key (\(messageName)) not found in the file")
            return nil
        }

        return messageItem
    }
}
