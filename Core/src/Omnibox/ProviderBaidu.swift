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

public final class ProviderBaidu: AbstractSuggestionProvider, SearchServiceProviderProtocol {
    // 20150907 format is
    // window.baidu.sug({q:"the-original-query",p:<Boolean>,s:["suggestion-1","suggestion-2",...]});
    // If there are no matches, the `s` array is present but empty.
    // It would be much safer to cut out the JSON part and parse it to object but unfortunately
    // this is not a valid JSON. NSJSONSerialization requires string keys. So we must get out the
    // innermost valid entity which is the array of `s` key.
    // The regex dumbly depends on the `s` key being the last in JSON but to get it out of anywhere
    // in the object, we would need a full blown JSON parser, just more tolerant than Cocoa's
    let responseRegex = try? NSRegularExpression(
        pattern: "s\\s?:\\s?(\\[.*?\\])\\s?\\}\\s?\\)\\s?;\\s?$",
        options: NSRegularExpression.Options())
    // Error pointer can be nil because the pattern is constant and verified correct

    override func findingImpl(_ query: String) {
        let newQuery = query.stringByEncodingToURLSafeFormat() ?? ""
        let urlString = String(format: "http://suggestion.baidu.com/su?%@wd=%@",
                               super.extraQueryStringPrependable(true), newQuery)

        if let urlQuery = URL(string: urlString) {
            var request = URLRequest(url: urlQuery)

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
        if let match = responseRegex?.firstMatch(in: jsonString,
                                                 options: NSRegularExpression.MatchingOptions(),
                                                 range: NSRange(location: 0, length: jsonString.count)),
            let matchRange = Range(match.range(at: 1)) {
            // rangeAtIndex is bridged ObjC typeless function so it doesn't know that it operated on a String.
            // Hence the type is Range<Int> but substringWithRange requires Range<String.Index>. Must convert.
            let range = jsonString.index(jsonString.startIndex, offsetBy: matchRange.lowerBound)
                ..< jsonString.index(jsonString.startIndex, offsetBy: matchRange.upperBound)
            let jsonArrayString = String(jsonString[range]) // the array of `s` key

            let rawResult: Any
            do {
                rawResult = try JSONSerialization.jsonObject(with: jsonArrayString, options: JSONSerialization.ReadingOptions())
            } catch let error {
                return .error(error)
            }

            if let resultArray = rawResult as? [Any] {
                if let suggestionStrings = resultArray as? [String] {
                    return .suggestions(suggestionStrings.map({OmniboxSuggestion(phrase: $0, rank: 0)}))
                }
            }
        }
        return .unknownFormat
    }
}
