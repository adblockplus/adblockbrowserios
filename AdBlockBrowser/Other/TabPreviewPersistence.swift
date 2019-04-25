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

private final class ObservedArrayWatcher<T>: NSObject where T: NSObject {
    weak var observer: NSObject?
    let keyPath: String
    let array: [T]

    init(observer: NSObject, keyPath: String, array: [T]) {
        self.observer = observer
        self.keyPath = keyPath
        self.array = array

        super.init()

        for element in array {
            element.addObserver(self, forKeyPath: keyPath, options: .new, context: nil)
        }
    }

    deinit {
        for element in array {
            element.removeObserver(self, forKeyPath: keyPath, context: nil)
        }
    }

    // swiftlint:disable:next block_based_kvo
    fileprivate override func observeValue(forKeyPath keyPath: String?,
                                           of object: Any?,
                                           change: [NSKeyValueChangeKey: Any]?,
                                           context: UnsafeMutableRawPointer?) {
        if self.keyPath == keyPath {
            observer?.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

let tabsDirectory = "TabPreviews"

final class TabPreviewPersistence: NSObject {
    fileprivate let imageDirectoryURL: NSURL

    fileprivate var _windows = [ChromeWindow: ObservedArrayWatcher<ChromeTab>]()
    fileprivate var windowsToTabs: [ChromeWindow: ObservedArrayWatcher<ChromeTab>] {
        get { return _windows }
        set {
            for (window, _) in _windows {
                window.removeObserver(self, forKeyPath: "tabs", context: nil)
            }
            _windows = newValue
            for (window, _) in _windows {
                window.addObserver(self, forKeyPath: "tabs", options: .new, context: nil)
            }
        }
    }

    init?(chrome: Chrome) {
        if let url = TabPreviewPersistence.constructImageDirectoryURL() as NSURL? {
            imageDirectoryURL = url
        } else {
            // If directory cannot be constructed, make an empty URL.
            // Will cancel the constructor after super.init()
            imageDirectoryURL = NSURL()
        }

        super.init()

        // Initialization is cancelled when directory cannot be created
        if imageDirectoryURL.path?.isEmpty ?? true ||
            !TabPreviewPersistence.createDirectoryIfNotExists(imageDirectoryURL as URL) {
            return nil
        }

        var map = [ChromeWindow: ObservedArrayWatcher<ChromeTab>]()
        for window in chrome.windows {
            if let tabs = window.tabs as? [ChromeTab] {
                for (index, tab) in tabs.enumerated() {
                    if let imageURL = imageURLFor((Int(window.identifier), index)) {
                        tab.preview = readPreviewFrom(imageURL as NSURL)
                    }
                }
                map[window] = ObservedArrayWatcher(observer: self, keyPath: "preview", array: tabs)
            } else {
                return nil
            }
        }
        windowsToTabs = map
    }

    deinit {
        windowsToTabs = [:]
    }

    // MARK: - Public

    func tabsDidChangedIn(_ window: ChromeWindow) {
        if let watcher = windowsToTabs[window], let newTabs = window.tabs as? [ChromeTab] {

            // Create mapping from webView to indices
            var map = [ChromeTab: Int]()
            for (index, tab) in watcher.array.enumerated() {
                map[tab] = index
            }

            // Story preview for new and moved items
            for (index, tab) in newTabs.enumerated() {

                var overwrite = true
                if let newIndex = map[tab] {
                    overwrite = newIndex != index
                }

                if overwrite {
                    if let preview = tab.preview,
                        let imageURL = imageURLFor((Int(window.identifier), index)) {
                        _ = write(preview, to: imageURL)
                    }
                }
            }

            // Commit changes
            windowsToTabs[window] = ObservedArrayWatcher(observer: self, keyPath: "preview", array: newTabs)
        }
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case .some("tabs"):
            if let window = object as? ChromeWindow {
                tabsDidChangedIn(window)
            }
        case .some("preview"):
            if let preview = change?[NSKeyValueChangeKey.newKey] as? UIImage,
                let tab = object as? ChromeTab,
                let watcher = windowsToTabs[tab.window],
                let index = watcher.array.firstIndex(of: tab),
                let imageURL = imageURLFor((Int(tab.window.identifier), index)) {
                _ = write(preview, to: imageURL)
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - Private

    fileprivate func write(_ preview: UIImage, to url: URL) -> Bool {
        let data = preview.pngData()
        guard (((try? data?.write(to: url)) as ()??)) != nil else {
            return false
        }
        return true
    }

    fileprivate func readPreviewFrom(_ url: NSURL) -> UIImage? {
        if let data = try? Data(contentsOf: url as URL) {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    fileprivate func imageURLFor(_ indices: (Int, Int)) -> URL? {
        if indices.0 == 0 { // For compatibility with previous versions with one window
            return imageDirectoryURL.appendingPathComponent("image_\(indices.1).png")
        } else {
            return imageDirectoryURL.appendingPathComponent("image_\(indices.0)_\(indices.1).png")
        }
    }

    fileprivate class func constructImageDirectoryURL() -> URL? {
        let directories = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let directory = directories.first else { return nil }
        return URL(fileURLWithPath: directory).appendingPathComponent(tabsDirectory)
    }

    fileprivate class func createDirectoryIfNotExists(_ url: URL) -> Bool {
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
        return (try? FileManager.default.createDirectory(atPath: path,
                                                         withIntermediateDirectories: true,
                                                         attributes: nil)) != nil
    }
}
