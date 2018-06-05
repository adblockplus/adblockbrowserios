// Generated using Sourcery 0.11.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

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

/// API data values are loaded in at build time.
final class ABBAPIData: NSObject {

    /// - Returns: A HockeyApp API Key (for Debug Scheme) or default string ("DEBUG").
    @objc
    class func hockeyAppIdDebug() -> NSString {
        return "DEBUG"
    }

    /// - Returns: A HockeyApp API Key (for DevBuild Scheme) or default string ("DEVBUILD").
    @objc
    class func hockeyAppIdDevBuild() -> NSString {
        return "DEVBUILD"
    }

    /// - Returns: A HockeyApp API Key (for Release Scheme) or default string ("RELEASE").
    @objc
    class func hockeyAppIdRelease() -> NSString {
        return "RELEASE"
    }
}
