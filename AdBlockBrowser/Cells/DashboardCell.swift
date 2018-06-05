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

protocol DashboardDelegate: NSObjectProtocol {
    func editBookmark(for cell: DashboardCell)
}

final class DashboardCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView?
    @IBOutlet weak var titleLabel: UILabel?

    weak var delegate: DashboardDelegate?

    private var overlayView: UIView?

    override func prepareForReuse() {
        super.prepareForReuse()
        isHidden = false
        titleLabel?.text = nil
    }

    func set(bookmark: BookmarkExtras) {
        titleLabel?.text = bookmark.title
        if let data = bookmark.icon?.iconData {
            imageView?.image = UIImage(data: data)
        } else {
            imageView?.image = DashboardCell.placeholder
        }
    }

    override var isHighlighted: Bool {
        willSet {
            if overlayView == nil {
                if let imageView = imageView {
                    let overlay = UIView(frame: imageView.bounds)
                    overlay.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
                    imageView.addSubview(overlay)
                    overlayView = overlay
                }
            }

            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { () in
                self.overlayView?.alpha = newValue ? 1 : 0
                return
            }, completion: nil)
        }
    }

    // MARK: - UIResponderStandardEditActions

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(editBookmark(_:))
    }

    @objc
    func editBookmark(_ sender: Any?) {
        delegate?.editBookmark(for: self)
    }

    // MARK: - Private

    private static let imageSize = CGSize(width: 64, height: 64)
    private static let imageRect = CGRect(origin: CGPoint(), size: imageSize)
    private static let placeholder = { () -> UIImage? in
        UIGraphicsBeginImageContext(imageSize)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        context.setFillColor(UIColor(white: CGFloat(178) / 0xFF, alpha: 1.0).cgColor)
        context.fill(imageRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }()
}
