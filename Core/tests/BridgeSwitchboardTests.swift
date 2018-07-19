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
@testable import KittCore
import XCTest

private let errorDomain = "KittCoreErrorDomain"

private enum LoggerType {
    case none
    case debug
    case info
    case warn
    case error
    case critical
}

private final class Logger: NSObject, LoggerSink {
    static var types = [LoggerType]()

    static func debug(_ message: String) {
        types.append(.debug)
    }

    static func info(_ message: String) {
        types.append(.info)
    }

    static func warn(_ message: String) {
        types.append(.warn)
    }

    static func error(_ message: String) {
        types.append(.error)
    }

    static func critical(_ error: StringCodeConvertibleError) {
        types.append(.critical)
    }
}

private struct TestsError: StringCodeConvertibleError {
    var shortCode: String {
        return "KittCoreTestsError"
    }
}

final class BridgeSwitchboardTests: XCTestCase {
    func testResultHandler() {
        let error = NSError(domain: errorDomain, code: 0, userInfo: nil)

        KittCoreLogger.loggerSinkType = Logger.self

        let handler = ResultHandler(command: "tests", context: [:])

        handler.completion(.success(nil))
        XCTAssert(Logger.types.count == 0)

        handler.completion(.failure(error))
        XCTAssert(Logger.types.count == 1 && Logger.types.last == .error)

        handler.completion(.failure(TestsError()))
        XCTAssert(Logger.types.count == 2 && Logger.types.last == .critical)

        handler.completion(.failure(IgnorableError(with: error)))
        XCTAssert(Logger.types.count == 3 && Logger.types.last == .info)

        handler.completion(.failure(NSError(code: .chromeBrowserActionNotAvailable, message: "")))
        XCTAssert(Logger.types.count == 4 && Logger.types.last == .debug)
    }
}
