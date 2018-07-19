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

import JavaScriptCore

private var requestIdCounter: UInt = 0

@objcMembers
public final class WebRequestDetails: NSObject {
    fileprivate var requestId: UInt
    open var request: URLRequest

    open var stage: String?
    open var tabId: UInt
    open var frameId: UInt = 0
    open var parentFrameId: Int = 0
    open var resourceType: WebRequestResourceType
    open var resourceTypeTentative = false
    open var isXHRAsync = true

    // none of them used there. It's just injected from the outside
    open var requestBody: NSString?
    open var requestHeaders: [String: String]?
    open var responseHeaders: [String: String]?

    static func separateKittValuesFromAcceptType(_ acceptHeaderCsvInput: String) -> (String?, [String]) {
        var kittElements = [String]()
        var standardElements = [String]()
        let allElements = acceptHeaderCsvInput.components(separatedBy: ",")

        for element in allElements {
            let trimmed = element.trimmingCharacters(in: CharacterSet.whitespaces)

            if trimmed.hasPrefix("kitt") {
                kittElements.append(element)
            } else {
                standardElements.append(element)
            }
        }

        return (standardElements.count > 0 ? standardElements.joined(separator: ", ") : nil, kittElements)
    }

    init(request urlRequest: URLRequest, resourceType: WebRequestResourceType, fromTabId tab: UInt) {
        request = urlRequest
        tabId = tab

        requestIdCounter += 1
        requestId = requestIdCounter

        // convert xhr extended sync flag back to standard type
        if resourceType == .extXHRSync {
            self.resourceType = .xhr
            isXHRAsync = false
        } else {
            self.resourceType = resourceType
        }
    }

    open func dictionaryForListenerEvent() -> [String: Any] {
        let reachabilityString: String
        switch ReachabilityCentral.currentInternetReachabilityStatus() {
        case .ReachableViaWiFi:
            reachabilityString = "WiFi"
        case .ReachableViaWWAN:
            reachabilityString = "Cellular"
        case .NotReachable:
            reachabilityString = "No Connection"
        }

        var ret: [String: Any] = [
            "stage": stage as NSObject? ?? "" as NSObject,
            "requestId": requestId as NSObject,
            "url": request.url?.absoluteString ?? "about:blank",
            "method": request.httpMethod ?? "get",
            "frameId": frameId,
            "parentFrameId": parentFrameId,
            "tabId": tabId,
            "type": resourceType.toString(),
            "timeStamp": round(Date().timeIntervalSince1970 * 1000.0),
            "reachability": reachabilityString
        ]

        if resourceTypeTentative {
            // custom flag to help webRequest listener do its job better
            ret["typeTentative"] = true as NSObject?
        }
        return ret
    }

    open var resourceTypeString: String {
        return resourceType.toString()
    }
}
