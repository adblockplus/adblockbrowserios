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

private let findResultsLimit = 3

public final class ProviderHistory: AbstractSuggestionProvider {
    public weak var historyManager: BrowserHistoryManager?

    public override init(id aId: UInt, delegate: SuggestionProviderDelegate) {
        super.init(id: aId, delegate: delegate)
    }

    override func findingImpl(_ query: String) {
        if !onFindingFinishValidateQuery() {
            return
        }

        if let results = historyManager?.omniboxHistoryFindPhrase(containing: query, limit: findResultsLimit) {
            let returnObjects = results.compactMap { result -> OmniboxSuggestion? in
                if let phrase = result.phrase {
                    return OmniboxSuggestion(phrase: phrase, rank: Int(result.rank))
                } else {
                    return nil
                }
            }
            foundSuggestions(returnObjects)
        } else {
            foundSuggestions([])
        }
    }

    // MARK: - OmniboxDataSource interface

    public func onTextSubmitted(_ text: String) {
        createOrUpdatePhrase(text)
    }

    public func onURLSubmitted(url: NSURL) {
        createOrUpdatePhrase(url.absoluteString!)
    }

    func createOrUpdatePhrase(_ phrase: String) {
        historyManager?.omniboxHistoryUpdatePhrase(phrase)
    }
}
