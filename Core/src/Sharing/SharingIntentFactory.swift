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

/**
 Block based dispatcher for UIActivityViewController.
 
 - adds activities of various types
 - creates the controller instance
 - matches and invokes an assigned handler for the selected activity
 */
open class SharingIntentFactory {
    public typealias ActivityMatcher = (_ selectedActivity: String) -> Bool
    public typealias ActivityHandler = (_ selectedActivity: String, _ items: [AnyObject]?) -> Void

    /// This empty public init enables the class to be initialized when called from outside of the module.
    public init() { }

    fileprivate struct ActivityAdapter {
        let matches: ActivityMatcher
        let handle: ActivityHandler
        var activity: UIActivity?
    }

    fileprivate var adapters = [ActivityAdapter]()

    /// Generic activity with any matcher and any handler
    @discardableResult
    open func add(matcher: @escaping ActivityMatcher, handler: @escaping ActivityHandler, activity: UIActivity?) -> Self {
        adapters.append(ActivityAdapter(
            matches: matcher,
            handle: handler,
            activity: activity
        ))
        return self
    }

    /// standard activity defined by string
    @discardableResult
    open func add(_ activityType: String, handler: @escaping ActivityHandler) -> Self {
        _ = add(
            matcher: { selectedActivity in
                selectedActivity == activityType
        },
            handler: handler,
            activity: nil
        )
        return self
    }

    /// UIActivity implementations
    @discardableResult
    open func add(_ activity: UIActivity, handler: @escaping ActivityHandler) -> Self {
        add(
            matcher: { selectedActivity in
                if let activityType = activity.activityType {
                    return selectedActivity == activityType.rawValue
                } else {
                    return false
                }
        },
            handler: handler,
            activity: activity
        )
        return self
    }

    /// Array of UIActivity implementations with common handler
    @discardableResult
    open func add(_ activities: [UIActivity], handler: @escaping ActivityHandler) -> Self {
        for activity in activities {
            add(activity, handler: handler)
        }
        return self
    }

    /// Convenience for UIActivity where matching and handling is done inside UIActivity
    @discardableResult
    open func add(_ activity: UIActivity) -> Self {
        add(activity, handler: { _, _ -> Void in
        })
        return self
    }

    /// Controller factory with completion activity matching
    open static func makeController(
        _ factory: SharingIntentFactory,
        activityItems: [AnyObject],
        excludedActivities: [UIActivityType]?,
        completion: @escaping (Bool, Error?) -> Void) -> UIActivityViewController {
        let activities = factory.adapters.reduce([UIActivity]()) { result, adapter in
            if let activity = adapter.activity {
                return result + [activity]
            }
            return result
        }
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: activities)
        if let excludedActivities = excludedActivities {
            controller.excludedActivityTypes = excludedActivities
        }
        controller.completionWithItemsHandler = { activityType, completed, items, error -> Void in
            guard completed && error == nil else {
                completion(completed, error)
                return
            }
            if let activityType = activityType {
                for adapter in factory.adapters {
                    if adapter.matches(activityType.rawValue) {
                        adapter.handle(activityType.rawValue, items as [AnyObject]?)
                        break
                    }
                }
            }
            completion(completed, error)
        }
        return controller
    }
}
