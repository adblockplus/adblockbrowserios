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

final class SubscriptionsViewModel: ViewModelProtocol, ComponentsInitializable {
    let components: ControllerComponents
    let extensionFacade: ABPExtensionFacadeProtocol
    var activeSubscriptions = [AvailableSubscription]()
    var subscriptions = [AvailableSubscription]()

    /// dictionary for maintaing original order
    var positions = [AvailableSubscription: Int]()
    var isLoading = true

    init(components: ControllerComponents) {
        self.components = components
        self.extensionFacade = components.extensionFacade
    }

    func count(`for` section: Int) -> Int {
        return section == 0 ? activeSubscriptions.count : subscriptions.count
    }

    func subscription(`for` indexPath: IndexPath) -> AvailableSubscription {
        return (indexPath.section == 0 ? activeSubscriptions : subscriptions)[indexPath.row]
    }

    func addOrRemoveSubscription(`for` indexPath: IndexPath) -> IndexPath {
        if indexPath.section == 0 {
            extensionFacade.removeSubscription(activeSubscriptions[indexPath.row])
            return move(itemAt: indexPath, from: &activeSubscriptions, to: &subscriptions)
        } else {
            extensionFacade.addSubscription(subscriptions[indexPath.row])
            return move(itemAt: indexPath, from: &subscriptions, to: &activeSubscriptions)
        }
    }

    // MARK: - Private

    ///Moves item from/to list of active subscriptions
    private func move(itemAt indexPath: IndexPath,
                      from fromSubscriptions: inout [AvailableSubscription],
                      to toSubscriptions: inout [AvailableSubscription]) -> IndexPath {
        let subscription = fromSubscriptions[indexPath.row]
        fromSubscriptions.remove(at: indexPath.row)

        let index = findPosition(toSubscriptions, subscription: subscription)
        toSubscriptions.insert(subscription, at: index)

        return IndexPath(row: index, section: indexPath.section == 0 ? 1 : 0)
    }

    private func findPosition(_ subscriptions: [AvailableSubscription], subscription: AvailableSubscription) -> Int {
        let position = positions[subscription] ?? -1
        for (index, sub) in subscriptions.enumerated() where position <= (positions[sub] ?? -1) {
            return index
        }
        return subscriptions.count
    }
}
