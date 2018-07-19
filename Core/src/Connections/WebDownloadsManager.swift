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

// CALL ON MAIN THREAD !!!
public protocol DownloadsUIFeedbackDelegate: NSObjectProtocol {
    func downloadFailed(_ link: SaveableWebLink?, error: WebDownloadError)
    func downloadSucceeded(_ link: SaveableWebLink)
}

/*
 Starts session downloads, keeps track of them
 Moves the downloaded files from temporary location to persistent app location
 Calls the file handler, accepts handling result
 
 The task needs to start as DataTask to provide an opportunity to cancel it upon receiving
 a response header. When not cancelled, it becomes a DownloadTask.
 */
@objc
public final class WebDownloadsManager: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
    public weak var uiFeedbackDelegate: DownloadsUIFeedbackDelegate?

    fileprivate lazy var session: Foundation.URLSession = {
        return Foundation.URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: self,
            delegateQueue: nil)
    }()

    // a mapping used from NSURLSession delegate calls
    fileprivate var linksForTasks = [URLSessionTask: SaveableWebLink]()
    // will get added in the Documents directory
    fileprivate final let downloadsSubfolder = "Downloads"
    fileprivate var downloadsDirURL: URL?

    public init(uiDelegate: DownloadsUIFeedbackDelegate) {
        self.uiFeedbackDelegate = uiDelegate
        super.init()
        let docDirs = NSSearchPathForDirectoriesInDomains(
            FileManager.SearchPathDirectory.documentDirectory,
            FileManager.SearchPathDomainMask.userDomainMask,
            true)
        if let docDir = docDirs.last {
            let downloadsDirURL = URL(fileURLWithPath: docDir)
                .appendingPathComponent(downloadsSubfolder, isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: downloadsDirURL,
                    withIntermediateDirectories: true,
                    attributes: nil)
                self.downloadsDirURL = downloadsDirURL
            } catch _ {
                // the result is self.downloadsDirURL not set
                // which is gracefuly failed with InvalidDownloadsLocation
            }
        }
    }

    @objc
    public func enqueue(_ link: SaveableWebLink) {
        var request = URLRequest(
            url: link.url,
            cachePolicy: .reloadIgnoringCacheData,
            timeoutInterval: TimeInterval(15))
        request.setValue(Settings.defaultWebViewUserAgent(), forHTTPHeaderField: "User-Agent")
        let sessionTask = session.dataTask(with: request)
        link.sessionTask = sessionTask
        linksForTasks[sessionTask] = link
        sessionTask.resume()
    }

    // MARK: NSURLSessionDataDelegate

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(Foundation.URLSession.ResponseDisposition.becomeDownload)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        let linkToMoveOver = linksForTasks[dataTask]
        linksForTasks[dataTask] = nil
        linksForTasks[downloadTask] = linkToMoveOver
    }

    // MARK: NSURLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let link = linksForTasks[downloadTask] else {
            self.dispatchFailure(nil, error: .sessionInconsistency)
            return
        }
        guard let downloadsDirURL = downloadsDirURL else {
            self.dispatchFailure(link, error: .invalidDownloadsLocation)
            return
        }

        let suggestedFilename = link.url.lastPathComponent
        /*
         The temp file downloaded to `location` must be copied or moved away, because URLSession will delete it
         upon exiting this delegate call. Other option is "opening for reading" which is not applicable because
         `handleDownloadedContent` is an asynchronous process with unknown internals
         (like UIImageWriteToSavedPhotosAlbum).
         */
        let downloadsLocation = downloadsDirURL.appendingPathComponent(suggestedFilename)

        do {
            try FileManager.default.moveItem(at: location, to: downloadsLocation)
        } catch let error {
            self.dispatchFailure(link, error: .temporaryRenameFailure(error: error))
            return
        }
        let backgroundQueue = DispatchQueue.global(qos: .background)
        backgroundQueue.async { () -> Void in
            link.saveDownloadedContent(downloadsLocation, callback: { result -> Void in
                switch result {
                case .success(let removeFile):
                    self.dispatchSuccess(link)
                    if removeFile, let location = link.downloadsLocation {
                        do {
                            try FileManager.default.removeItem(at: location)
                        } catch let error {
                            self.dispatchFailure(link, error: .downloadDeleteFailure(error: error))
                        }
                    }
                case .failure(let error):
                    self.dispatchFailure(link, error: error)
                }
            })
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let link = linksForTasks[task] else {
            self.dispatchFailure(nil, error: .sessionInconsistency)
            return
        }
        // error = nil means success so handle just the error case here.
        // Success is only a complete success after saveDownloadedContent callback
        if let error = error {
            self.dispatchFailure(link, error: .sessionError(error: error))
        }
    }

    fileprivate func dispatchSuccess(_ link: SaveableWebLink) {
        DispatchQueue.main.async { () -> Void in
            self.uiFeedbackDelegate?.downloadSucceeded(link)
        }
        if let task = link.sessionTask {
            linksForTasks[task] = nil
        }
    }

    fileprivate func dispatchFailure(_ link: SaveableWebLink?, error: WebDownloadError) {
        DispatchQueue.main.async { () -> Void in
            self.uiFeedbackDelegate?.downloadFailed(link, error: error)
        }
        if let task = link?.sessionTask {
            linksForTasks[task] = nil
        }
    }
}
