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

/// All contexts which may provide an injectable content
/// (script, series of scripts, html page)
@objc
public enum ManifestContextRunnable: Int {
    case background
    case content
    case browserAction
    case pageAction
}

/// All contexts which may provide an icon
@objc
public enum ManifestContextIcon: Int {
    case wholeExtension
    case browserAction
    case pageAction
}

/**
 Manifest is meant to be encapsulated in BrowserExtension and interpreted through
 its interface (concatenated script contents instead of filenames, ready made images
 instead of filenames, etc.). Certain manifest values however are meaningful directly
 and BrowserExtension getters would be just a thin redundant forwarding layer.
 */
public final class Manifest: NSObject {
    public let manifest: [AnyHashable: Any]
    @objc public let name: String
    // This is a *description*, but NSObject already declares one
    public let manifestDescription: String?
    public let version: String
    public let author: String?
    public let defaultLocale: String

    public let contentScripts: [ContentScript]

    private let background: [AnyHashable: Any]?
    private let browserAction: [AnyHashable: Any]?
    private let pageAction: [AnyHashable: Any]?

    public override init() {
        manifest = [:]
        name = kGlobalScopeExtId
        manifestDescription = nil
        version = "1.0.0"
        author = nil
        defaultLocale = "en"
        contentScripts = []
        background = nil
        browserAction = nil
        pageAction = nil
        super.init()
    }

    public init(json: Any?) throws {
        manifest = try parse(json)
        name = try parse(manifest["name"])
        manifestDescription = try parse(manifest["description"], defaultValue: nil)
        version = try parse(manifest["version"])
        author = try parse(manifest["author"], defaultValue: nil)
        defaultLocale = try parse(manifest["default_locale"], defaultValue: "en")

        contentScripts = try (parse(manifest["content_scripts"], defaultValue: []) as [Any]).map { json in
            return try ContentScript(json: json)
        }

        background = try parse(manifest["background"], defaultValue: nil)
        browserAction = try parse(manifest["browser_action"], defaultValue: nil)
        pageAction = try parse(manifest["page_action"], defaultValue: nil)
        super.init()
    }

    @objc
    public convenience init(data: Data) throws {
        try self.init(json: try JSONSerialization.jsonObject(with: data, options: []))
    }

    /// Somewhat unsystematic, but per Chrome manifest document, all possible
    /// elements of browser_action are optional, so we can't catch on any of the above
    /// common elements (neither scripts nor icons)
    public func hasDefinedBrowserAction() -> Bool {
        return browserAction != nil
    }

    /// Keys are pixel sizes, values are bundle-relative paths.
    /// - Remark: no particular ordering (it's a dictionary)
    /// - Todo: convert to NSArray preordered by pixel size, to simplify size matching
    /// - Returns: Dictionary of all defined icons for the given context.
    public func iconPaths(for context: ManifestContextIcon) -> [AnyHashable: Any]? {
        let iconPaths: Any?
        switch context {
        case .wholeExtension:
            iconPaths = manifest["icons"]
        case .pageAction:
            iconPaths = (manifest["page_action"] as? [AnyHashable: Any])?["default_icon"]
        case .browserAction:
            iconPaths = (manifest["browser_action"] as? [AnyHashable: Any])?["default_icon"]
        }

        if let iconPath = iconPaths as? String {
            // "old syntax for registering the default icon"
            // https://developer.chrome.com/extensions/browserAction
            return ["38": iconPath]
        } else {
            return iconPaths as? [AnyHashable: Any]
        }
    }

    public func backgroundFilenames() -> [String]? {
        return background?["scripts"] as? [String]
    }

    public func browserActionFilename() -> String? {
        return browserAction?["default_popup"] as? String
    }

    public func pageActionFilename() -> String? {
        return pageAction?["default_popup"] as? String
    }
}

func parse<T>(_ value: Any?, defaultValue: T) throws -> T {
    if let value = value {
        return try parse(value)
    } else {
        return defaultValue
    }
}

func parse<T>(_ value: Any?) throws -> T {
    if let value = value as? T {
        return value
    } else {
        throw NSError()
    }
}
