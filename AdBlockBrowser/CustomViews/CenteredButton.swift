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

final class CenteredButton: UIButton {
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        var rect = super.titleRect(forContentRect: contentRect)
        rect.size.width = min(rect.width, contentRect.width)
        rect.size.height = min(rect.height, contentRect.height)
        rect.origin.x = (contentRect.width - rect.width) / 2
        rect.origin.y = (contentRect.height - rect.height) / 2
        return rect.inset(by: titleEdgeInsets)
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        var rect = super.imageRect(forContentRect: contentRect)
        rect.size.width = min(rect.width, contentRect.width)
        rect.size.height = min(rect.height, contentRect.height)
        rect.origin.x = (contentRect.width - rect.width) / 2
        rect.origin.y = (contentRect.height - rect.height) / 2
        return rect.inset(by: imageEdgeInsets)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        centerTitleLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centerTitleLabel()
    }

    private func centerTitleLabel() {
        titleLabel?.textAlignment = .center
    }
}
