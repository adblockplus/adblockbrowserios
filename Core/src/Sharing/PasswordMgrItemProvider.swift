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

/*
 A workaround for an unfortunate iOS sharing extension misdesign. If the extension coder uses just
 the officially suggested format of NSExtensionActivationRule and does not take the extra complicated
 effort of configuring a proper predicate, the particular extension will appear in the sharing dialog
 if and only if the array of item providers contains EXACTLY THE EXPECTED ITEMS AND NOTHING ELSE.
 
 Specific example: if the extension expresses an interest in URLs by declaring
 NSExtensionActivationSupportsWebURLWithMaxCount and the app provides URL and also an image, the
 extension does not show up.
 
 In our specific case, we are sending URL to everyone and also would like to send a special item
 to a password manager extension. When both are sent to the sharing controller, the extensions which
 do not understand the password manager item do not show up. Unfortunately it's also high profile
 extensions like Twitter or Facebook.
 
 The solution is done in two places:
 
 1. the app must declare "Imported UTI" which is equal to the password manager item identifier
 "org.appextension.fill-browser-action", and declare it as conformant to "public.url". When the
 password manager is installed, it does export such UTI declaration and exports take over imports,
 but the import is needed for cases when the password manager is NOT installed. The sharing controller
 simply needs to know that our special item can pose as an URL.
 
 2. when constructing the sharing controller, the activity items must contain EITHER a plain URL OR
 this special item, BUT NOT BOTH. Password manager may be able to handle the duplication (OnePasswordExtension does),
 but namely Twitter, Facebook, Notes and Reminders will be missing - most probably because it uses
 a naive NSExtensionActivationSupportsWebURLWithMaxCount = 1 predicate.
 
 This item provider will then make sure that it serves the password manager item only to the relevant
 extensions, and plain URL to everyone else. The item identifier is forced to the UTI declared in
 step 1, because it now covers public.url too.
 */

open class PasswordMgrItemProvider: UIActivityItemProvider {
    fileprivate let webView: UIWebView
    fileprivate let defaultProvider: UIActivityItemProvider
    fileprivate var extensionItem: NSExtensionItem?
    fileprivate static let extensionInstance = OnePasswordExtension.shared()

    open static func isPasswordMgrAvailable() -> Bool {
        return extensionInstance.isAppExtensionAvailable()
    }

    fileprivate static func isPasswordMgrActivityType(_ activityType: String?) -> Bool {
        guard PasswordMgrItemProvider.isPasswordMgrAvailable() else {
            return false
        }
        return
            extensionInstance.isOnePasswordExtensionActivityType(activityType) ||
                (activityType == "com.lastpass.ilastpass.LastPassExt")
        // Add more non matching activity types here
    }

    // Factory pattern to encapsulate the asynchronous design of OnePassword extension item creation
    open static func create( _ forWebView: UIWebView,
                             defaultProvider: UIActivityItemProvider,
                             completionHandler:@escaping (PasswordMgrItemProvider?, Error?) -> Void ) {
        let instance = PasswordMgrItemProvider(webView: forWebView, defaultProvider: defaultProvider)
        extensionInstance.createExtensionItem(forWebView: forWebView, completion: { extensionItem, error -> Void in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            instance.extensionItem = extensionItem
            completionHandler(instance, error)
        })
    }

    fileprivate init(webView: UIWebView, defaultProvider: UIActivityItemProvider) {
        self.webView = webView
        self.defaultProvider = defaultProvider
        super.init(placeholderItem: defaultProvider.placeholderItem ?? NSNull())
    }

    open override var item: Any {
        if PasswordMgrItemProvider.isPasswordMgrActivityType(activityType.map { $0.rawValue }) {
            return extensionItem ?? NSNull()
        } else {
            return defaultProvider.item
        }
    }

    open override func activityViewController(_ activityViewController: UIActivityViewController,
                                              dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        // the data type is preferably taken programmatically from the created extension item, in case
        // the extension internal constants get changed. But as we can't distinguish which particular
        // item provider and registered type is the right one, it can be used only if there is only
        // one of each. Which is the current OnePassword design.
        if let itemProviders = extensionItem?.attachments as? [NSItemProvider], itemProviders.count == 1 {
            let types = itemProviders[0].registeredTypeIdentifiers
            if types.count == 1 {
                return types[0]
            }
        }
        // Fall back to the currently known kUTTypeAppExtensionFillBrowserAction
        return "org.appextension.fill-browser-action"
    }

    open override func activityViewController(_ activityViewController: UIActivityViewController,
                                              subjectForActivityType activityType: UIActivityType?) -> String {
        if PasswordMgrItemProvider.isPasswordMgrActivityType(activityType.map { $0.rawValue }) {
            return ""
        } else {
            return defaultProvider.activityViewController(activityViewController, subjectForActivityType: activityType)
        }
    }

    // SharingIntentFactory integration

    open func matches(_ selectedActivity: String) -> Bool {
        return PasswordMgrItemProvider.isPasswordMgrActivityType(selectedActivity)
    }

    open func handles(_ selectedActivity: String, items: [AnyObject]?) {
        PasswordMgrItemProvider.extensionInstance.fillReturnedItems(items, intoWebView: webView, completion: nil)
    }

}
