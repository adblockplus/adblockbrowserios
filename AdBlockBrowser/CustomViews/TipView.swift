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

final class TipView: UIView {
    @IBOutlet weak var label: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()

        label?.text = NSLocalizedString("TIP", comment: "TIP")
        label?.textColor = .abbCoolGray
        label?.textAlignment = .center

        layer.borderWidth = 1
        layer.borderColor = UIColor.abbCoolGray.cgColor
        layer.cornerRadius = 5
        layer.masksToBounds = true

        layoutMargins = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
    }
}
