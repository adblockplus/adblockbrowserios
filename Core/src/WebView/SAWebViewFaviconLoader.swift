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

extension SAWebViewFaviconLoader {
    @objc
    public func verifyFaviconWith(_ currentRequest: URLRequest) {
        assert(Thread.isMainThread)

        if delegate == nil {
            return
        }

        guard let currentURL = currentRequest.url else {
            return
        }

        let currentURLs: [URL]
        if let url = currentRequest.originalURL {
            currentURLs = [currentURL, url]
        } else {
            currentURLs = [currentURL]
        }

        let icon = historyManager()?.faviconFor(urls: currentURLs)

        if icon == nil {
            // no icon yet, look for some
            let loadingQueue = type(of: self).loadingQueue()
            loadingQueue.async {[weak self] in
                loadingQueue.suspend()
                DispatchQueue.main.async {
                    // verify again that there is still no icon
                    if self?.historyManager()?.faviconFor(urls: currentURLs) != nil {
                        // icon has landed meanwhile
                        loadingQueue.resume()
                    } else if let start = self?.startFaviconLoading(with:) {
                        start(currentRequest)
                    } else {
                        loadingQueue.resume()
                    }
                }
            }
        }
    }

    /// [delegate faviconData] will be called when finished
    func load(_ favicons: [FaviconSource], fromRequest currentRequest: URLRequest) {
        guard let currentURL = currentRequest.url else {
            return
        }

        let currentURLs: [URL]
        if let url = currentRequest.originalURL {
            currentURLs = [currentURL, url]
        } else {
            currentURLs = [currentURL]
        }

        let icon = historyManager()?.faviconFor(urls: currentURLs)

        var favicons = favicons

        if let icon = icon, icon.size != 0 {
            favicons = favicons.filter {
                guard let otherSize = icon.size?.int16Value else {
                    return false
                }
                return $0.size > otherSize || $0.type == faviconAppleTouch
            }
        }

        guard favicons.count != 0 else {
            // dispatch to obey the declared asynchronicity
            let delegate = self.delegate
            DispatchQueue.main.async {
                delegate?.setCurrentFavicon(icon)
            }
            return
        }

        favicons.sort { icon1, icon2 in
            let value1 = icon1.type == faviconAppleTouch ? 1 : 0
            let value2 = icon2.type == faviconAppleTouch ? 1 : 0

            if value1 != value2 {
                return value1 > value2
            } else {
                return icon1.size > icon2.size
            }
        }

        let faviconGroup = FaviconGroup(request: currentRequest)

        for favicon in favicons {
            let validatedURLString = type(of: self).urlString(fromValidatedFaviconURL: favicon.url as URL, withCurrentURL: currentURL)
            if let validatedURLString = validatedURLString, let currentFaviconURL = URL(string: validatedURLString) {
                let loadingQueue = type(of: self).loadingQueue()
                loadingQueue.async {[weak self] in
                    self?.startFaviconLoading(from: currentFaviconURL, withSize: UInt(favicon.size), andFaviconGroup: faviconGroup)
                }
            }
        }
    }

    // MARK: Favicon gathering

    // Scenario 1
    @objc
    public func URLFaviconStringFromDOMOfServerURL(_ serverURL: URL) -> String? {
        // Apple specific first, fall back to unspecific
        let urlString: String
        if let url = queryDOMWithAppleSpecific(true) {
            urlString = url
        } else if let url = queryDOMWithAppleSpecific(false) {
            urlString = url
        } else {
            // DOM doesn't specify any icon, bail out
            return nil
        }

        if let url = URL(string: urlString), let currentURL = currentRequest?.url {
            return type(of: self).urlString(fromValidatedFaviconURL: url, withCurrentURL: currentURL)
        } else {
            return nil
        }
    }

    // Scenario 2
    @objc
    public func URLFaviconStringWithDefaultServerURL(_ serverURL: URL) -> String? {
        // NSURL has no way to replace just the path
        // NSURLComponents (aka fully mutable NSURL) is iOS7+
        // So we must reconstruct as string
        if let scheme = serverURL.scheme, let host = serverURL.host {
            return "\(scheme)://\(host)\(optionalFormattedPort(of: serverURL))\(faviconDefaultPath)"
        } else {
            return nil
        }
    }

    // Scenario 3
    @objc
    public func URLFaviconStringWithModifiedServer(_ serverURL: URL) -> String? {
        guard let domainLevels = serverURL.host?.components(separatedBy: "."), domainLevels.count > 1 else {
            // not a regular URL, not a subject for this scenario
            return nil
        }
        guard let scheme = serverURL.scheme else {
            return nil
        }
        return "\(scheme)://www.\(domainLevels[domainLevels.count - 2])"
            + ".\(domainLevels[domainLevels.count - 1])\(optionalFormattedPort(of: serverURL))\(faviconDefaultPath)"
    }

    func queryDOMWithAppleSpecific(_ appleSpecific: Bool) -> String? {
        if let delegate = delegate {
            let selector = appleSpecific ?
                "link[rel='\(faviconAppleTouch)']" :
            "link[rel='shortcut icon'], link[rel='icon']"
            // wrap in IIFE to prevent interaction with global scope
            let query = "(function(){var s=document.querySelector(\"\(selector)\");return s?s.getAttribute('href'):null})();"
            let result = delegate.string(fromEvalJS: query)
            // return nil if JS returned empty string (which equals to "not found")
            return result.isEmpty ? nil : result
        } else {
            return nil
        }
    }

    // NSURL doesn't have a method to obtain complete hostname with port. So if
    // just a partial URL change is needed (like path only), port needs to be
    // reinserted. This function does it in a way that the result can be used
    // unconditionally
    // @return port number prefixed with separator
    // @return empty string if serverURL has no port
    func optionalFormattedPort(of serverURL: URL) -> String
    {
        if let port = serverURL.port {
            return ":\(port)"
        } else {
            return ""
        }
    }
}

private let faviconDefaultPath = "/favicon.ico"

private let faviconAppleTouch = "apple-touch-icon"

open class FaviconGroup: NSObject {
    @objc open let request: URLRequest
    @objc open var favicon: FaviconFacade?

    init(request: URLRequest) {
        self.request = request
    }

    @objc open var resolved: Bool {
        return favicon != nil
    }
}

struct FaviconSource {
    let url: URL
    let type: String?
    let size: Int16

    init?(object: Any) {
        guard let properties = object as? [String: Any] else {
            Log.warn("Unsupported type of properties")
            return nil
        }

        assert(properties.count == 3, "favicon event parameters expected to be array of 3 elements")

        guard let urlString = properties["href"] as? String, let url = URL(string: urlString) else {
            Log.warn("Favicon without URL")
            return nil
        }

        var biggestSize = Int16(0)

        if let sizes = properties["sizes"] as? String, !sizes.isEmpty {
            // http://www.w3.org/html/wg/drafts/html/master/semantics.html#attr-link-sizes
            // The format is "any" or a space-separated list of nonegative integer tuples
            // e.g. "45x45 72x72 120x120"
            for size in sizes.components(separatedBy: CharacterSet.whitespaces) {
                let keyword = size.lowercased()

                if keyword == "any" {
                    biggestSize = Int16.max
                    break
                }

                let dimensions = keyword.components(separatedBy: "x")
                if dimensions.count != 2 {
                    // does not contain 2 tokens separated by "x"
                    continue
                }

                let strDimX = dimensions[0]
                let strDimY = dimensions[1]

                if strDimX.hasPrefix("0") || strDimY.hasPrefix("0") {
                    // the numbers must not start with zero
                    continue
                }

                if let dimX = Int16(strDimX), let dimY = Int16(strDimY) {
                    biggestSize = max(biggestSize, max(dimX, dimY))
                }
            }
        }

        self.url = url
        self.type = properties["rel"] as? String
        self.size = biggestSize
    }
}
