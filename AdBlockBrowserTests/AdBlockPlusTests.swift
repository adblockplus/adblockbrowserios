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

@testable import AdblockBrowser
import UIKit
import XCTest

class AdBlockBrowserTests: XCTestCase {
    var backgroundContext: ExtensionBackgroundContext!
    var switchboard: BridgeSwitchboard!
    var `extension`: BrowserExtension!

    override func setUp() {
        super.setUp()
        let components = (UIApplication.sharedApplication().delegate as? AppDelegate)?.components

        backgroundContext = components.extensionFacade?.backgroundContext
        XCTAssert(backgroundContext != nil, "Background context has not been found!")

        switchboard = components.bridgeSwitchboard
        XCTAssert(switchboard != nil, "Switchboard has not been found!")

        `extension` = components.extensionFacade.extensionInstance
        XCTAssert(`extension` != nil, "Extension has not been found!")
    }

    func testAdblockBrowserExtension() {
        let bundle = NSBundle(forClass: type(of: self))
        let url = bundle.URLForResource("scripts", withExtension: "js")
        let scripts = try? String(contentsOfURL: url!, encoding: NSUTF8StringEncoding)

        let jsonURL = bundle.URLForResource("actions", withExtension: "json")
        let json = try? String(contentsOfURL: jsonURL!, encoding: NSUTF8StringEncoding)

        backgroundContext.evaluateJavaScript(scripts, inExtension: ABPExtensionName, completionHandler: { dataReturn, error -> Void in
            XCTAssert(error == nil, "Evaluating failed with \(e)")

            let test = "JSON.stringify(window.AdblockPlusTests.testOnBeforeRequest(\(json)))"

            self.backgroundContext.evaluateJavaScript(test, inExtension: ABPExtensionName, completionHandler: { dataReturn, error -> Void in
                XCTAssert(error == nil, "Evaluating failed with \(error)")

                if let data = dataReturn.dataUsingEncoding(NSUTF8StringEncoding),
                    let array = (try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())) as? [[NSObject: AnyObject]] {

                    for testResult: [NSObject: AnyObject] in array {
                        if let success = testResult["success"] as? Bool,
                            let requestId = testResult["requestId"] as? String,
                            let url = testResult["url"] as? String,
                            let response = testResult["response"] as? [NSObject: AnyObject] {
                            if !success {
                                XCTFail(" unexpected response \(response) to request \(requestId) \(url)")
                            }
                        }
                    }
                } else {
                    XCTFail("Unknown response")
                }

            })
        })
    }

    // swiftlint:disable:next function_body_length
    func testAdblocking() {
        let bundle = NSBundle(forClass: type(of: self))

        let jsonURL = bundle.URLForResource("actions", withExtension: "json")
        let data = NSData(contentsOfURL: jsonURL!)

        guard let json = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions()) as? [[NSObject: AnyObject]] else {
            XCTFail("Unable to parse serialize JSON")
            return
        }

        var map = ["other": WebRequestResourceType.Other,
                   "main_frame": WebRequestResourceType.MainFrame,
                   "sub_frame": WebRequestResourceType.SubFrame,
                   "stylesheet": WebRequestResourceType.Stylesheet,
                   "script": WebRequestResourceType.Script,
                   "image": WebRequestResourceType.Image,
                   "object": WebRequestResourceType.Object,
                   "xmlhttprequest": WebRequestResourceType.XHR]

        let ruleAction = RuleAction_OnBeforeRequest(commandDelegate: self.switchboard, originExtension: self.extension)
        ruleAction.configureWithProperties(["blocking": true])

        let result = json.reduce(false, combine: {(bool: Bool, index) -> Bool in bool || (index["result"]?.valueForKey("cancel") as? Bool ?? false)})
        XCTAssert(result, "At least one action has to do cancel")

        var count = json.count

        for jsonItem in json {
            if var jsonDetails = jsonItem["details"] as? [NSObject: AnyObject],
                let urlString = jsonDetails["url"] as? String,
                let url = NSURL(string: urlString),
                let method = jsonDetails["method"] as? String,
                let frameId = jsonDetails["frameId"] as? UInt,
                let parentFrameId = jsonDetails["parentFrameId"] as? Int,
                let requestId = jsonDetails["requestId"] as? String,
                let rawType = jsonDetails["type"] as? String,
                let type = map[rawType] {
                let blockingResponse = BlockingResponse()

                let request = NSMutableURLRequest(URL: url)
                request.HTTPMethod = method

                let details = WebRequestDetails(request: request, fromTabId: jsonDetails["tabId"] as? UInt)
                details.stage = "onBeforeRequest"
                details.parentFrameId = parentFrameId
                details.frameId = frameId
                details.setValue(requestId, forKey: "requestId")
                details.setValue(type.rawValue, forKey: "resourceType")

                let cancel = jsonItem["result"]?.valueForKey("cancel") as? Bool ?? false

                ruleAction.applyToDetails(details, modifyingResponse: blockingResponse, completionBlock: { () -> Void in
                    XCTAssert(cancel == blockingResponse.cancel,
                              "Blocking expected \(cancel) != response \(blockingResponse.cancel) (url = \(urlString), method = \(method))")
                    if count == 1 {
                        expectation.fulfill()
                    }
                    count -= 1
                })
            } else {
                // Skip invalid urls
                count -= 1
            }
        }
    }
}
