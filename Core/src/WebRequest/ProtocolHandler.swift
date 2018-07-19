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

/**
 Universal protocol handler for outgoing request in http(s) schemes.
 Features:
 - Encapsulates encoding/decoding of tab id into the request.
 - Incercepts and blocks requests

 Inspired by https://developer.apple.com/library/ios/samplecode/CustomHTTPProtocol/Listings/CustomHTTPProtocol_Core_Code_CustomHTTPProtocol_m.html
 */

import Foundation

/**
 Universal protocol handler for outgoing request in http(s) schemes.
 Features:
 - Encapsulates encoding/decoding of tab id into the request.
 - Incercepts and blocks requests

 Inspired by
 https://developer.apple.com/library/ios/samplecode/CustomHTTPProtocol/Listing...
 */
@objc
final public class ProtocolHandler: URLProtocol {
    /// request URL schemes accepted by this protocol handler
    fileprivate static var rexProtocolSchemeMatch = try? NSRegularExpression(pattern: "^https?$",
                                                                             options: NSRegularExpression.Options())

    /// A private queue for NSURLConnectionDelegate calls.
    /// Shared by all NSURLProtocol instances.
    /// Without this extra queue, resource loading was stalling
    /// and timing out rarely but annoyingly.
    fileprivate static let delegateQueue = { () -> OperationQueue in
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
        return queue
    }()

    fileprivate let authenticator = ConnectionAuthenticator()
    fileprivate var details: WebRequestDetails?
    fileprivate var stoppedLoading = false

    fileprivate var clientThread: Thread?
    fileprivate var modes: [RunLoopMode]?

    fileprivate var activeConnection: NSURLConnection? {
        willSet {
            if let connection = activeConnection {
                connection.cancel()
                NetworkActivityObserver.sharedInstance().unregisterConnection(connection)
            }
        }
    }

    fileprivate weak var webView: WebViewProtocolDelegate?

    /// canInitWithRequest said YES, iOS will init us
    /// a transparent implementation at the moment
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        NetworkActivityObserver.sharedInstance().onProtocolHandlerInstantiated()
    }

    deinit {
        assert(activeConnection == nil)
        activeConnection = nil
        NetworkActivityObserver.sharedInstance().onProtocolHandlerDeallocated()
    }

    class func hasApplicableSchemeInRequest(_ request: URLRequest) -> Bool {
        let scheme = request.url?.scheme
        if let scheme = scheme, !scheme.isEmpty {
            let match = rexProtocolSchemeMatch?.firstMatch(in: scheme,
                                                           options: NSRegularExpression.MatchingOptions(),
                                                           range: NSRange(location: 0, length: scheme.count))

            return match != nil && (match!.range.length != 0)

        } else {
            // happens for about:blank
            return false
        }
    }

    // MARK: - Private

    func startLoadingWithRequest(_ request: TransformedRequest, andTabId tabId: UInt?) {
        assert(clientThread != nil)
        assert(clientThread == Thread.current)
        if stoppedLoading {
            return
        }

        let delegate = ConnectionDelegateSanitizer(forwardHandler: self)

        guard let connection = NSURLConnection(request: request.request, delegate: delegate, startImmediately: false) else {
            return
        }
        activeConnection = connection
        connection.setDelegateQueue(ProtocolHandler.delegateQueue)
        NetworkActivityObserver.sharedInstance().registerNewConnection(connection, forTabId: tabId as NSNumber?)
        connection.start()
    }

     /// Finds out if the request should be loaded, or blocked.
     /// - Returns: True if response was handled specifically and loading should not happen
     ///            or False if response was not handled at all or in a way that does not prevent normal loading
    func tryToHandle(_ response: BlockingResponse, with request: TransformedRequest) -> TransformedRequest? {
        assert(clientThread != nil && clientThread == Thread.current)
        if response.cancel {
            // simple empty code is not enough.
            // It renders the page correctly but continues "loading" indefinitely
            // Calls NSURLProtocolDelegate directly (not NSURLConnectionDelegate as the
            // fake response below) because WebRequestDelegate said Cancel which should mean
            // that it's not interested in WebRequestDelegate.onCompleted
            //      [[self client] URLProtocol:self didReceiveResponse:[NSURLResponse new]
            //              cacheStoragePolicy:NSURLCacheStorageAllowed];
            // WebKit seems to ignore this error code, it does not throw any error.
            cancelLoading()
            return nil
        } else if let redirectUrl = response.redirectUrl {

            guard let url = request.request.url, let redirectURL = URL(string: redirectUrl) else {
                Log.error("redirectURL is invalid")
                return nil
            }

            var redirectRequest = URLRequest(url: redirectURL)
            redirectRequest.passedProtocolHandler = false
            let redirectResponse = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "1.0", headerFields: nil)!
            webView?.onRedirectResponse(redirectResponse, to: redirectRequest)
            client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: redirectResponse)
            cancelLoading()
            return nil
        } else if let fakeResponse = response.fakeResponse {

            let fakeData: Data
            if let data = response.fakeData {
                fakeData = data
            } else {
                assert(false, "Fake data should be set")
                fakeData = Data()
            }

            let fakeConnection = NSURLConnection()
            // fake connection as context for NSURLConnectionDelegate
            connection(fakeConnection, didReceive: fakeResponse)
            connection(fakeConnection, didReceive: fakeData)
            connectionDidFinishLoading(fakeConnection)
            fakeConnection.cancel()
            activeConnection = fakeConnection
            return nil
        } else if let headers = response.requestHeaders, headers.count > 0 {
            var mutableRequest = request.request
            /**
             https://developer.chrome.com/extensions/webRequest#type-BlockingResponse
             requestHeaders: "If set, the request is made with these request headers instead."
             i.e. REPLACING the existing headers, which works fine except:
             "User-Agent": if cleared, CFNetwork will fill in a default "CFNetwork/X Darwin/Y" header
             Can't do anything about it. Seting UA to empty string is as good as it gets.
             "Cookie": if cleared, CFNetwork will fill in what is known from shared cookie storage.
             Which is NOT expected - if there is no Cookie header in the blocking response, there must be
             no Cookie in the outgoing request. And vice versa: any Cookie header in the blocking response
             will replace whatever CFNetwork knows for the request. Hence the default CFNetwork handling
             must be turned off.
             HACK WARNING:
             "Turning off" means that response "Set-Cookies" and request "Cookies" will became
             yet-another-ordinary header FOR THE GIVEN (request's) URL. "Set-Cookies" will appear
             in responses normally, CFNetwork will not care about them, parse them nor store them
             in NSHTTPCookieStorage. That is supposedly handled by the client code when he turned off
             the CFNetwork handling. THIS IS NOT HANDLED NOW. Incoming response cookies are ignored and
             outgoing requests will only have cookies if the requestHeaders contain some.
             */
            mutableRequest.httpShouldHandleCookies = false
            // NSMutableURLRequest is quite stubborn regarding actually clearing/removing
            // the existing headers, not just changing their value.
            // NO [mutableRequest setAllHTTPHeaderFields:nil];
            // NO [mutableRequest setAllHTTPHeaderFields:@{}];
            // NO [mutableRequest setAllHTTPHeaderFields:@{@"Header": [NSNull null]}];
            // NO [mutableRequest setAllHTTPHeaderFields:@{@"Header": @""}];
            // YES [mutableRequest setValue:nil forHTTPHeaderField:@"Header"];
            // Hence we need to iterate and remove by one

            for (key, _) in mutableRequest.allHTTPHeaderFields ?? [:] {
                mutableRequest.setValue(nil, forHTTPHeaderField: key)
            }

            // set the new, and only the new, headers
            for (key, value) in headers {
                if let key = key as? String, let value = value as? String {
                    mutableRequest.setValue(value, forHTTPHeaderField: key)
                }
            }
            return TransformedRequest(request: mutableRequest)
        } else {
            // none of the event handlers were interested in this request
            return request
        }
    }

    func performBlockOnClientThread(_ block: @escaping () -> Void) {
        assert(clientThread != nil)
        perform(on: clientThread, modes: modes, block: block)
    }
}

// MARK: - NSURLProtocol interface

extension ProtocolHandler {
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    // static peek, called by iOS
    override public class func canInit(with request: URLRequest) -> Bool {
        let passed = request.passedProtocolHandler
        let hasScheme = hasApplicableSchemeInRequest(request)

        return !passed && hasScheme
    }

    fileprivate func transformForSending(_ request: URLRequest) -> TransformedRequest {
        var finalRequest = request
        // Try to prohibit "Conditional request"
        // Where server is allowed, but not required, to respond 304 Not Modified
        // previous response Last-Modified -> new request If-Modified-Since
        // previous response ETag -> new request If-None-Match
        if let allHTTPHeaderFields = finalRequest.allHTTPHeaderFields {
            for (key, obj) in allHTTPHeaderFields {
                let headerKey = key.lowercased()
                if headerKey == "if-modified-since" || headerKey == "if-none-match" {
                    finalRequest.setValue(nil, forHTTPHeaderField: key)
                }

                // Clean up after transporting knowledge from the JS API via extra request header(s)
                if headerKey == "accept" {
                    // not interested in what Kitt appended, just normalizing
                    let (cleanedValue, _) = WebRequestDetails.separateKittValuesFromAcceptType(obj)
                    finalRequest.setValue(cleanedValue, forHTTPHeaderField: key)
                }
            }
        }
        finalRequest.passedProtocolHandler = true
        return TransformedRequest(request: finalRequest)
    }

    /// No details for any reason = extensions not involved
    /// tabId null: not originated in webview tab (background XHR etc.)
    /// start loading right away
    fileprivate func sendBypassChrome(_ request: TransformedRequest, tabId: UInt?) {
        performBlockOnClientThread {
            self.startLoadingWithRequest(request, andTabId: tabId)
        }
    }

    fileprivate func sendThroughChrome(_ request: TransformedRequest, tabId: UInt, details: WebRequestDetails) {
        guard let url = request.request.url else {
            Log.error("Tab \(tabId) request has no URL")
            return
        }
        let cookieJar = HTTPCookieStorage.shared
        let cookies = cookieJar.cookies(for: url) ?? []
        let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
        WebRequestEventDispatcher.sharedInstance().onBeforeSendHeaders(
            request.request.allHTTPHeaderFields,
            cookieHeaders: cookieHeaders,
            withDetails: details) { response in
                self.performBlockOnClientThread {
                    if let request = self.tryToHandle(response, with: request) {
                        self.details = details
                        self.startLoadingWithRequest(request, andTabId: tabId)
                        self.webView?.onDidStartLoading(url, isMainFrame: details.resourceType == .mainFrame)
                    }
                }
        }
    }

    /// iOS calls this
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override public func startLoading() {
        assert(clientThread == nil) // you can't call -startLoading twice
        clientThread = Thread.current

        /// UIWebView runs this in "WebCoreSynchronousLoaderRunLoopMode"
        var calculatedModes = [RunLoopMode.defaultRunLoopMode]
        if let currentMode = RunLoop.current.currentMode {
            if currentMode != RunLoopMode.defaultRunLoopMode {
                calculatedModes.append(currentMode)
            }
        }

        modes = calculatedModes

        let finalRequest = transformForSending(request)

        let requestURL = request.url?.absoluteString ?? "URL unknown"
        let mainDocURL = request.mainDocumentURL?.absoluteString ?? "URL unknown"

        guard let originatingTabId = TabIdCodec.decodeTabIdFromRequest(request) else {
            Log.debug("PROTO:startLoading NOTAB \(requestURL)")
            sendBypassChrome(finalRequest, tabId: nil)
            return
        }

        Log.debug("PROTO:startLoading tab id \(originatingTabId)) \(requestURL) main \(mainDocURL)")

        guard let webView = Chrome.sharedInstance.findContentWebView(UInt(originatingTabId)) else {
            cancelLoading()
            return
        }

        self.webView = webView

        guard let urlObject = request.url else {
            assert(false, "Cannot determine URL object for request")
            sendBypassChrome(finalRequest, tabId: originatingTabId)
            return
        }

        if urlObject.absoluteString.isEmpty {
            assert(false, "URL string for request is empty")
            sendBypassChrome(finalRequest, tabId: originatingTabId)
            return
        }

        let runOnBeforeRequest = { [weak self] (frame: KittFrame, resourceType: WebRequestResourceType, isTentative: Bool) in
            guard let sSelf = self else {
                return
            }

            guard let frameId = frame.frameId, let parentFrameId = frame.parentFrameId else {
                Log.error("Frame of request \(urlObject.absoluteString) has no frameId and/or parentFrameId")
                sSelf.sendBypassChrome(finalRequest, tabId: originatingTabId)
                return
            }

            let details = WebRequestDetails(request: finalRequest.request, resourceType: resourceType, fromTabId: UInt(originatingTabId))
            details.resourceTypeTentative = isTentative
            details.frameId = frameId.uintValue
            details.parentFrameId = parentFrameId.intValue

            WebRequestEventDispatcher.sharedInstance().onBeforeRequest(finalRequest.request, withDetails: details) { response in
                // onbeforerequest = there is no request to modify yet
                guard let sSelf = self else {
                    return
                }

                sSelf.performBlockOnClientThread {
                    if let request = sSelf.tryToHandle(response, with: finalRequest) {
                        sSelf.sendThroughChrome(request, tabId: originatingTabId, details: details)
                    }
                }
            }
        }

        /// Do all kinds of resourceType detection possible synchronously and without JS context
        if let resourceType = ResourceTypeDetector.detectTypeFromRequest(finalRequest.request, allowExtended: false) {
            let isMainFrame = resourceType == .mainFrame
            // If main frame content is being changed by clicking a link in the previous page,
            // main frame request has referrer of the previous main frame,
            // which is not in the mapping anymore. Force find mapping of the mainDocumentURL

            if let parentFrameURLString = finalRequest.request.parentFrameURLString ??
                (isMainFrame ? finalRequest.request.mainDocumentURL?.absoluteString : nil) {
                // known right away, run synchronously
                let frame = WebRequestEventDispatcher
                    .sharedInstance()
                    .getFrameFrom(urlObject.absoluteString,
                                  parentFrameURLString: parentFrameURLString,
                                  webView: webView,
                                  isMainFrame: isMainFrame,
                                  isSubFrame: resourceType == .subFrame)
                runOnBeforeRequest(frame, resourceType, false)
                return
            }
        }

        // Async query
        ResourceTypeDetector.queryDOMNodeWithSource(urlObject.absoluteString, webView: webView) { [weak self] resourceType, originFrame in
            // check originating frame first
            guard let sSelf = self else {
                return
            }

            let maybeKittFrame: KittFrame? = {
                if let originFrame = originFrame {
                    return webView.kittFrame(forWebKitFrame: originFrame)
                } else if let urlString = sSelf.request.mainDocumentURL?.absoluteString {
                    return webView.kittFrame(forReferer: urlString)
                }
                return nil
            }()

            guard let kittFrame = maybeKittFrame else {
                Log.warn("Failed to detect originating frame or even forcing main frame assignment, bypassing chrome for \(urlObject.absoluteString)")
                sSelf.sendBypassChrome(finalRequest, tabId: originatingTabId)
                return
            }

            if let resourceType = resourceType {
                runOnBeforeRequest(kittFrame, resourceType, false)
                return
            }
            // Resourcetype not found by request/URL alone neither in DOM node creation cache.
            // Happens legally for anything requestable not by DOM element (XHRs, CSS images, etc.)
            Log.info("Failed to detect request content type with cheap methods, going to unleash CSS selector for \(urlObject.absoluteString)")
            // Follows the heaviest operation - finding the node by URL directly in the DOM, with CSS selector
            let webThread = webView.bridgeSwitchboard?.injector?.webThread
            ResourceTypeDetector.queryFrameContext(
                kittFrame.context,
                webThread: webThread,
                url: urlObject,
                operationQueue: ProtocolHandler.delegateQueue) { contentType, isTentative in
                    runOnBeforeRequest(kittFrame, contentType, isTentative)
            }
        }
    }

    override public func stopLoading() {
        // stopLoading needs to be called on client thread and after starLoading has been called.
        assert(clientThread != nil && clientThread == Thread.current)
        if stoppedLoading {
            return
        }
        stoppedLoading = true
        activeConnection = nil
        details = nil
    }

    public func finishLoading() {
        if stoppedLoading {
            //assert(false)
            return
        }
        client?.urlProtocolDidFinishLoading(self)
        stopLoading()
    }

    public func failLoading(with error: Error) {
        if stoppedLoading {
            assert(false)
            return
        }
        client?.urlProtocol(self, didFailWithError: error)
        stopLoading()
    }

    @objc
    public func cancelLoading() {
        failLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))
    }
}

// MARK: - NSURLConnectionDelegate

/// These are delegate event handlers for the forged _connection (if startLoading created one)
/// as well as for the fake URL connections which the WebRequestDelegate may generate
extension ProtocolHandler: NSURLConnectionDataDelegate {
    public func connection(_ connection: NSURLConnection,
                           willSend request: URLRequest,
                           redirectResponse response: URLResponse?) -> URLRequest? {
        guard let response = response else {
            /**
             Canonical rewrite. Means that there is no real redirection originated in the protocol,
             but just the `canonicalRequestForRequest` handler has returned something and the delegate
             wants to tell us. Sources claim that this is called for _every_ request going through protocol,
             my observation is different. Anyway, according to Apple doc, delegate expects the original
             request being returned and it really works.
             */
            return request
        }

        #if DEBUG
            let url = String(describing: request.url?.absoluteString)
            let mainUrl = String(describing: request.mainDocumentURL?.absoluteString)
            let responseUrl = String(describing: response.url?.absoluteString)
            Log.debug("PROTO:redirect request \(url) main \(mainUrl) response \(responseUrl)")
        #endif

        /**
         Order of redirection events:
         1. original request created here
         2. server responds with a redirection
         3. iOS creates a new request, following the requirements of the response
         4. iOS copies all applicable properties of the 1st request to the new request
         Conclusion: despite the new request never going through our constructor and/or `startLoading`, it
         has all the HTTP headers and attached [NSURLProtocol propertyForKey] as the original request.
         Unfortunately it means that this new request is marked as if it already gone through our protocol
         handler (regardless of the marking method, as both headers and properties are copied along).
         If we want the protocol handler to notice the new redirected request (which it must, because it
         is _the_ new right request, with the new right URL), the flag must be cleared from it.
         */
        var redirectableRequest = request
        redirectableRequest.passedProtocolHandler = false
        webView?.onRedirectResponse(response, to: redirectableRequest)
        // Let the host NSURLProtocol know we're redirecting
        performBlockOnClientThread {
            self.client?.urlProtocol(self, wasRedirectedTo: redirectableRequest, redirectResponse: response)
            self.cancelLoading()
        }
        /**
         According to NSURLConnectionDataDelegate doc, there is 3 possible values returnable from this
         event handler:
         1. "request unmodified to allow the redirect". This works well for canonical rewrite, but is not
         an option otherwise, because its attached property must be modified.
         2. "a new request". This sounds like the right thing to do. Unfortunately, my lengthy
         observation is that it never works right. Basically, iOS runs "the new request"
         _and_ "the old" one (given as parameter) too. There is essentially two equal requests going
         out on the wire (equal because we're modifying just an attached property). Just the timing
         is variable. Sometimes one roundtrip succeeds completely before the other one kicks out.
         Sometimes both requests go out simultaneously, resulting in the later one to get cancelled.
         Sometimes only one goes out ("correctly"), but mostly just on the first occassion after
         a fresh app installation (something to do with cache, i guess).
         If you wonder why it's a problem (the data get back from at least one response correctly, in
         the end), there are specific websites where two equal requests break the whole thing badly.
         1) http://clojure.org
         2) redirects to https://session.wikispaces.com/1/auth/auth?authToken=<somehash>
         3) redirects to http://clojure.org/?responseToken=<thesamehash>
         4) redirects to http://clojure.org while something was supposedly set on the server. So it is
         the same request as the first one, but it loads the expected page instead of redirect.
         If 3) goes out twice, first server response contains correct redirect 4), but the second one
         makes the server to redirect again (repeating 2). Just try it with curl,
         not even any headers are needed. The loading eventually aborts with "too many redirects". It
         might very much be a wrong wikispaces API implementation on clojure.org side, but we can't
         go harassing every such malfunctioning site (and wikispaces is HUGE).
         3. "nil to reject the redirect and continue processing the connection".
         Scary. However, further down the doc reads:
         "To receive the body of the redirect response itself, return nil to cancel the redirect.
         The connection continues to process, eventually sending your delegate a ... message,
         as appropriate."
         Doesn't sound like a reject, does it? The doc is confusing and nil is actually the only
         return value which works consistently as expected. Only one request goes out and it's the
         newly created one. The old one is thrown away (`stopLoading` is called on it)
         */
        return nil
    }

    public func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
        #if DEBUG
            let url = String(describing: connection.currentRequest.url?.absoluteString)
            Log.debug("PROTO:didReceiveResponse \(url)")
        #endif

        performBlockOnClientThread {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        }

        if let httpResponse = response as? HTTPURLResponse, let details = details {
            NetworkActivityObserver.sharedInstance().connection(connection,
                                                                receivedResponseWithExpectedLength: httpResponse.expectedContentLength)
            // suspected to be sending nil headers despite the Swift interface contract
            if !Utils.isObjectReferenceNil(httpResponse.allHeaderFields) {
                WebRequestEventDispatcher.sharedInstance().onHeadersReceived(httpResponse.allHeaderFields, withDetails: details) { _ in }
            }
        }
    }

    public func connection(_ connection: NSURLConnection, didReceive data: Data) {
        #if DEBUG
            let url = String(describing: connection.currentRequest.url?.absoluteString)
            Log.debug("PROTO:didReceiveData \(CLong(data.count)) \(url)")
        #endif
        performBlockOnClientThread {
            self.client?.urlProtocol(self, didLoad: data)
        }
        NetworkActivityObserver.sharedInstance().connection(connection, receivedDataLength: UInt(data.count))
    }

    public func connectionDidFinishLoading(_ connection: NSURLConnection) {
        #if DEBUG
            let url = String(describing: connection.currentRequest.url?.absoluteString)
            Log.debug("PROTO:didFinishLoading \(url)")
        #endif
        performBlockOnClientThread {
            self.finishLoading()
        }
    }

    public func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        #if DEBUG
            let url = String(describing: connection.currentRequest.url?.absoluteString)
            Log.debug("PROTO:didFailWithError \(url)")
        #endif
        webView?.onErrorOccured(with: connection.currentRequest)
        performBlockOnClientThread {
            self.failLoading(with: error)
        }
    }

    /// A preferred modern way to handle authentication requests, instead of
    /// canAuthenticateAgainstProtectionSpace and didReceiveAuthenticationChallenge
    public func connection(_ connection: NSURLConnection,
                           willSendRequestFor challenge: URLAuthenticationChallenge) {
        Log.debug("PROTO:willSendRequestForAuthenticationChallenge")
        // I suppose that any call to [challenge sender] must obey the same ordering
        // restriction as calls to [self client]. I have no counter evidence. The effect
        // is that whole handler must be dispatched to connectionEventsQueue.
        perform(on: nil, modes: nil) {
            self.authenticator.authenticateChallenge(challenge) { result in
                if self.details?.resourceType == .mainFrame {
                    self.webView?.mainFrameAuthenticationResult = result
                }
                self.performBlockOnClientThread {
                    if result.level == .unknown {
                        challenge.sender?.continueWithoutCredential(for: challenge)
                    } else if result.level == .untrusted {
                        self.cancelLoading()
                    }
                }
            }
        }
    }
}

struct TransformedRequest {
    var request: URLRequest
    // swiftlint:disable:next file_length
}
