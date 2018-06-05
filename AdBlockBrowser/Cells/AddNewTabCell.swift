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

final class AddNewTabCell: UITableViewCell {
    @IBOutlet weak var plusBorderView: UIView?
    @IBOutlet weak var titleLabel: UILabel?

    var isGhostModeStyleUsed = false {
        didSet {
            let borderColor = (isGhostModeStyleUsed ? UIColor.abbCoolGray : UIColor.abbSilver).cgColor
            layer.borderColor = borderColor
            plusBorderView?.layer.borderColor = borderColor
            titleLabel?.textColor = isGhostModeStyleUsed ? .abbSilver : .abbGhostMode
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        layer.borderWidth = 1
        plusBorderView?.layer.borderWidth = 1
        isGhostModeStyleUsed = false

        titleLabel?.text = localize("add_new_tab", comment: "Tabs view cell")
    }
}
