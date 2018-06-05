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

import UIKit

private let keyPaths = [
    #keyPath(ChromeTab.documentTitle),
    #keyPath(ChromeTab.URL),
    #keyPath(ChromeTab.faviconImage),
    #keyPath(ChromeTab.preview),
    #keyPath(ChromeTab.hibernated)
]

final class TabViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var urlLabel: UILabel?
    @IBOutlet weak var faviconImage: UIImageView?
    @IBOutlet weak var previewImage: UIImageView?

    fileprivate var _tab: ChromeTab?

    var tab: ChromeTab? {
        get { return _tab }
        set { setObservedProperty(&_tab, newValue, self, keyPaths) }
    }

    var isGhostModeStyleUsed = false {
        didSet {
            backgroundColor = isGhostModeStyleUsed ? .abbGhostMode : .white
            titleLabel?.textColor = isGhostModeStyleUsed ? .abbSilver : .abbGhostMode
        }
    }

    deinit {
        tab = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Background on iPad was white:
        // http://stackoverflow.com/questions/18901394/uitableview-uitableviewcell-challenge-with-transparent-background-on-ipad-with
        backgroundColor = .clear
        isGhostModeStyleUsed = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tab = nil
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        assert(Thread.isMainThread)

        let key = change?[NSKeyValueChangeKey.newKey]

        switch keyPath {
        case .some("documentTitle"):
            titleLabel?.text = key as? String
        case .some("URL"):
            var label: String? = nil
            if let url = key as? URL {
                if !(url as NSURL).shouldBeHidden() {
                    label = url.displayableHostname
                } else {
                    label = nil
                }
            }

            if label == nil {
                titleLabel?.text = NSLocalizedString("New Tab", comment: "Tab view label")
            }

            urlLabel?.text = label
        case .some("faviconImage"):
            faviconImage?.image = key as? UIImage
        case .some("preview"):
            previewImage?.image = key as? UIImage
        case .some("hibernated"):
            // Might be handy again for debugging
            // titleLabel?.textColor = key as? Bool ?? false ? UIColor.redColor() : UIColor.whiteColor()
            break
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
