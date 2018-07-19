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

// make the code statements reasonably short
typealias Log = KittCoreLogger

public protocol LoggerSink {
    static func debug(_ message: String)
    static func info(_ message: String)
    static func warn(_ message: String)
    static func error(_ message: String)
    static func critical(_ error: StringCodeConvertibleError)
}

public protocol StringCodeConvertibleError: Error {
    var shortCode: String { get }
}

public struct CodeRelatedError: StringCodeConvertibleError {
    private enum ErrorCause {
        case message(String)
        case error(Error)
    }

    private let relatedCodeError: StringCodeConvertibleError
    private let cause: ErrorCause

    init(_ relatedCodeError: StringCodeConvertibleError, message: String) {
        self.relatedCodeError = relatedCodeError
        self.cause = .message(message)
    }

    init(_ relatedCodeError: StringCodeConvertibleError, error: Error) {
        self.relatedCodeError = relatedCodeError
        self.cause = .error(error)
    }

    public var shortCode: String {
        // @todo the cause description should be rolled in this somehow
        // but let's wait after we see if this even works on HA
        return relatedCodeError.shortCode
    }
}

public final class KittCoreLogger: NSObject {
    public static var loggerSinkType: LoggerSink.Type?

    public static func debug(_ message: String,
                             file: StaticString = #file,
                             function: StaticString = #function,
                             line: UInt = #line) {
        loggerSinkType?.debug(format(message, file: file, function: function, line: line))
    }

    public static func info(_ message: String,
                            file: StaticString = #file,
                            function: StaticString = #function,
                            line: UInt = #line) {
        loggerSinkType?.info(format(message, file: file, function: function, line: line))
    }

    public static func warn(_ message: String,
                            file: StaticString = #file,
                            function: StaticString = #function,
                            line: UInt = #line) {
        loggerSinkType?.warn(format(message, file: file, function: function, line: line))
    }

    public static func error(_ message: String,
                             file: StaticString = #file,
                             function: StaticString = #function,
                             line: UInt = #line) {
        loggerSinkType?.error(format(message, file: file, function: function, line: line))
    }

    public static func critical(_ error: StringCodeConvertibleError) {
        loggerSinkType?.critical(error)
    }

    // MARK: - Objective-C interface

    @objc
    public static func plainDebug(_ message: String) {
        loggerSinkType?.debug(message)
    }

    @objc
    public static func plainInfo(_ message: String) {
        loggerSinkType?.info(message)
    }

    @objc
    public static func plainWarn(_ message: String) {
        loggerSinkType?.warn(message)
    }

    @objc
    public static func plainError(_ message: String) {
        loggerSinkType?.error(message)
    }

    public static func plainCritical(_ error: StringCodeConvertibleError) {
        loggerSinkType?.critical(error)
    }

    // MARK: - Private 

    private static func format(_ message: String,
                               file: StaticString = #file,
                               function: StaticString = #function,
                               line: UInt = #line) -> String {
        return "[\(file):\(function):\(line)] \(message)"
    }
}
