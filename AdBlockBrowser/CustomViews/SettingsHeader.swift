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

final class SettingsHeader: UITableViewHeaderFooterView {
    private let customTextLabel = UILabel()
    private let customDetailTextLabel = UILabel()
    private let customActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    func setup() {
        preservesSuperviewLayoutMargins = true
        contentView.backgroundColor = .clear
        contentView.addSubview(customTextLabel)
        contentView.addSubview(customDetailTextLabel)
        contentView.addSubview(customActivityIndicatorView)
        customTextLabel.numberOfLines = 0
        customTextLabel.textColor = .abbSlateGray
        customTextLabel.font = .systemFont(ofSize: 12)
        customDetailTextLabel.numberOfLines = 0
        customDetailTextLabel.textColor = .abbSlateGray
        customDetailTextLabel.font = .systemFont(ofSize: 12)
    }

    override var textLabel: UILabel? {
        return customTextLabel
    }

    override var detailTextLabel: UILabel? {
        return customDetailTextLabel
    }

    var text: String? {
        didSet {
            customTextLabel.text = text?.uppercased()
            setNeedsLayout()
        }
    }

    var detailText: String? {
        get {
            return customDetailTextLabel.text
        }
        set {
            customDetailTextLabel.text = newValue
            setNeedsLayout()
        }
    }

    var attributedDetailText: NSAttributedString? {
        get {
            return customDetailTextLabel.attributedText
        }
        set {
            customDetailTextLabel.attributedText = newValue
            setNeedsLayout()
        }
    }

    var isAnimating: Bool = false {
        didSet {
            if isAnimating {
                customActivityIndicatorView.startAnimating()
            } else {
                customActivityIndicatorView.stopAnimating()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let (_, textFrame, detailTextFrame) = computeDimensions(for: contentView.bounds.size)
        customTextLabel.frame = textFrame
        customDetailTextLabel.frame = detailTextFrame
        customActivityIndicatorView.center = CGPoint(x: textFrame.maxX + customActivityIndicatorView.frame.height,
                                                     y: textFrame.midY)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return computeDimensions(for: size).0
    }

    private func computeDimensions(for size: CGSize) -> (CGSize, CGRect, CGRect) {
        let margins = layoutMargins

        let width = max(size.width - margins.left - margins.right, 0)
        let height1 = max(size.height - margins.top - margins.bottom, 0)

        let textSize = customTextLabel.sizeThatFits(CGSize(width: width, height: height1))
        let textFrame = CGRect(origin: CGPoint(x: margins.left, y: margins.top), size: textSize)

        if detailText == nil {
            let size = CGSize(width: size.width, height: textFrame.maxY + margins.bottom)
            return (size, textFrame, .zero)
        }

        let height2 = max(height1 - textFrame.height - 8, 0)

        let detailTextSize = customDetailTextLabel.sizeThatFits(CGSize(width: width, height: height2))
        let detailTextFrame = CGRect(origin: CGPoint(x: margins.left, y: textFrame.maxY + 8),
                                     size: detailTextSize)

        let size = CGSize(width: size.width, height: detailTextFrame.maxY + margins.bottom)
        return (size, textFrame, detailTextFrame)
    }
}
