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

class LoggingManager: LoggerSink {
    private static var instance: LoggingManager?

    static func createInstance() {
        if instance == nil {
            instance = LoggingManager()
        }
    }

    private init() {

        // Set the default level.
        dynamicLogLevel = .warning

        // Instantiate the loggers!
        if let ttyLogger = DDTTYLogger.sharedInstance {
            ttyLogger.logFormatter = LumberjackFormatter()
            DDLog.add(ttyLogger)
        }
        if let osLogger = DDOSLogger.sharedInstance {
            osLogger.logFormatter = LumberjackFormatter()
            DDLog.add(osLogger)
        }
    }

    static func debug(_ message: String) {
        DDLogDebug(message)
    }

    static func info(_ message: String) {
        DDLogInfo(message)
    }

    static func warn(_ message: String) {
        DDLogWarn(message)
    }

    static func error(_ message: String) {
        DDLogError(message)
    }

    static func critical(_ error: StringCodeConvertibleError) {
        DDLogError(error.shortCode)
        FabricManager.shared.forwardErrorToManager(error: error)
    }
}

class LumberjackFormatter: NSObject, DDLogFormatter {
    private let dateFormatter = DateFormatter()

    public override init() {
        super.init()
        dateFormatter.dateFormat = "HHmmss.SSS"
    }

    @objc
    public func format(message logMessage: DDLogMessage) -> String? {
        return String(format: "%@|%@|%@(%@) %@", arguments: [
            LumberjackFormatter.stringFromFlag(flag: logMessage.flag),
            dateFormatter.string(from: logMessage.timestamp),
            logMessage.threadID,
            logMessage.threadName,
            logMessage.message])
    }

    private static func stringFromFlag(flag: DDLogFlag) -> String {
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
            return "   " // lowest level, print nothing
        default:
            return "?"
        }
    }
}
