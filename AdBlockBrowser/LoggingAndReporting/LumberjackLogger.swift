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
 Specific implementation of logger based on CocoaLumberjack
 */

import CocoaLumberjackSwift
import Foundation

/// NSDateFormatter is not threadsafe, using it in multiple loggers is possible but requires an elaborate thread safety instrumentation.
/// https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomFormatters.md#thread-safety-simple
/// Therefore each logger must have its own instance of log formatter.
final class LumberjackLogger: LoggerSink {
    private static var instance: LumberjackLogger?

    static func createInstance(eventFunnel: EventSendingFunnel) {
        if instance == nil {
            instance = LumberjackLogger(eventFunnel: eventFunnel)
        }
    }

    private let eventFunnel: EventSendingFunnel

    private init(eventFunnel: EventSendingFunnel) {
        self.eventFunnel = eventFunnel
        defaultDebugLevel = .warning

        if let ttyLogger = DDTTYLogger.sharedInstance {
            ttyLogger.logFormatter = LumberjackFormatter()
            DDLog.add(ttyLogger)
        }
        if let aslLogger = DDASLLogger.sharedInstance {
            aslLogger.logFormatter = LumberjackFormatter()
            DDLog.add(aslLogger)
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
        instance?.eventFunnel.register(error: error)
    }

    /// - parameter forcedRegisteringCompletion: if set, will send error regardless of
    /// crash reporting status and user (dis)approval
    static func critical(_ error: StringCodeConvertibleError, forcedRegisteringCompletion: @escaping () -> Void) {
        DDLogError(error.shortCode)
        instance?.eventFunnel.register(error: error, forcedRegisteringCompletion: forcedRegisteringCompletion)
    }
}
