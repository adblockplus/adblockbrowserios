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

final class TopSettingsViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents
    let extensionFacade: ABPExtensionFacadeProtocol
    let historyManager: BrowserHistoryManager
    var searchEngine: SearchEngineProtocol?

    weak var browserControlDelegate: BrowserControlDelegate?

    init(components: ControllerComponents) {
        self.components = components
        self.extensionFacade = components.extensionFacade
        self.historyManager = components.historyManager
        self.searchEngine = UserDefaults.standard.selectedSearchEngine()

        self.browserControlDelegate = components.browserController
    }
}
