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

public final class MessageHandler: NSObject, WKScriptMessageHandler {
    fileprivate weak var bridgeSwitchboard: BridgeSwitchboard?

    @objc
    public init(bridgeSwitchboard: BridgeSwitchboard) {
        self.bridgeSwitchboard = bridgeSwitchboard
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        guard let webView = scriptMessage.webView as? WebViewFacade,
            let data = scriptMessage.body as? [AnyHashable: Any],
            let command = data["name"] as? String else {
                Log.error("Message from WKWebView has not been processed!")
                return
        }

        if let frame = (webView as? BackgroundWebView)?.mainFrame {
            bridgeSwitchboard?.handle(command, withData: data, fromWebView: webView, frame: frame)
        } else {
            Log.error("WKWebView does not have any frame")
            bridgeSwitchboard?.handle(command, withData: data, fromWebView: webView, frame: nil)
        }
    }
}
