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

final class GhostModeBanner: UIView {
    @IBOutlet weak var headlineLabel: UILabel?
    @IBOutlet weak var sublineLabel: UILabel?
    @IBOutlet weak var tipLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()

        headlineLabel?.text = localize("ghost_mode_banner_headline", comment: "Ghost mode banner")
        sublineLabel?.text = localize("ghost_mode_banner_subline", comment: "Ghost mode banner")
        tipLabel?.text = localize("ghost_mode_banner_tip", comment: "Ghost mode banner")
    }

    static func create() -> GhostModeBanner? {
        let nib = UINib(nibName: "GhostModeBanner", bundle: Bundle.main)
        return nib.instantiate(withOwner: nil, options: nil).first as? GhostModeBanner
    }
}
