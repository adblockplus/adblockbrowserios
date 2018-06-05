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

final class UndoToast: UIView {
    let label = UILabel()
    let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    private func initialize() {
        let labelText = NSLocalizedString("You closed a tab", comment: "Undo tooltip")
        let buttonTitle = NSLocalizedString("UNDO", comment: "Undo tooltip")

        let textColor = #colorLiteral(red: 0.9568627451, green: 0.9529411765, blue: 0.9450980392, alpha: 1)
        backgroundColor = #colorLiteral(red: 0.3215686275, green: 0.3215686275, blue: 0.3215686275, alpha: 1)
        layer.cornerRadius = 5
        layer.masksToBounds = true

        let font = UIFont.systemFont(ofSize: 12)

        label.font = font
        label.textColor = textColor
        label.text = labelText
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[label]-8-|",
                                                      options: NSLayoutFormatOptions(),
                                                      metrics: nil,
                                                      views: ["label": label]))

        button.titleLabel?.font = font
        button.tintColor = textColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 8)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        button.setTitle(buttonTitle, for: .normal)
        button.setImage(#imageLiteral(resourceName: "UndoIconTip"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[button]-0-|",
                                                      options: NSLayoutFormatOptions(),
                                                      metrics: nil,
                                                      views: ["button": button]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-8-[label]-(>=8)-[button]-0-|",
                                                      options: NSLayoutFormatOptions(),
                                                      metrics: nil,
                                                      views: ["button": button, "label": label]))
    }
}
