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

@testable import AdblockBrowser
import XCTest

class AdblockPlusTests: XCTestCase {
    let subscriptions: [ListedSubscription] = blockingItems.values.map { $0.subscription }

    var facade: ABPExtensionFacadeProtocol?

    override func setUp() {
        super.setUp()

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let facade = appDelegate?.components?.extensionFacade
        XCTAssert(facade != nil, "Facade has not been found!")
    }

    func testSubscriptionAddingRemoving() {

        // Add subscriptions
        for subscription in subscriptions {
            facade?.addSubscription(subscription)
        }

        facade?.getListedSubscriptions({ listedSubs, error -> Void in
            XCTAssertNil(error, "Calling getListedSubscriptions has failed")
            XCTAssertNotNil(listedSubs, "getListedSubscriptions returned nil data")
            let listedUrls = listedSubs!.keys
            for subscription in self.subscriptions {
                XCTAssert(listedUrls.contains(subscription.url), "Subscription not installed \(subscription.url)")
            }

            // Remove subscriptions
            for subscription in self.subscriptions {
                self.facade?.removeSubscription(subscription)
            }

            self.facade?.getListedSubscriptions({ listedSubs, error -> Void in
                XCTAssertNil(error, "Calling getListedSubscriptions has failed")
                XCTAssertNotNil(listedSubs, "getListedSubscriptions returned nil data")
                let listedUrls = listedSubs!.keys
                for subscription in self.subscriptions {
                    XCTAssertFalse(listedUrls.contains(subscription.url), "Subscription still installed \(subscription.url)")
                }
            })
        })
    }

    func testSubscriptionEnabling() {
        // Add subscriptions
        for subscription in subscriptions {
            facade?.addSubscription(subscription)
        }

        // Enable subscriptions
        for subscription in subscriptions {
            facade?.subscription(subscription, enabled: true)
        }

        facade?.getListedSubscriptions({ listedSubs, error -> Void in
            XCTAssertNil(error, "Calling getListedSubscriptions has failed")
            XCTAssertNotNil(listedSubs, "getListedSubscriptions returned nil data")
            for subscription in self.subscriptions {
                XCTAssertNotNil(listedSubs![subscription.url], "Expected listed subscription \(subscription.url)")
                XCTAssertFalse(listedSubs![subscription.url]?.disabled ?? true, "Subscription not enabled \(subscription.url)")
            }

            // Disable subscriptions
            for subscription in self.subscriptions {
                self.facade?.subscription(subscription, enabled: false)
            }

            self.facade?.getListedSubscriptions({ listedSubs, error -> Void in
                XCTAssertNil(error, "Calling getListedSubscriptions has failed")
                XCTAssertNotNil(listedSubs, "getListedSubscriptions returned nil data")
                for subscription in self.subscriptions {
                    XCTAssertNotNil(listedSubs![subscription.url], "Expected listed subscription \(subscription.url)")
                    XCTAssertTrue(listedSubs![subscription.url]?.disabled ?? false, "Subscription not disabled \(subscription.url)")
                }
            })
        })
    }
}
