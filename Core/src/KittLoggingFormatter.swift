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

import CocoaLumberjackSwift
import Foundation

// NSObject inheritance is needed only for @objc exportability
@objc
open class KittLoggingFormatter: NSObject, DDLogFormatter {
    fileprivate let dateFormatter = DateFormatter()

    public override init() {
        super.init()
        dateFormatter.dateFormat = "HHmmss.SSS"
    }

    open func format(message logMessage: DDLogMessage) -> String? {
        return String(format: "%@|%@|%@(%@) %@", arguments: [
            KittLoggingFormatter.stringFromFlag(logMessage.flag),
            dateFormatter.string(from: logMessage.timestamp),
            logMessage.threadID,
            logMessage.threadName,
            logMessage.message])
    }

    fileprivate static func stringFromFlag(_ flag: DDLogFlag) -> String {
        switch flag {
        case DDLogFlag.error:
            return "-E-"
        case DDLogFlag.warning:
            return ".W."
        case DDLogFlag.info:
            return " I "
        case DDLogFlag.debug:
            return " d "
        case DDLogFlag.verbose:
            return " v "
        default:
            return "?"
        }
    }
}
