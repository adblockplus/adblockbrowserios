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

struct ChromeFrameDetails: JSObjectConvertibleParameter {
    let tabId: UInt?
    let frameId: Int?

    init?(object: [AnyHashable: Any]) {
        tabId = object["tabId"] as? UInt
        frameId = object["frameId"] as? Int
    }
}

protocol ChromeWebNavigationProtocol {
    func getFrame(_ object: ChromeFrameDetails) throws -> Any?

    func getAllFrames(_ object: ChromeFrameDetails) throws -> Any?
}

struct ChromeWebNavigationFactory: StandardHandlerFactory {
    var bridgeContext: JSBridgeContext

    typealias Handler = ChromeWebNavigation
}

struct ChromeWebNavigation: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension ChromeWebNavigation: ChromeWebNavigationProtocol {
    func getFrame(_ details: ChromeFrameDetails) throws -> Any? {
        guard let tabId = details.tabId, let tab = context.chrome.findContentWebView(tabId) else {
            throw NSError(message: "Tab with \(details.tabId ?? 0) has not been found")
        }

        for frameObject in tab.threadsafeKittFrames() {
            guard let frame = frameObject as? KittFrame else {
                continue
            }

            if frame.frameId as? Int == details.frameId {
                return frame.toJSON()
            }
        }

        throw NSError(message: "Frame with '\(String(describing: details.frameId))' has not been found")
    }

    func getAllFrames(_ details: ChromeFrameDetails) throws -> Any? {
        guard let tabId = details.tabId, let tab = context.chrome.findContentWebView(tabId) else {
            throw NSError(message: "Tab with \(details.tabId ?? 0) has not been found")
        }

        let frames = tab.threadsafeKittFrames().compactMap { frameObject in
            return (frameObject as? KittFrame)?.toJSON()
        }

        if frames.count == 0 {
            Log.error("getAllFrames did not find any frame")
        }

        return frames
    }
}

func registerChromeWebNavigationHandlers<F>(_ dispatcher: CommandDispatcher,
                                            withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeWebNavigationProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.getFrame, forName: "webNavigation.getFrame")
    dispatcher.register(factory, handler: Handler.getAllFrames, forName: "webNavigation.getAllFrames")
}

extension KittFrame {
    fileprivate func toJSON() -> [String: Any] {
        return [
            "url": fullURLString as Any,
            "frameId": frameId ?? 0,
            "parentFrameId": parentFrameId ?? -1,
            "processId": 0,
            "errorOccurred": false
        ]
    }
}
