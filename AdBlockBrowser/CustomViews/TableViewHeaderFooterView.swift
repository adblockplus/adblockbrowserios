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

final class TableViewHeaderFooterView: UITableViewHeaderFooterView {
    private let _textLabel = UILabel(frame: CGRect())
    var insets = UIEdgeInsets(top: 16, left: 8, bottom: 0, right: 8) {
        didSet {
            setNeedsLayout()
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(_textLabel)
        _textLabel.numberOfLines = 0
        _textLabel.textColor = UIColor(white: 0.45, alpha: 1)
        _textLabel.font = .systemFont(ofSize: 11)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var text: String? {
        get {
            return _textLabel.text
        }
        set {
            _textLabel.text = newValue
        }
    }

    var attributedText: NSAttributedString? {
        get {
            return _textLabel.attributedText
        }
        set {
            _textLabel.attributedText = newValue
        }
    }

    override var textLabel: UILabel? {
        return _textLabel
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        _textLabel.frame = UIEdgeInsetsInsetRect(contentView.bounds, insets)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = size
        size.width -= insets.left + insets.right
        size.height -= insets.top + insets.bottom
        size = _textLabel.sizeThatFits(size)
        size.width = ceil(size.width + insets.left + insets.right)
        size.height = ceil(size.height + insets.top + insets.bottom)
        return size
    }
}
