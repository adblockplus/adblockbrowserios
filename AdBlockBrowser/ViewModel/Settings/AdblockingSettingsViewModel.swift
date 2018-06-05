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
import RxSwift

final class AdblockingSettingsViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents
    let extensionFacade: ABPExtensionFacadeProtocol
    let isAcceptableAdsEnabled = Variable(true)

    var extensionEnabled: Bool {
        get { return extensionFacade.extensionEnabled }
        set { extensionFacade.extensionEnabled = newValue }
    }

    enum SubscriptionStatus {
        case notInstalled
        case installedButDisabled
        case enabled
    }

    var subscriptionsStatus = [ListedSubscription: SubscriptionStatus]()

    init(components: ControllerComponents) {
        self.components = components
        self.extensionFacade = components.extensionFacade

        extensionFacade.isAcceptableAdsEnabled { [weak self] isEnabled, _ in
            self?.isAcceptableAdsEnabled.value = isEnabled
        }
    }

    func update(subscriptions listedSubscriptions: [String: ListedSubscription]) {
        var subscriptionsStatus = [ListedSubscription: SubscriptionStatus]()

        for (_, tuple) in blockingItems {
            let expectedSubscription = tuple.subscription
            var status = SubscriptionStatus.notInstalled
            if let listedSubscription = listedSubscriptions[expectedSubscription.url] {
                status = listedSubscription.disabled ? .installedButDisabled : .enabled
            }
            subscriptionsStatus[expectedSubscription] = status
        }

        self.subscriptionsStatus = subscriptionsStatus
    }
}
