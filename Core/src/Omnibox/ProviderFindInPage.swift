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

public final class ProviderFindInPage: AbstractSuggestionProvider {
    let chrome: Chrome?

    public required init(id aId: UInt, delegate: SuggestionProviderDelegate, chrome: Chrome?) {
        self.chrome = chrome
        super.init(id: aId, delegate: delegate)
    }

    override func findingImpl(_ query: String) {
        guard let tab = chrome?.focusedWindow?.activeTab,
            let dispatcher = tab.webView.bridgeSwitchboard?.eventDispatcher,
            let url = tab.URL, !url.shouldBeHidden() else {
                foundSuggestions([])
                return
        }

        dispatcher.countMatches(tab.identifier, phrase: query) {[weak self] _, count in
            self?.foundSuggestions([OmniboxSuggestion(phrase: "\(count)", rank: 0)])
        }
    }
}
