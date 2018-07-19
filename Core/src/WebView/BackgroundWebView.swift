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

public final class BackgroundWebView: WKWebView, BackgroundFacade {
    public weak var context: ExtensionBackgroundContext?

    // MARK: - WebViewFacade

    public var origin: CallbackOriginType {
        return .background
    }

    public weak var bridgeSwitchboard: BridgeSwitchboard?

    // MARK: - BackgroundFacade

    public weak var `extension`: BrowserExtension?

    public func loadExtensionBundleScript() {
        guard let `extension` = `extension` else {
            Log.error("WebView is not assigned to any extension")
            return
        }

        let extensionId = `extension`.extensionId

        guard let chromeObjectScript = bridgeSwitchboard?.injector?.backgroundApi(for: extensionId) else {
            Log.error("Script for creation of content object cannot be found")
            return
        }

        let controller = configuration.userContentController
        controller.removeAllUserScripts()

        // Load translations
        if let translations = `extension`.chooseBestTranslationsFile() {
            let scriptText = NSString(data: translations, encoding: String.Encoding.utf8.rawValue)! as String
            let script = WKUserScript(source: "var extensionMessageTranslations = \(scriptText);",
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true)
            controller.addUserScript(script)
        }

        /// Load chrome object
        let script = WKUserScript(source: "try { \(chromeObjectScript); } catch (e) { alert(e); }",
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: true)
        controller.addUserScript(script)

        let generatedBackgroundFilename = BrowserExtension.generatedBackgroundPageFilename
        if #available(iOS 9, *) {
            `extension`.generateBackgroundPage()
            if let extensionDirectoryPath = `extension`.path(to: "."),
                let backgroundPagePath = `extension`.path(to: generatedBackgroundFilename) {

                let backgroundPageUrl = URL(fileURLWithPath: backgroundPagePath, isDirectory: false)
                let directoryUrl = URL(fileURLWithPath: extensionDirectoryPath, isDirectory: true)

                loadFileURL(backgroundPageUrl, allowingReadAccessTo: directoryUrl)
            }
        } else {
            // Load background script
            if let filenames = `extension`.manifest.backgroundFilenames() {
                for filename in filenames {
                    let content = try? `extension`.data(forBundleResource: filename)
                    if let uwContent = content {
                        let scriptText = NSString(data: uwContent, encoding: String.Encoding.utf8.rawValue)! as String
                        let script = WKUserScript(source: scriptText, injectionTime: .atDocumentStart, forMainFrameOnly: true)
                        controller.addUserScript(script)
                    }
                }
            }

            let baseURL = ProtocolHandlerChromeExt.url(forRequestResource: generatedBackgroundFilename,
                                                       extensionId: extensionId)
            loadHTMLString("<!DOCTYPE html><head><title>\(extensionId)</title></head>", baseURL: baseURL)
        }
    }

    // MARK: - Frames

    // Dummy frame needed by BridgeCallback
    let mainFrame = WebViewFrame()
}

class WebViewFrame: NSObject, WebKitFrame {
    func parentFrame() -> Any? {
        return nil
    }
}
