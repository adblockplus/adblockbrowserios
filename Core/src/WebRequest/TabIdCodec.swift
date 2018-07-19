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

@objc
open class TabIdCodec: NSObject {
    /// regex to parse the tab id out of user-agent
    /// The form is: Version/iOSMajorVersion.AppVersion.TabId
    /// The last number is the wanted tab id and is match group 2
    fileprivate static let VersionDecodingFormat = "Version/[0-9]+\\.([0-9.]+?)\\.([0-9]+)(\\s|$)"
    fileprivate static let VersionEncodingFormat = "Version/%@.%@.%@"

    /**
     The "Version" token was originally configurable so that it could be branded,
     but Google Recaptcha was found to be extremely sensitive to the User-Agent header content.
     Specifically when there is "Safari/" in UA, it wants to have "Version/" too,
     so Kitt is pretty much fixed to it.
     */
    static let rexHeaderValueMatch = try? NSRegularExpression(pattern: VersionDecodingFormat,
                                                              options: NSRegularExpression.Options())

    fileprivate static let UserAgentEncodingPattern = { (encodingFormat: String) -> String in
        let iOSMajorVersion = UIDevice.current.systemVersion.components(separatedBy: ".")[0]
        let applicationVersion = { () -> String in
            let fullVersion = Settings.applicationVersion()
            if let devbuildExtensionRange = fullVersion?.range(of: "-") {
                // version has the "-branch" suffix, remove it
                return String(fullVersion![..<devbuildExtensionRange.lowerBound])
            }
            return fullVersion!
        }()
        return String(format: VersionEncodingFormat, iOSMajorVersion, applicationVersion, "%lu")
    }(VersionEncodingFormat)

    @objc
    open class func prepareNextWebViewForTabId(_ tabId: UInt) {
        let userAgent = [Settings.defaultWebViewUserAgent(), String(format: UserAgentEncodingPattern, tabId)]
            .joined(separator: " ")

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
    }

    open class func decodeTabIdFromRequest(_ request: URLRequest) -> UInt? {
        let headersKey = "User-Agent"
        guard
            let value = request.value(forHTTPHeaderField: headersKey),
            let match = rexHeaderValueMatch?.firstMatch(in: value,
                                                        options:
                NSRegularExpression.MatchingOptions(),
                                                        range: NSRange(location: 0,
                                                                       length:
                                                            value.count)),
            match.range.length > 0
            else {
                return nil
        }
        let tabIdRange = match.range(at: 2)
        if tabIdRange.length == 0 {
            return nil
        }
        let startIndex = value.index(value.startIndex, offsetBy: tabIdRange.location)
        let endIndex = value.index(startIndex, offsetBy: tabIdRange.length)
        let tabIdStr = value[startIndex..<endIndex]
        return UInt(tabIdStr)
    }
}
