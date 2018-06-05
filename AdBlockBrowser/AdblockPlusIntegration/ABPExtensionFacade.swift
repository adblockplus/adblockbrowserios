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

let keyPathExtensionEnabled = "extensionEnabled"

///
/// Public interface
///
public protocol ABPExtensionFacadeProtocol: class, NSObjectProtocol {
    var extensionEnabled: Bool { get set }

    func getAvailableSubscriptions(_ retvalHandler: @escaping ([AvailableSubscription]?, Error?) -> Void)
    func getListedSubscriptions(_ retvalHandler: @escaping ([String: ListedSubscription]?, Error?) -> Void)
    func subscription(_ subscription: ABPSubscriptionBase, enabled: Bool)
    func addSubscription(_ subscription: ABPSubscriptionBase)
    func removeSubscription(_ subscription: ABPSubscriptionBase)
    func isAcceptableAdsEnabled(_ retvalHandler: @escaping (Bool, Error?) -> Void)
    func setAcceptableAdsEnabled(_ enabled: Bool)
    func isSiteWhitelisted(_ url: String, retvalHandler: @escaping (Bool, Error?) -> Void)
    func whitelistSite(_ url: String, whitelisted: Bool, completion: ((Error?) -> Void)?)
    func whitelistDomain(_ domainName: String, whitelisted: Bool, completion: ((Error?) -> Void)?)
    func getWhitelistedSites(_ retvalHandler: @escaping ([String]?, Error?) -> Void)
    func getExtensionVersion(_ retvalHandler: @escaping (Result<String>) -> Void)
}

public let ABPExtensionName = "adblockplus"

///
/// Implementation of ABPExtensionFacadeProtocol
///
class ABPExtensionFacade: NSObject, ABPExtensionFacadeProtocol {
    fileprivate let extensionName = ABPExtensionName
    fileprivate let adblockPlusApi = "window.AdblockPlusApi"

    fileprivate let model: BrowserStateModel
    fileprivate let bundleUnpacker: ExtensionUnpacker

    let backgroundContext: ExtensionBackgroundContext
    var extensionInstance: BrowserExtension?

    required init(model: BrowserStateModel, unpacker: ExtensionUnpacker, backgroundContext: ExtensionBackgroundContext) {
        self.model = model
        self.bundleUnpacker = unpacker
        self.backgroundContext = backgroundContext
        super.init()
    }

    func load(_ forceReload: Bool = false) {
        do {
            // First the extension must be loaded into memory, without executing any scripts in it, because
            // snippet will be attached
            backgroundContext.skipInitialScriptLoad = true

            let successful = (try? bundleUnpacker.hasExtension(ofId: extensionName)) != nil

            if  successful && !forceReload {
                try model.loadExtensions()
                extensionInstance = model.extension(withId: extensionName)
            } else {
                let path = Bundle.main.path(forResource: extensionName, ofType: "crx")
                let data = try? Data(contentsOf: URL(fileURLWithPath: path!))
                extensionInstance = try model.unpackAndCreateExtension(withId: extensionName, from: data)
                // https://adblockplus.org/development-builds/suppressing-the-first-run-page-on-chrome
                // ^^^ refers to "managed" storage which Kitt doesn't support.
                // "local" must be prefixed with "pref:" (ABP implementation detail)
                try extensionInstance?.storage?.merge(["pref:suppress_first_run_page": "true"])
            }

            // Those keys is supposed to be too large for redundant transfering in JS bridge.
            // This filter will exclude it from onChange events.
            if let filter = try? NSRegularExpression(pattern: "^file:patterns.*\\.ini$", options: []) {
                extensionInstance?.storage?.keyFilter = filter
            }

            // Load all scripts at once, including snippet(s)
            backgroundContext.loadScripts(ofExtensionId: extensionName)

        } catch let error {
            let alert = Utils.alertViewWithError(error, title: "Chrome extension load", delegate: nil)
            alert?.show()
        }
    }

    @objc dynamic var extensionEnabled: Bool {
        get {
            return extensionInstance?.enabled ?? false
        }
        set {
            if (extensionInstance?.enabled ?? false) != newValue {
                extensionInstance?.enabled = newValue
                if newValue {
                    backgroundContext.loadScripts(ofExtensionId: extensionName)
                }
            }
        }
    }

    // MARK: - API

    func isAcceptableAdsEnabled(_ retvalHandler: @escaping (Bool, Error?) -> Void) {
        isFeatureActivated("acceptableAdsEnabled", retvalHandler: retvalHandler)
    }

    func getListedSubscriptions(_ retvalHandler: @escaping ([String: ListedSubscription]?, Error?) -> Void) {
        let script = "listedSubscriptions"
        query(script, retvalHandler: { (results: [String: AnyObject]?, error: Error?) -> Void in
            var subscriptions: [String: ListedSubscription]? = nil
            if let results = results {
                subscriptions = [:]
                results.forEach({ url, subscription -> Void in
                    guard let deserializedSub = ListedSubscription(object: subscription) else {
                        Log.error("Failed deserializing listed subscription \(url)")
                        return
                    }
                    subscriptions?[url] = deserializedSub
                })
            }
            retvalHandler(subscriptions, error)
        })
    }

    func getAvailableSubscriptions(_ retvalHandler: @escaping ([AvailableSubscription]?, Error?) -> Void) {
        let script = "availableSubscriptions"
        query(script, retvalHandler: { (results: [AnyObject]?, error: Error?) -> Void in
            var subscriptions: [AvailableSubscription]? = nil
            if let results = results {
                subscriptions = []
                results.forEach({ subscription -> Void in
                    guard let deserializedSub = AvailableSubscription(object: subscription) else {
                        let subscriptionURL = subscription.value(forKey: "url") as? String ?? "unknown URL"
                        Log.error("Failed deserializing available subscription for \(subscriptionURL)")
                        return
                    }
                    subscriptions?.append(deserializedSub)
                })
            }
            retvalHandler(subscriptions, error)
        })
    }

    func subscription(_ subscription: ABPSubscriptionBase, enabled: Bool) {
        let script = adblockPlusApi + ".enableSubscription('\(subscription.url)', \(enabled))"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName, completionHandler: nil)
    }

    func addSubscription(_ subscription: ABPSubscriptionBase) {
        let script = adblockPlusApi + ".addSubscription('\(subscription.url)', '\(subscription.title)')"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName, completionHandler: nil)
    }

    func removeSubscription(_ subscription: ABPSubscriptionBase) {
        let script = adblockPlusApi + ".removeSubscription('\(subscription.url)')"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName, completionHandler: nil)
    }

    func setAcceptableAdsEnabled(_ enabled: Bool) {
        let script = adblockPlusApi + ".acceptableAdsEnabled = \(enabled)"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName, completionHandler: nil)
    }

    func isSiteWhitelisted(_ url: String, retvalHandler: @escaping (Bool, Error?) -> Void) {
        isFeatureActivated("isSiteWhitelisted('\(url)')", retvalHandler: retvalHandler)
    }

    func whitelistSite(_ url: String, whitelisted: Bool, completion: ((Error?) -> Void)? = nil) {
        let script = adblockPlusApi + ".whitelistSite('\(url)', \(whitelisted))"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName) { _, error in
            completion?(error)
        }
    }

    func whitelistDomain(_ domainName: String, whitelisted: Bool, completion: ((Error?) -> Void)? = nil) {
        let script = adblockPlusApi + ".whitelistSiteByDomain('\(domainName)', \(whitelisted))"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName) { _, error in
            completion?(error)
        }
    }

    func getWhitelistedSites(_ retvalHandler: @escaping ([String]?, Error?) -> Void) {
        let script = "whitelistedSites"
        query(script, retvalHandler: retvalHandler)
    }

    func getExtensionVersion(_ retvalHandler: @escaping (Result<String>) -> Void) {
        let script = adblockPlusApi + ".extensionVersion"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName) {output, error -> Void in

            if let version = output as? String, !version.isEmpty {
                retvalHandler(.success(version))
            } else {
                if let error = error {
                    retvalHandler(.failure(error))
                } else {
                    retvalHandler(.failure(NSError()))
                }
            }
        }
    }

    // MARK: - ExtensionModelEventDelegate

    func onModelExtensionAdded(_ `extension`: BrowserExtension!) {
    }

    // MARK: -

    fileprivate func isFeatureActivated(_ feature: String, retvalHandler: @escaping (Bool, Error?) -> Void) {
        let undefined = "undefined"
        let script = "!!\(adblockPlusApi) ? (\(adblockPlusApi).\(feature) ? 'true' : 'false') : '\(undefined)';"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName) { output, error -> Void in
            if error == nil {
                if let uwOutput = output as? NSString {
                    // Repeat query multiple times, until api is loaded.
                    if uwOutput.isEqual(undefined) {
                        weak var wSelf = self

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            wSelf?.isFeatureActivated(feature, retvalHandler: retvalHandler)
                        }
                        return
                    }

                    retvalHandler(uwOutput.boolValue, nil)
                    return
                }
            }
            retvalHandler(false, error)
        }
    }

    fileprivate func query<T>(_ query: String, retvalHandler: @escaping (T?, Error?) -> Void) {
        let script = "JSON.stringify(\(adblockPlusApi).\(query))"
        backgroundContext.evaluateJavaScript(script, inExtension: extensionName) { output, _ -> Void in
            do {
                if let data = (output as? String)?.data(using: String.Encoding.utf8),
                    let object = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? T {
                    retvalHandler(object, nil)
                } else {
                    retvalHandler(nil, nil)
                }
            } catch let error {
                retvalHandler(nil, error)
            }
        }
    }
}
