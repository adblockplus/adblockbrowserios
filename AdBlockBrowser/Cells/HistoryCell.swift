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

final class HistoryCell: UITableViewCell {
    func set(historyUrl: HistoryUrl) {
        if let data = historyUrl.icon?.iconData {
            let image = UIImage(data: data)

            // Images need to be resized, otherwise they
            let scale = UIScreen.main.scale
            UIGraphicsBeginImageContextWithOptions(type(of: self).imageSize, false, scale)
            image?.draw(in: type(of: self).imageRect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            imageView?.image = newImage
        } else {
            imageView?.image = type(of: self).cellImage
        }
        textLabel?.text = historyUrl.title
        detailTextLabel?.text = historyUrl.url
    }

    // MARK: - Private

    private static let imageSize = CGSize(width: 40, height: 40)
    private static let imageRect = CGRect(origin: CGPoint(), size: imageSize)
    private static let cellImage = { () -> UIImage? in
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(imageSize, true, scale)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        let label = UILabel(frame: imageRect)
        label.text = "W"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 24)
        label.backgroundColor = .abbCoolGray
        label.layer.draw(in: context)
        return UIGraphicsGetImageFromCurrentImageContext()
    }()
}
