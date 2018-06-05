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

final class FailureController: UIViewController {
    @IBOutlet weak var exclamationHeadlineLabel: UILabel?
    @IBOutlet weak var apologySubheadingLabel: UILabel?
    @IBOutlet weak var explanationParagraphLabel: UILabel?
    @IBOutlet weak var bullet1Label: UILabel?
    @IBOutlet weak var bullet2Label: UILabel?
    @IBOutlet weak var bullet3Label: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        exclamationHeadlineLabel?.text = NSLocalizedString("Uh-Oh!", comment: "App start failure screen")
        apologySubheadingLabel?.text = NSLocalizedString("Something went wrong.", comment: "App start failure screen")
        explanationParagraphLabel?.text =
            NSLocalizedString("A critical error prevented Adblock Browser from starting. Follow the steps below to quit the app and try again.",
                              comment: "App start failure screen")
        bullet1Label?.text = NSLocalizedString("Double tap the Home button.", comment: "App start failure screen")
        bullet2Label?.text = NSLocalizedString("Swipe up on Adblock Browser to quit the app.", comment: "App start failure screen")
        bullet3Label?.text = NSLocalizedString("Restart Adblock Browser.", comment: "App start failure screen")
    }
}
