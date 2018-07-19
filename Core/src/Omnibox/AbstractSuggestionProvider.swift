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

open class AbstractSuggestionProvider: NSObject {
    /// read only accessor to provider id set in constructor
    @objc open var providerId: UInt
    /// Enabled upon construction, will ignore startFindingForQuery if disabled
    @objc open var enabled: Bool
    /// will be appended as &key=value to the provider GET request
    open var extraQueryParameters: [String: String] {
        didSet {
            extraQueryString = extraQueryParameters.reduce("", { string, parameter  in
                let key = parameter.0.stringByEncodingToURLSafeFormat() ?? ""
                let value = parameter.1.stringByEncodingToURLSafeFormat() ?? ""
                if string.isEmpty {
                    return "\(key)=\(value)"
                } else {
                    return "\(string)&\(key)=\(value)"
                }
            })
        }
    }

    // swiftlint:disable:next weak_delegate
    var delegate: SuggestionProviderDelegate
    /// last stable query string, which will be used by next future request
    var lastQuery: String // atomic
    /// query has changed while a current request was still running
    var lastQueryChanged: Bool// atomic
    /// request is currently running
    var isRequestRunning: Bool // atomic
    /// computed upon setting extraQueryParameters
    var extraQueryString: String

    /// - Parameters:
    ///   - aId: aId provider identification, returned in Suggestion objects
    ///   - delegate: delegate see above
    public init(id aId: UInt, delegate: SuggestionProviderDelegate) {
        self.providerId = aId
        self.delegate = delegate
        self.enabled = true
        self.extraQueryString = ""
        self.extraQueryParameters = [:]
        self.lastQueryChanged = false
        self.isRequestRunning = false
        self.lastQuery = ""
        super.init()
    }

    func onFindingFinishValidateQuery() -> Bool {
        isRequestRunning = false
        // request is completed now
        if lastQueryChanged {
            // Query string has changed meanwhile, the data we got now are obsolete.
            // Clear the flag and dispatch running ourselves immediately again
            // with the new query
            lastQueryChanged = false
            DispatchQueue.main.async(execute: {() -> Void in
                self.findingImpl(self.lastQuery)
            })
            return false
        }
        return true
    }

    /// To be called when async searching in provider is finished
    /// before going on to parsing the response. Checks whether the query which
    /// originated the last call is still valid
    ///
    /// - return: true query is valid, go on
    /// - return: false parsing should NOT continue, search will be restarted
    @objc
    open func startAsyncFindingForQuery(_ query: String) {
        if !enabled {
            return
        }
        // save away the last stable query string
        lastQuery = query
        if isRequestRunning {
            // request is still running, do nothing now and leave it upon
            // finished request
            lastQueryChanged = true
            return
        }
        // fulfill the contract of starting asynchronously
        DispatchQueue.main.async(execute: {() -> Void in
            self.findingImpl(self.lastQuery)
        })
    }

    /// To be called with array of resulting Suggestion objects
    func foundSuggestions(_ suggestions: [OmniboxSuggestion]) {
        // fill in our provider id so that delegate can distinguish
        for suggestion in suggestions {
            suggestion.providerId = providerId
        }
        delegate.provider(self, suggestionsReady: suggestions)
    }

    /// protected abstract, no way to tell in ObjC
    /// the actual provider-specific implementation of search
    /// inside calls the protected methods above
    func findingImpl(_ query: String) {
        // NSException.raise(NSInternalInconsistencyException, format: "You must override findingImpl in a subclass", arguments: NSObject())
    }

    /// - Parameter prependable: true will have "&" at the end, false will have "&" at beginning.
    /// - Returns: constructed extra query string
    func extraQueryStringPrependable(_ prependable: Bool) -> String {
        if extraQueryString.isEmpty {
            return ""
        } else {
            return "\(!prependable ? "&" : "")\(extraQueryString)\(prependable ? "&" : "")"
        }
    }
}
