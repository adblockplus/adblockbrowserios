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

/// @see http://developer.chrome.com/extensions/webRequest.html#type-BlockingResponse
public final class BlockingResponse: NSObject {
    /// onBeforeRequest
    public var cancel = false
    /// onBeforeRequest, onHeadersReceived
    public var redirectUrl: String?
    /// onBeforeSendHeaders
    public var requestHeaders: [AnyHashable: Any]?
    /// onHeadersReceived
    public var responseHeaders: [AnyHashable: Any]?

    // @todo authCredentials

    // Kitt specific
    // Used in declarativeWebRequest.RedirectToEmptyDocument
    // when local fixed resource is to be served
    public var fakeResponse: URLResponse?
    public var fakeData: Data?
}
