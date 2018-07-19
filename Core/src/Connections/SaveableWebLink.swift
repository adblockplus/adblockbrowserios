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

/*
 SaveableWebLink is keeping informations about the requested web download
 and knows how to save itself depending on the expected content type.
 Calls SavingResultCallback when finished.
 */

import Foundation

public enum SavingResult {
    case success(removeFile:Bool)
    case failure(error:WebDownloadError)
}

public typealias SavingResultCallback = (_ result: SavingResult) -> Void

/*
 An unfortunate hack around the fact that `*SavedPhotosAlbum` UIKit functions use delegates
 for completion callbacks. So the reference to `SavingResultCallback` function must be
 captured strongly to survive between `saveDownloadedContent` and the delegate call. After the
 call however, the capture must be released so that the block on caller side can be released.
 */
open class SelfReleasingCallback {
    open var callback: SavingResultCallback?

    init!(_ callback: @escaping SavingResultCallback) {
        self.callback = callback
    }
    func call(_ result: SavingResult) {
        callback?(result)
        callback = nil
    }
}

@objc
public final class SaveableWebLink: NSObject {
    @objc
    public enum LinkType: Int {
        case image, video, other
    }

    public let url: URL
    public let type: LinkType

    /// The final filesystem location of the downloaded file
    fileprivate(set) public var downloadsLocation: URL?

    /// The download task for this web link.
    public weak var sessionTask: URLSessionTask?

    /// The filename that the temporary filename will be renamed to
    fileprivate var suggestedFilename: String?

    /// @see SelfReleasingCallback description
    fileprivate var handlerCallback: SelfReleasingCallback?

    @objc
    public init(url: URL, type: LinkType) {
        self.url = url
        self.type = type
        super.init()
    }

    public func saveDownloadedContent(_ atLocation: URL, callback: @escaping SavingResultCallback) {
        handlerCallback = SelfReleasingCallback(callback)
        downloadsLocation = atLocation
        switch type {
        case .image:
            guard let image = UIImage(contentsOfFile: atLocation.path) else {
                handlerCallback?.call(.failure(error: WebDownloadError.incompatibleContent))
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(SaveableWebLink.image(_:didFinishSavingWithError:contextInfo:)), nil)
        case .video:
            if !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(atLocation.path) {
                handlerCallback?.call(.failure(error: WebDownloadError.incompatibleContent))
                return
            }
            UISaveVideoAtPathToSavedPhotosAlbum(atLocation.path, self, #selector(SaveableWebLink.video(_:didFinishSavingWithError:contextInfo:)), nil)
        case .other:
            break
        }
    }

    // The selectors above have mandatory format. The following function signatures need to respect it.
    @objc
    public func image(_ image: UIImage, didFinishSavingWithError: NSError?, contextInfo: UnsafeMutableRawPointer) {
        if let error = didFinishSavingWithError {
            handlerCallback?.call(.failure(error: WebDownloadError.cameraRollSavingError(error: error)))
        } else {
            handlerCallback?.call(.success(removeFile:true))
            downloadsLocation = nil // Not in the Downloads anymore
        }
    }

    @objc
    public func video(_ path: NSString, didFinishSavingWithError: NSError?, contextInfo: UnsafeMutableRawPointer) {
        if let error = didFinishSavingWithError {
            handlerCallback?.call(.failure(error: WebDownloadError.cameraRollSavingError(error: error)))
        } else {
            handlerCallback?.call(.success(removeFile:true))
            downloadsLocation = nil // Not in the Downloads anymore
        }
    }
}
