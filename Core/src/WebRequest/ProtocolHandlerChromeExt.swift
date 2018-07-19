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

extension ProtocolHandlerChromeExt {
    static let scheme = "chrome-extension"

    /// - Returns: TRUE if the request URL looks like bundle resource URL
    @objc(isBundleResourceURL:)
    public static func isBundleResource(_ url: URL?) -> Bool {
        return url?.scheme == scheme
    }

    /// Convenience wrapper of isBundleResourse()
    @objc(isBundleResourceRequest:)
    public static func isBundleResource(_ request: URLRequest) -> Bool {
        return isBundleResource(request.url)
    }

    @objc(extensionIdOfBundleResourceRequest:)
    public static func extensionId(of request: URLRequest) -> String? {
        return request.url?.host
    }

    /// - Returns: constructed bundle resource URL for given extension and extension-local resource
    @objc(URLforRequestResource:extensionId:)
    public static func url(forRequestResource resourcePath: String, extensionId: String) -> URL? {
        /// scheme://extensionId/resource
        var components = URLComponents()
        components.scheme = scheme
        components.host = extensionId
        components.path = resourcePath.hasPrefix("/") ? resourcePath : "/" + resourcePath
        return components.url
    }
}
