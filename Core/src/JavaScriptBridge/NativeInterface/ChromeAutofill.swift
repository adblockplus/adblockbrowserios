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
import UIKit

struct ChromeAutofillFactory: StandardHandlerFactory {
    typealias Handler = ChromeAutofill

    let bridgeContext: JSBridgeContext
}

struct KeyboardSuggestionsProperties: JSObjectConvertibleParameter {
    var suggestions: [String]?

    init?(object: [AnyHashable: Any]) {
        suggestions = object["suggestions"] as? [String]
    }
}

struct ExtractedFormsProperty: JSObjectConvertibleParameter {
    let extractedForms: [Any]

    init?(object: [AnyHashable: Any]) {
        guard let uwForms = object["forms"] as? [Any] else {
            return nil
        }
        extractedForms = uwForms
    }
}

protocol ChromeAutofillProtocol {
    // MARK: - JS Interface
    func setKeyboardInputSuggestions(_ properties: KeyboardSuggestionsProperties) throws -> Any?
    func clearKeyboardInputSuggestions() throws -> Any?
    func requestAutofillValues(_ forms: ExtractedFormsProperty, _ completion: StandardCompletion?) throws
}

struct ChromeAutofill: StandardHandler, MessageDispatcher {
    let context: CommandDispatcherContext
    let bridgeContext: JSBridgeContext
    var chrome: Chrome {
        return context.chrome
    }

}

func newAutofillForms(_ formsProperty: ExtractedFormsProperty) -> [Any] {
    let formAutofiller = FormAutofiller(regexConstants: AutofillRegexConstants())

    let extractedForms = formsProperty.extractedForms
    var autofilledForms = [Any]()
    for extractedForm in extractedForms {
        if let form = extractedForm as? [String: Any], let filledForm = formAutofiller.fill(form) {
            autofilledForms.append(filledForm)
        }
    }
    return autofilledForms
}

extension ChromeAutofill: ChromeAutofillProtocol {
    func setKeyboardInputSuggestions(_ properties: KeyboardSuggestionsProperties) throws -> Any? {
        if let suggestions = properties.suggestions {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "setKeyboardInputSuggestions"), object: suggestions)
        }
        return nil
    }

    func clearKeyboardInputSuggestions() throws -> Any? {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "clearKeyboardInputSuggestions"), object: nil)
        return nil
    }

    func requestAutofillValues(_ formsProperty: ExtractedFormsProperty, _ completion: StandardCompletion?) throws {
        let wrappedForms = ["forms": newAutofillForms(formsProperty)]

        // no dispatch construct?
        completion?(.success(wrappedForms))

    }

}

func registerChromeAutofillHandlers<F>(_ dispatcher: CommandDispatcher,
                                       withFactory factory: F) where F: HandlerFactory, F.Handler: ChromeAutofillProtocol {
    typealias Handler = F.Handler
    dispatcher.register(factory, handler: Handler.setKeyboardInputSuggestions, forName: "autofill.setKeyboardInputSuggestions")
    dispatcher.register(factory, handler: Handler.clearKeyboardInputSuggestions, forName: "autofill.clearKeyboardInputSuggestions")
    dispatcher.register(factory, handler: Handler.requestAutofillValues, forName: "autofill.requestAutofillValues")
}
