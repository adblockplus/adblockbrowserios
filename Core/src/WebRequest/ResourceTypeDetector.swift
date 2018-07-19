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

@objc
public enum WebRequestResourceType: Int {
    case other
    case mainFrame
    case subFrame
    case stylesheet
    case script
    case image
    case object
    case xhr
    case extended = 100
    // Extended types without Chrome standard mapping
    case extXHRSync = 101
    case extAudio = 102
    case extVideo = 103

    func toString() -> String {
        // enum types to chrome specific strings
        switch self {
        case .mainFrame:
            return "main_frame"
        case .subFrame:
            return "sub_frame"
        case .stylesheet:
            return "stylesheet"
        case .script:
            return "script"
        case .image:
            return "image"
        case .object:
            return "object"
        case .xhr:
            return "xmlhttprequest"
        case .extAudio, .extended, .extVideo, .extXHRSync, .other:
            return "other"
        }
    }
}

    // MARK: Synchronous detectors

open class ResourceTypeDetector: NSObject {
    /// There is not very much of them nor big variety in them, so replacing with
    /// regexes or adding leading dot in initialization would make the code
    /// unnecessarily complicated.
    fileprivate struct TypeMatcherDefinition {
        var resourceType: WebRequestResourceType // enum reflecting (but not copying) Chrome defined type strings
        var mimeStrings: [String] // substrings matched against request header "Accept"
        var fileSuffixes: [String] // URL string suffix match. Complete strings with leading dot.
    }

    /// type matcher instances for all applicable resourceTypes
    /// must be an array to ensure order of matching
    fileprivate static var typeMatchers: [TypeMatcherDefinition] = [
        TypeMatcherDefinition(resourceType: .subFrame,
                              mimeStrings: ["text/html", "application/xhtml"],
                              fileSuffixes: [".htm", ".html", ".jsp", ".php"]),

        TypeMatcherDefinition(resourceType: .stylesheet,
                              mimeStrings: ["text/css"],
                              fileSuffixes: [".css"]),

        TypeMatcherDefinition(resourceType: .script,
                              mimeStrings: ["text/javascript", "application/javascript", "application/json"],
                              fileSuffixes: [".js"]),

        TypeMatcherDefinition(resourceType: .xhr,
                              mimeStrings: ["application/x-www-form-urlencoded", "application/xml"], fileSuffixes: [".xml"]),

        TypeMatcherDefinition(resourceType: .image,
                              mimeStrings: ["image/"],
                              fileSuffixes: [".jpg", ".jpe", ".jpeg", ".png", ".gif", ".tif", ".tiff", ".bmp", ".xbm"]),

        TypeMatcherDefinition(resourceType: .object,
                              mimeStrings: ["application/x-shockwave-flash", "application/zip", "application/octet-stream"],
                              fileSuffixes: [".swf", ".zip", ".gz", ".tgz", ".bz2", ".4z", ".rar", ".exe", ".pkg", ".apk", ".ipa", ".ps", ".eps"]),

        TypeMatcherDefinition(resourceType: .extAudio,
                              mimeStrings: ["audio/"],
                              fileSuffixes: [".wav", ".mp3", ".mid", ".midi", ".aiff", ".aac"]),

        TypeMatcherDefinition(resourceType: .extVideo,
                              mimeStrings: ["video/"],
                              fileSuffixes: [".mpe", ".mpg", ".mpeg", ".avi", ".mp4", ".m4v", ".mov"])
    ]

    open static func detectTypeFromURL(_ url: URL, allowExtended allowExt: Bool) -> WebRequestResourceType? {
        /// Simple NSURL.path will knee-jerk on any slightly irregular character
        /// and cut off the real suffix. Example:
        /// http://m.novinky.cz/i/03000L1w2g1b00XuTJ$10$2r479;514799-top_$0J2-z94m2$1Y.jpg
        /// path = /i/03000l1w2g1b00xutj$10$2r479
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var maybeDetectedType: WebRequestResourceType?

        if let urlString = components?.path.lowercased() {
            findType: for obj in typeMatchers {
                for suffix in obj.fileSuffixes {
                    if urlString.hasSuffix(suffix) {
                        maybeDetectedType = obj.resourceType
                        break findType
                    }
                }
            }
        }
        guard let detectedType = maybeDetectedType else {
            return nil
        }

        if detectedType.rawValue >= WebRequestResourceType.extended.rawValue && !allowExt {
            return .other
        }
        return detectedType
    }

    /// ObjC-compatible adapter of detectTypeFromURL()
    ///
    /// - Returns: a valid NSNumber with WebRequestResourceType enum value or nil if type was not detected/
    @objc
    open static func objc_detectTypeFromURL(_ url: URL, allowExtended allowExt: Bool) -> NSNumber? {
        if let resourceType = detectTypeFromURL(url, allowExtended: allowExt) {
            return NSNumber(value: resourceType.rawValue as Int)
        }
        return nil
    }

    fileprivate static func detectTypeFromMIMEList(_ mimeListString: String, allowExtended allowExt: Bool) -> WebRequestResourceType? {
        var maybeDetectedType: WebRequestResourceType?

        findType: for obj in typeMatchers {
            for mime in obj.mimeStrings {
                if mimeListString.range(of: mime, options: NSString.CompareOptions.caseInsensitive) != nil {
                    maybeDetectedType = obj.resourceType
                    break findType
                }
            }
        }
        guard let detectedType = maybeDetectedType else {
            return nil
        }
        if detectedType.rawValue >= WebRequestResourceType.extended.rawValue && !allowExt {
            return .other
        }
        return detectedType
    }

    /// - Returns: WebRequestResourceExtXHRSync even if allowExt = false
    /// As a flag to distinguish synchronicity of WebRequestResourceXHR
    fileprivate static func detectResourceTypeFromAcceptTypes(_ acceptTypes: String, allowExtended allowExt: Bool) -> WebRequestResourceType? {
        if !acceptTypes.isEmpty {
            let (cleanedAcceptTypes, kittValues) = WebRequestDetails.separateKittValuesFromAcceptType(acceptTypes)

            if kittValues.contains("kitt-xhr-async") {
                return .xhr
            } else if kittValues.contains("kitt-xhr-sync") {
                return .extXHRSync
            } else if let cleanedAcceptTypes = cleanedAcceptTypes {
                return detectTypeFromMIMEList(cleanedAcceptTypes, allowExtended: allowExt)
            }
        }
        return nil
    }

    open static func detectTypeFromRequest(_ request: URLRequest, allowExtended allowExt: Bool) -> WebRequestResourceType? {
        guard let url = request.url else {
            return WebRequestResourceType.other
        }

        if url == request.mainDocumentURL {
            return .mainFrame
        }

        let typeFromHeader = { () -> WebRequestResourceType? in
            if let accept = request.value(forHTTPHeaderField: "Accept"), !accept.isEmpty {
                return detectResourceTypeFromAcceptTypes(accept, allowExtended: allowExt)
            }
            return nil
        }()
        if typeFromHeader == .xhr || typeFromHeader == .extXHRSync {
            // Types detected from special accept tokens, analysing URL is redundant
            return typeFromHeader
        }
        /*
         When a link is simply clicked in webview, the request is constructed with
         `Accept: text/html,application/xhtml+xml,application/xml`
         regardless of the actual linked content type, probably to express the expectation
         of replacing the new main frame content. So if the actual content type is wanted,
         URL analysis has higher priority.
         */
        if let url = request.url, let typeFromURL = detectTypeFromURL(url, allowExtended: allowExt) {
            return typeFromURL
        }
        // may be nil when there was no Accept header and detectTypeFromURL was not successful
        return typeFromHeader
    }

    /// ObjC-compatible adapter of detectTypeFromRequest()
    ///
    /// - Returns: A valid NSNumber with WebRequestResourceType enum value or nil if type was not detected.
    @objc
    public static func objc_detectTypeFromRequest(_ request: URLRequest, allowExtended allowExt: Bool) -> NSNumber? {
        if let resourceType = detectTypeFromRequest(request, allowExtended: allowExt) {
            return NSNumber(value: resourceType.rawValue as Int)
        }
        return nil
    }

    fileprivate static func detectResourceTypeWithJavascript(_ ctx: JSContext,
                                                             url: String,
                                                             modifier: String) -> WebRequestResourceType? {
        var query = ctx.evaluateScript("document.querySelector('img[src\(modifier)=\"\(url)\"]')")
        if let query = query, !query.isNull && !query.isUndefined {
            return .image
        }

        query = ctx.evaluateScript("document.querySelector('script[src\(modifier)=\"\(url)\"]')")
        if let query = query, !query.isNull && !query.isUndefined {
            return .script
        }

        query = ctx.evaluateScript("document.querySelector('iframe[src\(modifier)=\"\(url)\"]')")
        if let query = query, !query.isNull && !query.isUndefined {
            return .subFrame
        }

        return nil
    }

    fileprivate static func detectResourceTypeOfURL(_ url: URL,
                                                    fromJSContext context: JSContext) -> WebRequestResourceType? {
        if let type = detectResourceTypeWithJavascript(context, url: url.absoluteString, modifier: "") {
            return type
        }

        // construct query-less URL and match "begins with" selector
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        guard let url = components?.string else {
            return nil
        }
        return detectResourceTypeWithJavascript(context, url: url, modifier: "^")
    }

    open static func queryFrameContext(_ context: JSContext?,
                                       webThread: Thread?,
                                       url: URL,
                                       operationQueue: OperationQueue,
                                       _ callback: @escaping (_ resourceType: WebRequestResourceType, _ isTentative: Bool) -> Void) {
        guard let context = context, let webThread = webThread else {
            /*
             Normally, JS context is already available here (didCreate was already called)
             but unfortunately this really can happen when the (main) frame is very simple
             and fast to parse:
             1. (main) frame starts loading in protocol handler
             2. frame resources start loading in protocol handler
             3. JSC creation arrives for (main) frame
             For the resources loaded in step 2, context is not available
             */
            callback(.other, true)
            return
        }
        perform(on: webThread, modes: nil) {

            // webThread does all the heavy lifting, so we try to relieve it by delegation
            if let resourceType = self.detectResourceTypeOfURL(url, fromJSContext: context) {
                operationQueue.addOperation {
                    callback(resourceType, false)
                }
            } else {
                // No match found by any method
                operationQueue.addOperation {
                    callback(.other, true)
                }
            }
        }
    }

    open static func queryDOMNodeWithSource(
        _ url: String,
        webView: WebViewProtocolDelegate,
        callback: @escaping (_ resourceType: WebRequestResourceType?, _ originFrame: WebKitFrame?) -> Void) {
        webView.domNode(forSourceAttribute: url) { nodeName, originFrame in
            if let nodeName = nodeName, let resourceType = domNodeType(for: nodeName) {
                callback(resourceType, originFrame)
            } else {
                callback(nil, originFrame)
            }
        }
    }
}

// MARK: Asynchronous detectors (slower)

/// mapping of DOM nodenames to Chrome contentTypes
private func domNodeType(for nodeName: String) -> WebRequestResourceType? {
    switch nodeName {
    case "img":
        return .image
    case "script":
        return .script
    case "iframe":
        return .subFrame
    default:
        return nil
    }
}
