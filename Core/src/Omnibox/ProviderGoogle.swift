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

public final class ProviderGoogle: AbstractSuggestionProvider, SearchServiceProviderProtocol {
    override func findingImpl(_ query: String) {
        let jsonFormat = "firefox"
        let query = query.stringByEncodingToURLSafeFormat() ?? ""
        let urlString = String(format: "http://google.com/complete/search?%@output=%@&q=%@",
                               super.extraQueryStringPrependable(true),
                               jsonFormat, query)

        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)

            // A request without well known UA will result in scarily unpredictable and
            // downright wrong results from Google. I'm retaining the incremental research
            // below for future reference.
            request.setValue(Settings.defaultWebViewUserAgent(), forHTTPHeaderField: "User-Agent")

            start(request: request)
        } else {
            foundSuggestions([])
        }
    }

    // MARK: - SearchServiceProviderProtocol

    @objc public var sessionManager = SessionManager.defaultSessionManager
    var data = SearchServiceProviderData()

    func suggestionsFrom(_ jsonString: String) -> SearchServiceProviderParsingResult {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: jsonString, options: JSONSerialization.ReadingOptions())
        } catch let error {
            return .error(error)
        }

        if let rootArray = root as? [Any] {
            for rootElement in rootArray {
                if let resultArray = rootElement as? [String] {
                    return .suggestions(resultArray.map({ OmniboxSuggestion(phrase: $0, rank: 0) }))
                }
            }
        }

        return .unknownFormat
    }
}
