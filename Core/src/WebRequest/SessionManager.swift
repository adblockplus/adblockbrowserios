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

import UIKit

let operationQueue = OperationQueue()

func synchronized<R>(_ lock: AnyObject, block: () throws -> R ) rethrows -> R {
    objc_sync_enter(lock)
    defer {
        objc_sync_exit(lock)
    }
    return try block()
}

public final class SessionManager: NSObject, URLSessionDataDelegate {
    @objc public static let defaultSessionManager = SessionManager(useDefaultSessionConfiguration: true)

    fileprivate let lock = NSObject()
    fileprivate let session: URLSession
    fileprivate var protocols: [Int: URLSessionDataDelegate] = [:]

    public init(useDefaultSessionConfiguration: Bool = false) {
        let sessionDataDelegate = DefaultSessionDataDelegate()
        let configuration: URLSessionConfiguration
        if useDefaultSessionConfiguration {
            configuration = URLSessionConfiguration.default
        } else {
            configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieAcceptPolicy = .always
        }
        session = URLSession(configuration: configuration, delegate: sessionDataDelegate, delegateQueue: operationQueue)
        super.init()
        sessionDataDelegate.sessionManager = self
    }

    deinit {
        session.invalidateAndCancel()
    }

    func startDataTask(_ request: URLRequest, withDelegate delegate: URLSessionDataDelegate) -> URLSessionDataTask {
        let dataTask = session.dataTask(with: request)
        synchronized(lock) {
            protocols[dataTask.taskIdentifier] = delegate
        }
        dataTask.resume()
        return dataTask
    }

    func cancelDataTask(_ dataTask: URLSessionDataTask) {
        dataTask.cancel()
        removeDataTask(dataTask)
    }

    func removeDataTask(_ dataTask: URLSessionDataTask) {
        _ = synchronized(lock) {
            protocols.removeValue(forKey: dataTask.taskIdentifier)
        }
    }

    func protocolDataTaskIdentifier(_ taskIdentifier: Int) -> URLSessionDataDelegate? {
        return synchronized(lock) {
            return protocols[taskIdentifier]
        }
    }

    public var cookieStorage: HTTPCookieStorage? {
        return session.configuration.httpCookieStorage
    }
}

// MARK: - URLSessionDataDelegate

private final class DefaultSessionDataDelegate: NSObject, URLSessionDataDelegate {
    weak var sessionManager: SessionManager?

    @objc
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard let delegate = sessionManager?.protocolDataTaskIdentifier(task.taskIdentifier) ,
            delegate.urlSession?(session,
                                 task: task,
                                 willPerformHTTPRedirection: response,
                                 newRequest: request,
                                 completionHandler: completionHandler) != nil else {
                completionHandler(request)
                return
        }
    }

    @objc
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let delegate = sessionManager?.protocolDataTaskIdentifier(task.taskIdentifier) ,
            delegate.urlSession?(session, task: task, didReceive: challenge, completionHandler: completionHandler) != nil else {
                completionHandler(.performDefaultHandling, nil)
                return
        }
    }

    @objc
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let delegate = sessionManager?.protocolDataTaskIdentifier(dataTask.taskIdentifier) ,
            delegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler) != nil else {
                completionHandler(.allow)
                return
        }
    }

    @objc
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard let delegate = sessionManager?.protocolDataTaskIdentifier(dataTask.taskIdentifier) ,
            delegate.urlSession?(session,
                                 dataTask: dataTask,
                                 willCacheResponse: proposedResponse,
                                 completionHandler: completionHandler) != nil else {
                completionHandler(proposedResponse)
                return
        }
    }

    @objc
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let delegate = sessionManager?.protocolDataTaskIdentifier(dataTask.taskIdentifier) {
            delegate.urlSession?(session, dataTask: dataTask, didReceive: data)
        }
    }

    @objc
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let delegate = sessionManager?.protocolDataTaskIdentifier(task.taskIdentifier) {
            delegate.urlSession?(session, task: task, didCompleteWithError: error)

            if let dataTask = task as? URLSessionDataTask {
                sessionManager?.removeDataTask(dataTask)
            }
        }
    }
}
