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

public final class URLProtocolWithCookies: URLProtocol {
    var dataTask: URLSessionDataTask?
    var sessionManager: SessionManager?

    var clientThread: Thread?
    var modes = [String]()

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    /// static peek, called by iOS
    override public class func canInit(with request: URLRequest) -> Bool {
        let passed = request.passedURLProtocolWithSession
        let hasScheme = ProtocolHandler.hasApplicableSchemeInRequest(request)
        if !passed && hasScheme,
            let tabId = TabIdCodec.decodeTabIdFromRequest(request),
            let (_, tab) = Chrome.sharedInstance.findTab(tabId) {
            // NSURLSession is used only for incognito tabs.
            // The rest is using shared cookie storage.
            // It would be nice to use session for all tabs,
            // but it was causing problem on alza.cz (only page, which I managed to reproduce it)
            return tab.incognito
        } else {
            return false
        }
    }

    /// canInitWithRequest said YES, iOS will init us
    /// a transparent implementation at the moment
    override public init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override public func startLoading() {
        assert(clientThread == nil)

        // Taken from reference implementation
        var calculatedModes = [String]()
        calculatedModes.append(RunLoopMode.defaultRunLoopMode.rawValue)
        if let currentMode = RunLoop.current.currentMode, currentMode != RunLoopMode.defaultRunLoopMode {
            calculatedModes.append(currentMode.rawValue)
        }

        modes = calculatedModes
        clientThread = Thread.current

        let startLoadingBlock = { (sessionManager: SessionManager) -> Void in
            var finalRequest = self.request
            finalRequest.passedURLProtocolWithSession = true
            self.sessionManager = sessionManager
            self.dataTask = sessionManager.startDataTask(finalRequest, withDelegate: self)
        }

        guard let tabId = TabIdCodec.decodeTabIdFromRequest(request) else {
            assert(false)
            startLoadingBlock(SessionManager.defaultSessionManager)
            return
        }

        if let sessionManager = WebRequestEventDispatcher.sharedInstance().sessionManagerForWebView(withTabId: tabId) {
            startLoadingBlock(sessionManager)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override public func stopLoading() {
        assert(clientThread == Thread.current)

        if let dataTask = dataTask {
            sessionManager?.cancelDataTask(dataTask)
        }

        dataTask = nil
        sessionManager = nil
    }

    func performBlockOnClientThread(_ block: @escaping () -> Void) {
        assert(clientThread != nil)

        if let clientThread = clientThread {
            perform(on: clientThread, modes: modes, block: block)
        }
    }
}

// MARK: - URLSessionDataDelegate

extension URLProtocolWithCookies: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {
        var redirectableRequest = request
        redirectableRequest.passedURLProtocolWithSession = false

        performBlockOnClientThread {
            let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
            // Let the host NSURLProtocol know we're redirecting
            self.client?.urlProtocol(self, wasRedirectedTo: redirectableRequest, redirectResponse: response)
            self.client?.urlProtocol(self, didFailWithError: error)
            self.stopLoading()
        }
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        performBlockOnClientThread {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            completionHandler(.allow)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        performBlockOnClientThread {
            self.client?.urlProtocol(self, didLoad: data)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        performBlockOnClientThread {
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
}
