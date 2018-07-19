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

public final class FulltextSearchResults: NSObject, JSObjectConvertibleParameter {
    @objc public let viewport: [Any]
    @objc public let locations: [Any]

    init?(object: [AnyHashable: Any]) {
        guard let uwViewport: JSArray<JSAny> = JSArray(json: object["viewport"]),
            let uwLocations: JSArray<JSAny> = JSArray(json: object["locations"]) else {
                return nil
        }

        viewport = uwViewport.contents.map { $0.any }
        locations = uwLocations.contents.map { $0.any }
    }
}

extension EventDispatcher {
    @objc
    public func countMatches(_ tabId: UInt, phrase: String, completion: @escaping (NSError?, UInt) -> Void) {
        dispatch(.fullText_CountMatches, tabId, ["phrase": phrase]) { (results: [Result<JSArray<UInt>>]) in
            if case .some(.success(let result)) = results.first, let count = result.contents.first {
                completion(nil, count)
            } else {
                completion(NSError(message: "No results"), 0)
            }
        }
    }

    @objc
    public func markMatches(_ tabId: UInt, phrase: String, completion: @escaping (NSError?, FulltextSearchResults?) -> Void) {
        dispatch(.fullText_MarkMatches, tabId, ["phrase": phrase]) { (results: [Result<FulltextSearchResults>]) in
            if case .some(.success(let result)) = results.first {
                completion(nil, result)
            } else {
                completion(NSError(message: "No results"), nil)
            }
        }
    }

    @objc
    public func makeCurrent(_ tabId: UInt, properties: [String: Any], completion: @escaping (NSError?, FulltextSearchResults?) -> Void) {
        dispatch(.fullText_MakeCurrent, tabId, properties) { (results: [Result<FulltextSearchResults>]) in
            if case .some(.success(let result)) = results.first {
                completion(nil, result)
            } else {
                completion(NSError(message: "No results"), nil)
            }
        }
    }

    @objc
    public func unmarkMatches(_ tabId: UInt) {
        let completion: (([Result<JSAny>]) -> Void)? = nil
        dispatch(.fullText_UnmarkMatches, tabId, [:], completion)
    }
}
