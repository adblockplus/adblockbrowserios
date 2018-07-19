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

public enum WebDownloadError: Error, CustomStringConvertible {
    /// Session download task failed
    case sessionError(error: Error?)

    /// The data structure for download task was lost
    case sessionInconsistency

    /// The downloaded content is not what it claims to be
    case incompatibleContent

    /// Could not move the file away from temporary location
    case temporaryRenameFailure(error: Error?)

    /// The final location for downloaded files is invalid
    case invalidDownloadsLocation

    /// The downloaded file from the final location could not be deleted
    case downloadDeleteFailure(error: Error?)

    /// UIKit saving blackbox function failed
    case cameraRollSavingError(error: Error?)

    public var description: String {
        var message: String?
        var internalErrorName: String?
        var systemError: Error?
        switch self {
        case .sessionError(let error):
            message = bundleLocalizedString("File download failed due to network error.", comment: "Web download failure description")
            systemError = error
        case .sessionInconsistency:
            internalErrorName = "SessionInconsistency"
        case .incompatibleContent:
            message = bundleLocalizedString("The file had an unexpected content.", comment: "Web download failure description")
        case .temporaryRenameFailure(let error):
            internalErrorName = "TemporaryRenameFailure"
            systemError = error
        case .invalidDownloadsLocation:
            internalErrorName = "InvalidDownloadsLocation"
        case .downloadDeleteFailure(let error):
            internalErrorName = "DownloadDeleteFailure"
            systemError = error
        case .cameraRollSavingError(let error):
            message = bundleLocalizedString("The file could not be saved to Camera Roll.", comment: "Web download failure description")
            systemError = error
        }
        // Specific message already set, or it is an internal error that the user should not be annoyed with.
        // Cannot place in each branch (even if it allowed `message` being non-optional) because it would
        // result in redundant translations.
        let description = {message, internalErrorName -> String in
            if let message = message {
                return message
            } else {
                // Unwrapping needed to prevent "Optional(foo)" rendering to string
                let internalErrorName = internalErrorName ?? "Undefined"
                // WARNING NSLocalizedString does not support interpolated string variables
                // ie. "error \(internalErrorName)" would not get matched in Localizable.strings
                // Good ol' ObjC "error %@" is needed.
                return String(format: bundleLocalizedString("File download failed due to internal error %@.",
                                                            comment: "Web download failure description"), arguments: [internalErrorName])
            }
        }(message, internalErrorName)
        if let errorStr = systemError?.localizedDescription {
            return "\(description)\n\(errorStr)"
        } else {
            return description
        }
    }
}
