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

@objc public protocol AbstractRuleAction: NSObjectProtocol {
    init(eventDispatcher: EventDispatcher)

    func applyToDetails(_ details: WebRequestDetails,
                        modifyingResponse response: BlockingResponse,
                        completionBlock: (() -> Void)?)
}

@objc public protocol RuleActionConfigurable {
    func configureWithProperties(_ properties: [AnyHashable: Any])
}

/// A superclass for any action which may block its response
open class AbstractRuleActionBlockable: NSObject, AbstractRuleAction, RuleActionConfigurable {
    fileprivate var extraProperties = [String]()
    let eventDispatcher: EventDispatcher

    /**
     listenerCallback set means that the action was created on behalf of conditional listener
     subscription and will try to invoke that one subscription instead of iterating all listeners
     of the applicable type (which would cancel the condition matching done previously).
     Held strongly by BrowserExtension along other unconditional callbacks to simplify listener removal.
     */
    @objc open weak var listenerCallback: BridgeCallback?

    public required init(eventDispatcher: EventDispatcher) {
        self.eventDispatcher = eventDispatcher
    }

    open func applyToDetails(_ details: WebRequestDetails,
                             modifyingResponse response: BlockingResponse,
                             completionBlock: (() -> Void)?) {
    }

    open func configureWithProperties(_ properties: [AnyHashable: Any]) {
        extraProperties = properties["extraInfo"] as? [String] ?? []
    }

    /// ask if there was some property in listener parameter opt_extrainfospec
    func hasExtraProperty(_ property: String) -> Bool {
        return extraProperties.contains { $0 == property }
    }

    open var blockingResponse: Bool {
        return hasExtraProperty("blocking")
    }

    open override var debugDescription: String {
        return blockingResponse ? "blocking" : "noblock"
    }
}
