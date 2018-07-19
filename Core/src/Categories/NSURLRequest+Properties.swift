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

/*
 WARNING: NSURLProtocol.setProperty:forKey must have only NSCoding-compliant object as value
 OK: String, Boolean, Number NOT OK: NSURL
 Resulting runtime error:
 createEncodedCachedResponseAndRequestForXPCTransmission - Invalid protocol-property list - CFURLRequestRef
 */

public extension URLRequest {
    private mutating func set(_ value: Any?, forKey key: String) {
        // swiftlint:disable:next force_cast
        let request = (self as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        if let value = value {
            URLProtocol.setProperty(value, forKey: key, in: request)
        } else {
            URLProtocol.removeProperty(forKey: key, in: request)
        }
        self = request as URLRequest
    }

    public var originalURL: URL? {
        get {
            if let urlString = URLProtocol.property(forKey: originalURLKey, in: self) as? String {
                return URL(string: urlString)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.absoluteString, forKey: originalURLKey)
        }
    }

    public var passedProtocolHandler: Bool {
        get {
            return URLProtocol.property(forKey: passedProtocolHandlerKey, in: self) != nil
        }
        set {
            set(newValue, forKey: passedProtocolHandlerKey)
        }
    }

    var passedURLProtocolWithSession: Bool {
        get {
            return URLProtocol.property(forKey: passedKey, in: self) != nil
        }
        set {
            set(newValue, forKey: passedKey)
        }
    }

    public var parentFrameURLString: String? {
        if let referrer = value(forHTTPHeaderField: "Referer"), !referrer.isEmpty {
            return referrer
        }
        return nil
    }
}

public extension NSURLRequest {
    @objc public var originalURL: URL? {
        if let urlString = URLProtocol.property(forKey: originalURLKey, in: self as URLRequest) as? String {
            return URL(string: urlString)
        }
        return nil
    }

    @objc public var passedProtocolHandler: Bool {
        return URLProtocol.property(forKey: passedProtocolHandlerKey, in: self as URLRequest) != nil
    }

    public var parentFrameURLString: String? {
        if let referrer = value(forHTTPHeaderField: "Referer"), !referrer.isEmpty {
            return referrer
        }
        return nil
    }
}

extension NSMutableURLRequest {
    public override var passedProtocolHandler: Bool {
        set (enabled) {
            if enabled {
                URLProtocol.setProperty(true, forKey: passedProtocolHandlerKey, in: self)
            } else {
                URLProtocol.removeProperty(forKey: passedProtocolHandlerKey, in: self)
            }
        }
        get {
            return super.passedProtocolHandler
        }
    }
}

private var originalURLKey = "OriginalURLKey"
private var passedProtocolHandlerKey = "PassedProtocolHandlerKey"
private let passedKey = "URLProtocolWithSession"
