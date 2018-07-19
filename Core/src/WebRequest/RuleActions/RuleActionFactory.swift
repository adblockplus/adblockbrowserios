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

public final class RuleActionFactory: NSObject {
    weak var delegate: NativeActionCommandDelegate?

    public init(commandDelegate: NativeActionCommandDelegate) {
        self.delegate = commandDelegate
    }

    @objc
    public func ruleActionWithProperties(_ properties: [AnyHashable: Any], originExtension: BrowserExtension) -> AbstractRuleAction? {
        guard let instanceType = properties["instanceType"] as? String,
            let actionClass = actionMapping[instanceType],
            let eventDispatcher = delegate?.eventDispatcher else {
                return nil
        }

        let action = actionClass.init(eventDispatcher: eventDispatcher)

        if let configurable = action as? RuleActionConfigurable {
            configurable.configureWithProperties(properties)
        }

        return action
    }

    /// mapping of instanceType string (from declarativeWebRequest object factory) to native enum
    fileprivate let actionMapping: [String: AbstractRuleAction.Type] = [
        "declarativeWebRequest.CancelRequest": RuleActionCancelRequest.self,
        "declarativeWebRequest.RedirectRequest": RuleActionRedirectRequest.self,
        "declarativeWebRequest.RedirectToEmptyDocument": RuleActionRedirectToEmptyDocument.self,
        "declarativeWebRequest.SendMessageToExtension": RuleActionSendMessageToExtension.self,
        "webRequest.onBeforeRequest": RuleActionOnBeforeRequest.self,
        "webRequest.onBeforeSendHeaders": RuleActionOnBeforeSendHeaders.self,
        "webRequest.onHeadersReceived": RuleActionOnHeadersReceived.self
    ]
}
