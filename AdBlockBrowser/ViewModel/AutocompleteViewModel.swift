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

final class AutocompleteViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents
    let autocompleteDataSource: OmniboxDataSource

    init(components: ControllerComponents) {
        self.components = components
        self.autocompleteDataSource = components.autocompleteDataSource
        updateProviders()
    }

    func updateProviders() {
        let defaults = UserDefaults.standard

        let enabled = defaults.bool(forKey: defaultsKeyAutocomplete)
        let selectedEngine = defaults.selectedSearchEngine()

        if let providers = autocompleteDataSource.installedProviders() as? [NSNumber] {
            for provider in providers {
                if let engine = searchEngineFromProvider(provider.uint32Value) {
                    let enabled = enabled && engine === selectedEngine
                    let type = SuggestionProviderType(provider.uint32Value)
                    autocompleteDataSource.setProviderType(type, enabled: enabled)
                }
            }
        }
    }
}
