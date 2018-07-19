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

struct JSCallbackEventType: JSParameter {
    let eventString: String
    let eventType: CallbackEventType

    init?(json: Any?) {
        guard let name = json as? String else {
            return nil
        }
        eventString = name
        eventType = BridgeCallback.eventTypeForEventString(name)
    }
}

protocol EventListenerStorageProtocol {
    func add(_ eventType: JSCallbackEventType, parameters: JSAny, callbackId: String) throws -> Any?

    func remove(_ callbackId: String) throws -> Any?
}

struct EventListenerStorageFactory: StandardHandlerFactory {
    var bridgeContext: JSBridgeContext

    typealias Handler = EventListenerStorage
}

struct EventListenerStorage: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
}

extension EventListenerStorage: EventListenerStorageProtocol {
    func add(_ event: JSCallbackEventType, parameters: JSAny, callbackId: String) throws -> Any? {
        Log.info("Extension '\(context.`extension`.extensionId)' subscription to event '\(event.eventString)' = \(event.eventType)")

        var callbackContext: [String: Any] = ["callbackId": callbackId, "event": event.eventString]

        if let tabId = context.sourceTab?.identifier {
            callbackContext["tabId"] = tabId
        }

        let callback = BridgeCallback(webView: context.source,
                                      frame: context.sourceFrame,
                                      origin: context.source.origin,
                                      extension: context.`extension`,
                                      event: event.eventType,
                                      callbackId: callbackId,
                                      context: callbackContext)

        switch callback.event {
        case .webRequest_OnBeforeRequest, .webRequest_OnHeadersReceived, .webRequest_OnBeforeSendHeaders, .webRequest_HandlerBehaviorChanged:
            try addWebRequestListener(callback, for: event, parameters: parameters.any)
        case .webNavigation_OnCompleted, .webNavigation_OnBeforeNavigate, .webNavigation_OnCreatedNavTarget, .webNavigation_OnCommitted:
            addWebNavigationListener(callback, for: event, parameters: parameters.any)
        case .fullText_CountMatches, .fullText_MarkMatches, .fullText_MakeCurrent, .fullText_UnmarkMatches:
            let tabId = callback.tabId ?? 0
            context.`extension`.removeContentCallbacks(for: Int(tabId), event: callback.event)
            context.`extension`.add(callback)
        default:
            context.`extension`.add(callback)
        }
        Log.debug("Extension \(context.`extension`.extensionId) added subscription to event '\(event.eventString)' = \(event.eventType)")
        return nil
    }

    func remove(_ callbackId: String) throws -> Any? {
        Log.debug("Remove listener \(callbackId)")
        // Remove request rules before removing the callback object, because the rule
        // holds the callback object weakly.
        WebRequestEventDispatcher.sharedInstance().removeRequestRule(forCallbackId: callbackId)
        context.`extension`.removeCallback(with: callbackId)
        return nil
    }

    // MARK: - Event specific handlers

    fileprivate func addWebNavigationListener(_ callback: BridgeCallback, for event: JSCallbackEventType, parameters: Any?) {
        let `extension` = context.`extension`
        let parameters = parameters as? [AnyHashable: Any]

        // "url: array of events.UrlFilter conditions that the URL being navigated to must satisfy"
        if let urlFilters = parameters?["url"] as? [[AnyHashable: Any]] {
            callback.conditions = urlFilters.map { urlFilter in
                return RuleCondition_UrlFilter(jsConfigObject: urlFilter, for: event.eventType)
            }
        }
        `extension`.add(callback)
    }

    fileprivate func addWebRequestListener(_ callback: BridgeCallback,
                                           for event: JSCallbackEventType,
                                           parameters: Any?) throws {
        let `extension` = context.`extension`
        let parameters = parameters as? [AnyHashable: Any]

        let mainGroup = RuleConditionGroup(groupOperator: .and)
        let stage = event.eventString.components(separatedBy: ".")[1]
        mainGroup.addRuleCondition(RuleCondition_DetailPath(path: "stage", matchingValue: stage))

        guard let factory = context.source.bridgeSwitchboard?.ruleActionFactory else {
            throw NSError(message: "RuleActionFactory cannot be used!")
        }

        let properties: [AnyHashable: Any] = [
            // this instantiation by string key may look strange
            // but it's reusing logic of declarativeWebRequest
            "instanceType": event.eventString,
            "extraInfo": parameters?["extraInfo"] as? [Any] ?? []
        ]

        guard let action = factory.ruleActionWithProperties(properties, originExtension: `extension`) else {
            throw NSError(message: "Action cannot be created")
        }

        let wantsBlocking: Bool

        if let action = action as? AbstractRuleActionBlockable {
            wantsBlocking = action.blockingResponse
        } else {
            wantsBlocking = false
        }

        mainGroup.addRuleCondition(RuleCondition_BlockingResponse(blockingFlag: wantsBlocking))

        var conditions: [RuleConditionMatchable] = [mainGroup]

        let rawFilters = (parameters?["filter"] as? [AnyHashable: Any])?["urls"]

        if let filters = rawFilters as? [String], !filters.isEmpty {
            let group = RuleConditionGroup(groupOperator: .or)
            for globFilter in filters {
                group.addRuleCondition(RuleCondition_ChromeGlob(chromeGlob: globFilter))
            }
            conditions.append(group)
        } else {
            assert(rawFilters == nil, "Unsupported type of blocking url filters")
        }

        let rawTypes = (parameters?["filter"] as? [AnyHashable: Any])?["types"]

        if let filters = rawTypes  as? [String], !filters.isEmpty {
            let group = RuleConditionGroup(groupOperator: .or)
            for type in filters {
                group.addRuleCondition(RuleCondition_DetailPath(path: "resourceTypeString", matchingValue: type))
            }
            conditions.append(group)
        } else {
            assert(rawTypes == nil, "Unsupported type of blocking type filters")
        }

        let rule = RequestRule(conditions: conditions, actions: [action], originExtension: `extension`)
        WebRequestEventDispatcher.sharedInstance().add(rule)

        `extension`.add(callback)
        // weak hold to simplify action execution instead of iterating over all
        // callbacks in BrowserExtension instance
        if let action = action as? AbstractRuleActionBlockable {
            action.listenerCallback = callback
        }
    }
}

func registerEventListenerStorageHandlers<F>(_ dispatcher: CommandDispatcher, withFactory factory: F)
    where F: HandlerFactory, F.Handler: EventListenerStorageProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.add, forName: "listenerStorage.add")
    dispatcher.register(factory, handler: Handler.remove, forName: "listenerStorage.remove")
}
