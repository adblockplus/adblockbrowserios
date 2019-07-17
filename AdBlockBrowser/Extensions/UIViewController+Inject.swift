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

/**
 Instruments UIViewController hierarchy for propagation of browser components
 through prepareForSegue calls.
 */

import Foundation

protocol ExtensionControlComponents {
    var extensionFacade: ABPExtensionFacadeProtocol { get }
}

struct ControllerComponents: ExtensionControlComponents {
    let bridgeSwitchboard: BridgeSwitchboard
    let browserStateData: BrowserStateCoreData
    let historyManager: BrowserHistoryManager
    let autocompleteDataSource: OmniboxDataSource
    let browserStateModel: BrowserStateModel
    let contextMenuProvider: ContextMenuProvider
    let extensionFacade: ABPExtensionFacadeProtocol
    let ruleActionFactory: RuleActionFactory
    let tabPreviewPersistence: TabPreviewPersistence
    let fulltextSearchObserver: FulltextSearchObserver
    let chrome: Chrome

    // Controllers throughout the app need browserController as dependency, but it's available
    // later than browser assembly, hence var
    // (and weak because the primary strong holder is the storyboard)
    weak var browserController: BrowserContainerViewController? {
        didSet {
            // Legacy dependency hack to be gradually removed.
            // Ideally the assembly is not dependent on BrowserController at all.
            bridgeSwitchboard.browserControlDelegate = browserController
        }
    }
}

protocol ControllerComponentsInjectable {
    var controllerComponents: ControllerComponents? { get set }
}

extension ControllerComponentsInjectable {
    /**
     Meant to be called from prepareForSegue.
     Originally the parameter was UIStoryboardSegue and segue.targetViewController was
     inspected exclusively, but there are other cases like when targetViewController is
     UINavigationController and the actual target is topViewController
     */
    func tryInjectToController(_ controller: UIViewController) {
        if var injectable = controller as? ControllerComponentsInjectable {
            injectable.controllerComponents = self.controllerComponents
        }
    }
}
