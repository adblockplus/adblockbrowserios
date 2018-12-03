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

final class DashboardTipReusableView: UICollectionReusableView {
    @IBOutlet weak var tipLabel: UILabel?
    @IBOutlet weak var tipViewWidth: NSLayoutConstraint!
    @IBOutlet weak var tipLabelSpacing: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        tipLabel?.text = localize("dashboard_tip_text", comment: "Dashboard tip footer text")

        // reservedWidthTotal being the width of |tipView|, plus the spacing between |tipView|
        // and |tipLabel|, plus 16px for the margins (32px either side).
        let reservedWidthTotal = tipViewWidth.constant + tipLabelSpacing.constant + 64.0
        let maxTipLabelWidth = self.frame.size.width - reservedWidthTotal
        tipLabel?.preferredMaxLayoutWidth = maxTipLabelWidth
    }
}
