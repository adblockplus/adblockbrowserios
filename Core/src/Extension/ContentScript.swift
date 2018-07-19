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

public final class ContentScript: NSObject {
    @objc public let allFrames: Bool
    public let filenames: [String]
    @objc public let runAt: String
    public let matches: [NSPredicate]
    public let excludeMatches: [NSPredicate]

    init(json: Any?) throws {
        let object = try parse(json) as [AnyHashable: Any]
        allFrames = try parse(object["all_frames"], defaultValue: false)
        filenames = try parse(object["js"], defaultValue: [])
        runAt = try parse(object["run_at"], defaultValue: "document_end")
        matches = try predicates(from: try parse(object["matches"]))
        excludeMatches = try predicates(from: parse(object["exclude_matches"], defaultValue: []))
    }

    @objc
    public func applicableOnContentURL(_ url: URL) -> Bool {
        if excludeMatches.count > 0 {
            for excludeMatch in excludeMatches {
                if excludeMatch.evaluate(with: url.absoluteString) {
                    return false // exclusion match
                }
            }
        }
        // no exclusion match, continue with includes (blacklist-whitelist order)
        if matches.count > 0 {
            for matche in matches {
                if matche.evaluate(with: url.absoluteString) {
                    return true
                }
            }
        }
        return false
    }
}

private func predicates(from patterns: [String]) throws -> [NSPredicate] {
    return try patterns.map { pattern in
        do {
            let regex = try (pattern as NSString).regex(fromChromeGlobPattern: pattern)
            return NSPredicate(format: "SELF MATCHES %@", regex.pattern)
        } catch let error {
            throw Utils.error(forWrappingError: error, message: "Pattern bad format '\(pattern)'")
        }
    }
}
