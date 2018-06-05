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

final class BookmarkCell: UITableViewCell {
    private typealias Item = BookmarkExtras

    var isGhostModeStyleUsed = false {
        didSet {
            textLabel?.textColor = isGhostModeStyleUsed ? .abbSilver : .abbGhostMode
        }
    }

    func set(bookmark: BookmarkExtras) {
        if let data = bookmark.icon?.iconData {
            let image = UIImage(data: data)

            // Images need to be resized
            UIGraphicsBeginImageContextWithOptions(type(of: self).imageSize, false, contentScaleFactor)
            defer {
                UIGraphicsEndImageContext()
            }
            image?.draw(in: type(of: self).imageRect)
            imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        } else {
            imageView?.image = type(of: self).cellImage
        }

        textLabel?.text = bookmark.title
        detailTextLabel?.text = bookmark.url
    }

    // MARK: - Private

    private static let imageSize = CGSize(width: 40, height: 40)
    private static let imageRect = CGRect(origin: CGPoint(), size: imageSize)

    /// Gray image which is used as placeholder,
    /// if there is not any image avaible
    private static let cellImage = { () -> UIImage? in
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 1.0)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        context.setFillColor(UIColor.abbCoolGray.cgColor)
        context.fill(imageRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }()
}
