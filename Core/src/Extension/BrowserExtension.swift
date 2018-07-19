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

let kChromeStorageMigratedToFileSystem = "kChromeStorageMigratedToFileSystem"
private let kBrowserAddoniPhoneShareIconHeight = 43
private let kBrowserAddoniPadShareIconHeight = 55

public final class BrowserExtension: NSObject, ChromeStorageMutationDelegate {
    @objc public static let iphoneShareIconHeight = kBrowserAddoniPhoneShareIconHeight
    @objc public static let ipadShareIconHeight = kBrowserAddoniPadShareIconHeight

    private var callbacks: [BridgeCallback] = []

    @objc public let extensionId: String
    @objc public let manifest: Manifest
    public weak var persistence: BrowserStateCoreData?
    public weak var bundle: ExtensionBundleDataSource?
    public weak var commandDelegate: NativeActionCommandDelegate?

    public let translations: Any?
    @objc public let storage: ChromeStorageProtocol?
    @objc public weak var changeDelegate: BrowserExtensionChangeDelegate?

    static let generatedBackgroundPageFilename = "_generated_background_page.html"

    @objc
    public init(extensionId: String,
                manifest: Manifest,
                persistence: BrowserStateCoreData?,
                bundle: ExtensionBundleDataSource?,
                commandDelegate: NativeActionCommandDelegate?) {
        self.extensionId = extensionId
        self.manifest = manifest
        self.persistence = persistence
        self.bundle = bundle
        self.commandDelegate = commandDelegate

        if let data = bundle?.translationsFile(for: extensionId, defaultLocale: manifest.defaultLocale),
            let translations = try? JSONSerialization.jsonObject(with: data, options: []) {
            self.translations = translations
        } else {
            self.translations = nil
        }

        if let persistence = persistence {
            do {
                let storage = try FileSystemChromeStorage(extensionId: extensionId)
                self.storage = storage

                if !UserDefaults.standard.bool(forKey: kChromeStorageMigratedToFileSystem) {
                    let oldStorage = ChromeStorage(extensionId: extensionId, dataSource: persistence)
                    do {
                        try transferValues(from: oldStorage, to: storage)
                        UserDefaults.standard.set(true, forKey: kChromeStorageMigratedToFileSystem)
                        UserDefaults.standard.synchronize()
                        do {
                            try storage.clear()
                        } catch let error {
                            Log.error("Clearing of old storage has failed: \(error.localizedDescription)")
                        }
                    } catch let error {
                        Log.error("Transfer values has failed: \(error.localizedDescription)")
                    }
                }
            } catch let error {
                Log.error("Chrome storage backed by file system was not created: \(error.localizedDescription)")
                self.storage = nil
            }
        } else {
            self.storage = nil
        }

        super.init()
    }

    @objc dynamic public var enabled: Bool {
        get {
            return persistence?.extensionObject(withId: extensionId)?.enabled ?? false
        }
        set {
            if let `extension` = persistence?.extensionObject(withId: self.extensionId) {
                `extension`.enabled = newValue
                persistence?.saveContextWithErrorAlert()
                if let delegate = changeDelegate?.browserExtension {
                    delegate(self, newValue)
                }
            }
        }
    }

    public func generateBackgroundPage() {
        var scriptTags = ""
        for backgroundFilename in manifest.backgroundFilenames() ?? [] {
            scriptTags += "<script type='text/javascript' src='\(backgroundFilename)'></script>\n"
        }

        let contents = "<!DOCTYPE html><html>\n<head><title>\(extensionId)</title>\n\(scriptTags)</head></html>\n"

        guard let bundle = bundle else {
            Log.critical(KittCoreError.generatingBackgroundPage)
            return
        }

        do {
            let filename = BrowserExtension.generatedBackgroundPageFilename
            try bundle.write(contents, toResource: filename, ofExtensionWithId: extensionId)
        } catch _ {
            Log.critical(KittCoreError.generatingBackgroundPage)
        }
    }

    func path(to resource: String) -> String? {
        let path = try? bundle?.path(forExtensionId: extensionId, resource: resource)
        if let uwPath = path {
            return uwPath
        } else {
            return nil
        }
    }

    /// - Parameter resourcePath: bundle-relative path to resource file
    /// - Returns: raw data of the requested resource
    @objc
    public func data(forBundleResource resourcePath: String) throws -> Data {
        return try bundle!.data(ofResource: resourcePath, inExtensionOfId: extensionId)
    }

    /// Detect whether this extension declares runnability in the given context
    public func isRunnable(inContext context: ManifestContextRunnable) -> Bool {
        switch context {
        case .background:
            return manifest.backgroundFilenames()?.count ?? 0 > 0
        case .browserAction:
            // browser action may not define any filenames neither icons and still be
            // runnable for onClick handler
            return manifest.hasDefinedBrowserAction()
        case .content:
            return manifest.contentScripts.first { contentScript in return contentScript.filenames.count > 0 } != nil
        case .pageAction:
            return manifest.pageActionFilename() != nil
        }
    }

    /// - Parameter height: if 0, no resizing will be performed.
    /// - Returns: best image for requested context and height match, resized if necessary.
    @objc  // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func image(forContext context: ManifestContextIcon, withHeight height: CGFloat) throws -> UIImage {
        var context = context
        var iconFilename: String?

        END: do {
            var icons = manifest.iconPaths(for: context) ?? [:]

            // Preferred iPhone share menu icon.
            if context == .wholeExtension && height == CGFloat(kBrowserAddoniPhoneShareIconHeight) {
                iconFilename = icons["\(kBrowserAddoniPhoneShareIconHeight)"] as? String
                if iconFilename != nil {
                    break END
                }
            }

            // Preferred iPod share menu icon.
            if context == .wholeExtension && height == CGFloat(kBrowserAddoniPadShareIconHeight) {
                iconFilename = icons["\(kBrowserAddoniPadShareIconHeight)"] as? String
                if iconFilename != nil {
                    break END
                }
            }

            var iconHeight = 0

            while true {

                for (key, value) in icons {
                    // Skip JSON errors
                    guard let key = key as? String, let keyHeight = Int(key) else {
                        continue
                    }

                    // Skip preferred icons
                    if context == .wholeExtension &&
                        (keyHeight == kBrowserAddoniPadShareIconHeight ||
                            keyHeight == kBrowserAddoniPhoneShareIconHeight) {
                        continue
                    }

                    if iconFilename == nil ||
                        (CGFloat(keyHeight) >= height && CGFloat(iconHeight) < height) ||
                        (CGFloat(keyHeight) >= height && iconHeight > keyHeight) ||
                        (CGFloat(keyHeight) < height && iconHeight < keyHeight) {
                        iconFilename = value as? String
                        iconHeight = keyHeight
                    }
                }

                if iconFilename == nil && context != .wholeExtension {
                    // try the whole extension icon as fallback
                    // in case the specific icon context is not available
                    context = .wholeExtension
                    icons = manifest.iconPaths(for: context) ?? [:]
                } else {
                    // Return any object from array, do not skip ignored
                    if iconFilename == nil {
                        iconFilename = icons.first?.value as? String
                    }
                    break
                }
            }
        }

        guard let filename = iconFilename else {
            throw Utils.error(forWrappingError: nil, message: "No image for extension '\(extensionId)'")
        }

        let iconData: Data?
        do {
            iconData = try bundle?.data(ofResource: filename, inExtensionOfId: extensionId)
        } catch let error as NSError {
            throw Utils.error(forWrappingError: error, message: "Asking image '\(filename)' of extension '\(extensionId)'")
        }

        guard let uwIconData = iconData, let image = UIImage(data: uwIconData) else {
            throw Utils.error(forWrappingError: nil, message: "Creating image '\(filename)' of extension '\(extensionId)'")
        }

        if height > 0 && height < image.size.height {
            // downscaling required
            return image.imageScaled(toWidth: 0, height: height)
        } else {
            return image
        }
    }

    public func chooseBestTranslationsFile() -> Data? {
        assert(bundle != nil)
        return bundle?.translationsFile(for: extensionId, defaultLocale: manifest.defaultLocale)
    }

    // MARK: - callbacks

    /*
     Callbacks for a single extension generally has two types:
     content script and everything else.
     - Content script callbacks can be as many as there is browser tabs, hence
     the separate signatures with tab id.
     - Background and popup callbacks are not multiplied by tabs, hence the
     signatures without tab id (but giving the specific callback origin)
     */

    /// Some script of this extension has added a listener, which produced a persistent callback.
    public func add(_ callback: BridgeCallback) {
        callbacks.append(callback)
    }

    /// Remove all listener callbacks with given origin
    /// @warn NOT applicable to CallbackOriginContent, use signature with tabId
    @objc
    public func removeCallbacks(for origin: CallbackOriginType) {
        callbacks = callbacks.filter { callback in
            return callback.origin != origin && callback.isValid
        }
    }

    /// Remove all listener callbacks which originated in content script.
    /// Call when page gets reloaded.
    /// - Parameters:
    ///   - tabId: the tab id of content script
    ///   - event: removes just the callbacks for given event
    ///              CallbackEvent_Undefined removes all callbacks on the tab
    @objc
    public func removeContentCallbacks(for tabId: Int, event: CallbackEventType) {
        let removeByType = event != .undefined
        callbacks = callbacks.filter { callback in
            // true => predicate match => leave object in array
            // false => predicate fail => remove object
            let willStay = callback.origin != .content || callback.tab != tabId || (removeByType && callback.event != event)
            #if DEBUG
                let callbackId = callback.callbackId
                Log.debug("removeContentCallbacks \(willStay ? "keeping" : "removing") \(callbackId))")
            #endif
            return willStay && callback.isValid
        }
    }

    /// Remove one specific callback with token assigned by JS API
    public func removeCallback(with callbackId: String)
    {
        for (index, callback) in callbacks.enumerated() where callback.callbackId == callbackId {
            callbacks.remove(at: index)
            break
        }
    }

    /// - Returns: all listener callbacks to content script
    /// - Parameters:
    ///   - event: the event type requested
    ///   - tabId: the tab id in question
    public func callbacksToContent(for event: CallbackEventType, andTab tabId: Int) -> [BridgeCallback] {
        return callbacks.filter { callback in
            return callback.origin == .content && callback.event == event && callback.tab == tabId
        }
    }

    /// - Returns: all listener callbacks NOT to content script
    /// - Parameters:
    ///   - origin: the origin type which defines the target group
    ///   - event: the event type requested
    @objc
    public func callbacks(for origin: CallbackOriginType, event: CallbackEventType) -> [BridgeCallback] {
        return callbacks.filter { callback in
            if callback.event != event {
                return false
            }
            // background can talk to popup and vice versa
            // content can talk to background and popup, but not vice versa
            // (there is callbacksToContent for vice versa, with tab id)
            switch origin {
            case .background:
                return callback.origin == .popup
            case .popup:
                return callback.origin == .background
            case .content:
                return callback.origin != .content
            }
        }
    }

    // MARK: - Scripts

    @objc
    public func contentScripts() -> [ContentScript] {
        return manifest.contentScripts
    }

    @objc
    public func script(for contentScript: ContentScript) throws -> String {
        return try string(byConcatingFiles: contentScript.filenames)
    }

    private func string(byConcatingFiles filenames: [String]) throws -> String {
        guard let bundle = bundle else {
            throw Utils.error(forWrappingError: nil, message: "No bundle for extension '\(extensionId)'")
        }
        return try filenames.reduce("", { result, filename in
            do {
                let data = try bundle.data(ofResource: filename, inExtensionOfId: extensionId)
                return result + String(data: data, encoding: String.Encoding.utf8)!
            } catch let error as NSError {
                throw Utils.error(forWrappingError: error, message: "Asking resource '\(filename)' of extension '\(extensionId)'")
            }
        })
    }

    // MARK: - ChromeStorageMutationDelegate

    public func storageIdentifier() -> String {
        return extensionId
    }

    public func storageDataChanged(_ dataDictionary: [AnyHashable: Any]) {
        commandDelegate?.eventDispatcher.dispatch(.storage_OnChanged,
                                                  extension: self,
                                                  json: dataDictionary)
    }

    // MARK: - Private

}

private func transferValues(from storage1: ChromeStorageProtocol, to storage2: ChromeStorageProtocol) throws {
    let values = try storage1.values(for: nil)
    try storage2.merge(values)
}

extension ExtensionBundleDataSource {
    fileprivate func loadTranslations(for extensionId: String, withLocale locale: String) -> Data? {
        let path = "_locales/\(locale)/messages.json"
        return try? data(ofResource: path, inExtensionOfId: extensionId)
    }

    fileprivate func translationsFile(for extensionId: String, defaultLocale: String?) -> Data? {
        let locale = Locale.current.identifier

        if let file = loadTranslations(for: extensionId, withLocale: locale) {
            return file
        }

        let generalLocale = locale.components(separatedBy: "_")[0]
        if let generalFile = loadTranslations(for: extensionId, withLocale: generalLocale) {
            return generalFile
        }

        if let defaultLocale = defaultLocale {
            return loadTranslations(for: extensionId, withLocale: defaultLocale)
        }

        return nil
    }
    // swiftlint:disable:next file_length
}
