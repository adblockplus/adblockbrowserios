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
@testable import KittCore
import XCTest

// wraps the browser the the test extension
class TestingBrowser {
    private let testExtension = "TestExtension"
    private let wkSymbol = "testSymbol"

    let browser: MinimalBrowser
    let backgroundWebView: BackgroundFacade
    let contentWebView: SAContentWebView

    var testMessageHandler: TestMessageHandler

    internal var isBackgroundScriptReady = false
    internal var backgroundScriptReadyQueue = [() -> Void]()

    func ready(onReady: @escaping () -> Void) {
        if self.isBackgroundScriptReady {
            onReady()
        } else {
            backgroundScriptReadyQueue.append(onReady)
        }
    }

    class TestMessageHandler: NSObject, WKScriptMessageHandler {
        var keyToCallbackMap = [String: ([String: Any]) -> Void]()

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let jsonBody = message.body as? [String: Any] else {
                return
            }

            for (key, callback) in keyToCallbackMap where jsonBody[key] != nil {
                callback(jsonBody)
                break
            }
        }
    }

    init?() {
        do {
            browser = try MinimalBrowser()
            let destUrl = try browser.extensionUnpacker.path(forExtensionId: testExtension, resource: nil)
            guard let originTestExtensionPath = Bundle(for:
                KittCoreExtensionTests.self).url(forResource: testExtension, withExtension: nil)
                else {
                    return nil
            }
            let destTestExtensionPath = URL(fileURLWithPath: destUrl).appendingPathComponent("..", isDirectory: true).standardized

            // cleanup the extensions directory after previous tests
            let recreateDirectoryPath = destTestExtensionPath.appendingPathComponent("..", isDirectory: true).standardized
            try? FileManager.default.removeItem(at: recreateDirectoryPath)
            try? FileManager.default.createDirectory(at: recreateDirectoryPath, withIntermediateDirectories: true, attributes: nil)

            // copy extension bundle resource to documents
            try? FileManager.default.createDirectory(at: destTestExtensionPath, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.removeItem(at: destTestExtensionPath)
            try? FileManager.default.copyItem(at: originTestExtensionPath, to: destTestExtensionPath)
            try? browser.browserStateModel.loadExtensions()
            browser.backgroundContext.loadScripts(ofExtensionId: testExtension)
            contentWebView = Chrome.sharedInstance.mainWindow.activeTab!.webView
            backgroundWebView = browser.backgroundContext.backgroundWebView(for: testExtension)!

            testMessageHandler = TestMessageHandler()
            backgroundWebView.initTestSymbol(messageHandler: testMessageHandler, name: wkSymbol)

            testMessageHandler.keyToCallbackMap["backgroundScriptReady"] = { json in
                for onReadyCallback in self.backgroundScriptReadyQueue {
                    onReadyCallback()
                }
                self.backgroundScriptReadyQueue.removeAll()
                self.isBackgroundScriptReady = true
            }
        } catch let error {
            XCTFail("Unable to instantiate TestingBrowser - Error: \(error)")
            return nil
        }
    }
}

extension BackgroundFacade {
    public func initTestSymbol(messageHandler: WKScriptMessageHandler, name: String) {
        if let webView = self as? WKWebView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
            webView.configuration.userContentController.add(messageHandler, name: name)
        }
    }
}

var browserWithExtension = TestingBrowser()

final class KittCoreExtensionTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func executeTest(description: String, testNameInJavascript: String) {
        let testExpectation = expectation(description: description)

        browserWithExtension?.testMessageHandler.keyToCallbackMap[testNameInJavascript] = { json in
            guard let testCase = json[testNameInJavascript] as? [String: Any] else {
                XCTFail("Error: Unable to unwrap testCase")
                return
            }
            if let okMessage = testCase["testPassed"] as? String {
                print(okMessage)
            }

            if let errorMessage = testCase["testFailed"] as? String {
                if let stack = testCase["stack"] as? String {
                    print(stack)
                }
                XCTFail("Error: \(errorMessage)")
            }
            testExpectation.fulfill()
        }

        browserWithExtension?.ready {
            let javascriptCommand = "window.executeTest('\(testNameInJavascript)')"
            // window.executeTest is an async function (returns a promise) and WKWebView can't
            // serialize it, so it always returns an error
            browserWithExtension?.backgroundWebView.evaluateJavaScript(javascriptCommand)
        }

        waitForExpectations(timeout: 5) { error in
            if error != nil {
                print("Time limit exceeded for \(testNameInJavascript)")
            }

            browserWithExtension?.testMessageHandler.keyToCallbackMap[testNameInJavascript] = nil
        }

    }

    func testExtensionLoad() {
        let backgroundScriptLoadedExpectation = expectation(description: "Testing if the extension has loaded")
        browserWithExtension?.ready {
            backgroundScriptLoadedExpectation.fulfill()
        }

        waitForExpectations(timeout: 5) { error in
            if error != nil {
                print("Background script not ready")
            }
        }
    }

    func testTabsQuery() {
        executeTest(description: "Test tabs query", testNameInJavascript: "testTabsQuery")
    }
}
