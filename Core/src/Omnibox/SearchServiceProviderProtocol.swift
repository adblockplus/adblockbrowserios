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

enum SearchServiceProviderParsingResult {
    case suggestions([OmniboxSuggestion])
    case error(Error)
    case unknownFormat
}

protocol SearchServiceProviderProtocol: class {
    var sessionManager: SessionManager { get set }

    var data: SearchServiceProviderData { get }

    func suggestionsFrom(_ jsonText: String) -> SearchServiceProviderParsingResult

    func foundSuggestions(_ suggestions: [OmniboxSuggestion])

    func onFindingFinishValidateQuery() -> Bool
}

extension SearchServiceProviderProtocol {
    func start(request: URLRequest) {
        if let dataTask = data.dataTask {
            sessionManager.cancelDataTask(dataTask)
        }
        data.delegate = self
        data.dataTask = sessionManager.startDataTask(request, withDelegate: data)
    }

    func sendErrorSuggestionWithFormat(_ format: String, arguments: CVarArg...) {
        let format = bundleLocalizedString("Error: ", comment: "Google autocomplete error") + format

        let phrase = String(format: format, arguments: arguments)

        foundSuggestions([OmniboxSuggestion(phrase: phrase, rank: Int.max)])
    }

    func handleCompletion(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        if !onFindingFinishValidateQuery() {
            // there is newer query, data is obsolete
            return
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            sendErrorSuggestionWithFormat(bundleLocalizedString("response code %d", comment: "Google autocomplete error"), arguments: statusCode)
            return
        }

        guard let data = data, data.count != 0 else {
            sendErrorSuggestionWithFormat(bundleLocalizedString("no data returned", comment: "Google autocomplete error"))
            return
        }

        var cfEncodingEnum = kCFStringEncodingInvalidId
        let encodingStr = httpResponse.textEncodingName
        if encodingStr != nil {
            cfEncodingEnum = CFStringConvertIANACharSetNameToEncoding(encodingStr as CFString!)
        }
        var encodingEnum = String.Encoding.utf8
        if cfEncodingEnum != kCFStringEncodingInvalidId {
            encodingEnum = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncodingEnum))
        }
        guard let jsonString = NSString(data: data, encoding: encodingEnum.rawValue) as String? else {
            sendErrorSuggestionWithFormat(bundleLocalizedString("response non-decodable", comment: "Google autocomplete error"))
            return
        }

        switch suggestionsFrom(jsonString) {
        case .suggestions(let suggestions):
            foundSuggestions(suggestions)
        case .error(let error):
            sendErrorSuggestionWithFormat(bundleLocalizedString("response parsing %@",
                                                                comment: "Google autocomplete error"),
                                          arguments: error.localizedDescription)
        case .unknownFormat:
            sendErrorSuggestionWithFormat(bundleLocalizedString("response format unrecognized", comment: "Google autocomplete error"))
        }
    }
}

class SearchServiceProviderData: NSObject, URLSessionDataDelegate {
    fileprivate weak var delegate: SearchServiceProviderProtocol?
    fileprivate weak var dataTask: URLSessionDataTask?
    fileprivate var data: Data?

    // MARK: - NSURLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.data = data
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        delegate?.handleCompletion(data, task.response, error)
    }
}
