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

extension SAContentWebView {
    // We need to override default cookie storage in webView,
    // since it is using shared cookie storage.
    func changeCookieStorage(in context: JSContext) {
        // Shared cookie storage is overridden just for incognito tabs
        guard let tab = chromeTab, tab.incognito else {
            return
        }

        guard let document = context.globalObject?.objectForKeyedSubscript("document") else {
            return
        }

        document.setObject(cookieGetter(for: tab), forKeyedSubscript: "__cookiesForURL" as NSString)
        document.setObject(cookieSetter(for: tab), forKeyedSubscript: "__setCookie" as NSString)

        // document.cookie is property with this behaviour:
        // get: return all stored cookies with format "key=value; ..."
        // set: Stores exactly ONE cookie to cookie storage.
        // You can use modifiers (Max-Age) to adjust scope and durability of stored cookie.
        context.evaluateScript("Object.defineProperty(document, 'cookie', {"
            + "get: document.__cookiesForURL.bind(null, window.location.href),"
            + "set: document.__setCookie.bind(null, window.location.href),"
            + "configurable: true"
            + "});")
    }
}

protocol CookieStorageProvider: class {
    var cookieStorage: HTTPCookieStorage? { get }
}

extension ChromeTab: CookieStorageProvider {
    var cookieStorage: HTTPCookieStorage? {
        return sessionManager.cookieStorage
    }
}

let cookieDateFormatter = { () -> DateFormatter in
    let dateFormatter = DateFormatter()
    let enUSPOSIXLocale = Locale(identifier: "en_US_POSIX")
    dateFormatter.locale = enUSPOSIXLocale
    dateFormatter.dateFormat = "EEE, dd MM yyyy HH:mm:ss zzz"
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    return dateFormatter
}()

func createHTTPCookie(from url: URL, cookie: String) -> HTTPCookie? {
    var properties: [HTTPCookiePropertyKey: Any]?
    var isFirstItem = true
    let whitespaces = CharacterSet.whitespacesAndNewlines

    for component in cookie.components(separatedBy: ";") {
        // Separate pair key=value. Value may contain aditional '=' symbol.
        let name: String
        let value: String
        if let range = component.range(of: "=") {
            name = component[..<range.lowerBound].trimmingCharacters(in: whitespaces)
            value = component[range.upperBound...].trimmingCharacters(in: whitespaces)
        } else {
            name = component.trimmingCharacters(in: whitespaces)
            value = ""
        }

        if isFirstItem && name.isEmpty {
            return nil
        }

        if isFirstItem {
            // Those properties are mandatory
            properties = [
                .name: name,
                .originURL: url,
                .path: "/",
                .value: value,
                .version: 0
            ]
        } else if name.compare(HTTPCookiePropertyKey.expires.rawValue, options: .caseInsensitive) == .orderedSame {
            properties?[.expires] = cookieDateFormatter.date(from: value)
        } else {
            for property: HTTPCookiePropertyKey in [ .domain, .path] {
                if name.compare(property.rawValue, options: .caseInsensitive) == .orderedSame {
                    properties?[property] = value
                }
            }
        }

        isFirstItem = false
    }

    if let properties = properties {
        return HTTPCookie(properties: properties)
    } else {
        return nil
    }
}

func cookieGetter(for provider: CookieStorageProvider) -> (@convention(block) (_: String) -> String) {
    return { [weak provider] (urlString: String) -> String in
        guard let provider = provider else {
            Log.error("Tab has been deallocated")
            return ""
        }

        guard let url = URL(string: urlString) else {
            Log.error("Provided URL string is invalid: \(urlString)")
            return ""
        }

        guard let cookies = provider.cookieStorage?.cookies(for: url) else {
            Log.error("No cookies for url: \(url)")
            return ""
        }

        return cookies.lazy
            .compactMap { cookie in
                if cookie.isHTTPOnly {
                    return nil
                } else {
                    return "\(cookie.name)=\(cookie.value)"
                }
            }
            .joined(separator: "; ")
    }
}

func cookieSetter(for provider: CookieStorageProvider) -> (@convention(block) (_: String, _: String) -> Void) {
    return { [weak provider] (urlString: String, cookie: String) in
        guard let provider = provider else {
            Log.error("Tab has been deallocated")
            return
        }

        guard let url = URL(string: urlString) else {
            Log.error("Provided URL string is invalid: \(urlString)")
            return
        }

        if let cookie = createHTTPCookie(from: url, cookie: cookie) {
            provider.cookieStorage?.setCookie(cookie)
        } else {
            Log.error("Invalid cookie: \(cookie)")
        }
    }
}
