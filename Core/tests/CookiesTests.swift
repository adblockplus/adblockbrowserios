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

class CookiesTests: XCTestCase {
    func testParser() {
        let date = Date().addingTimeInterval(3600)
        let dateString = cookieDateFormatter.string(from: date)
        let name = "name"
        let value = "value"
        let cookieString = "\(name)=\(value); expIres=\(dateString); domain=.example.com; pAth=/"
        let cookie = createHTTPCookie(from: URL(string: "http://example.com")!, cookie: cookieString)
        XCTAssert(cookie?.name == name)
        XCTAssert(cookie?.value == value)
        XCTAssert(cookieDateFormatter.string(from: date) == dateString)
    }

    class CookieStorage: CookieStorageProvider {
        var cookieStorage: HTTPCookieStorage?
    }

    func testGetterAndSetter() {
        let cookieStorage = CookieStorage()
        let configuration = URLSessionConfiguration.ephemeral
        cookieStorage.cookieStorage = configuration.httpCookieStorage

        let setter = cookieSetter(for: cookieStorage)
        let getter = cookieGetter(for: cookieStorage)

        let date = Date().addingTimeInterval(3600)
        let dateString = cookieDateFormatter.string(from: date)
        let url = "http://example.com"
        let cookies = [("name1", "value1"), ("name2", "value2"), ("name3", "value3")]

        for (name, value) in cookies {
            let cookieString = "\(name)=\(value); expIres=\(dateString); domain=.example.com; pAth=/"
            setter(url, cookieString)
        }

        let cookiesString = cookies
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "; ")
        let newCookiesString = getter(url)

        XCTAssert(newCookiesString == cookiesString)
    }
}
