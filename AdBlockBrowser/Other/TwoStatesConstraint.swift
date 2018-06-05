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

final class TwoStatesConstraint: NSLayoutConstraint {
    var firstState: CGFloat = 0.0

    @IBInspectable var secondState: CGFloat = 0.0

    @IBInspectable var priorityStateType: Bool = false

    func setState(_ second: Bool) {
        let value = second ? firstState : secondState
        if priorityStateType {
            priority = UILayoutPriority(rawValue: Float(value))
        } else {
            constant = value
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if priorityStateType {
            firstState = CGFloat(priority.rawValue)
        } else {
            firstState = constant
        }
    }

    func interpolate(_ xValue: CGFloat) {
        if priorityStateType {
            priority = UILayoutPriority(rawValue: Float(firstState * xValue + secondState * (1 - xValue)))
        } else {
            constant = firstState * xValue + secondState * (1 - xValue)
        }
    }
}
