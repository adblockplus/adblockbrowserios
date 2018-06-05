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

protocol WelcomeProgressDelegate: class {
    func next()
    func finished()
}

/// class WelcomeController: UIViewController
/// One class is used by two view controllers
class WelcomeController: UIViewController {
    fileprivate static let WelcomeGuideSeen = "WelcomeGuideSeen"
    @IBOutlet weak var screen1HeadlineLabel: UILabel?
    @IBOutlet weak var screen1ParagraphLabel: UILabel?
    @IBOutlet weak var screen1Button: UIButton?
    @IBOutlet weak var screen2HeadlineLabel: UILabel?
    @IBOutlet weak var screen2ParagraphLabel: UILabel?
    @IBOutlet weak var screen2PictureLabel: UILabel?
    @IBOutlet weak var screen2Button: UIButton?

    weak var progressDelegate: WelcomeProgressDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        screen1HeadlineLabel?.text = localize("Browse in peace",
                                              comment: "Welcome guide screen 1 headline")
        screen1ParagraphLabel?.text = localize("Ad blocking is automatically integrated - no more annoying ads while you surf!",
                                               comment: "Welcome guide screen 1 paragraph")
        screen1Button?.setTitle(localize("Only one more step", comment: "Welcome guide screen 1 button"), for: UIControlState())
        screen2HeadlineLabel?.text = localize("You're in control",
                                              comment: "Welcome guide screen 2 headline")
        screen2ParagraphLabel?.text =
            localize("Annoying ads are always blocked, while nonintrusive ads are displayed by default. You can change this setting at any time.",
                     comment: "Welcome guide screen 2 paragraph")
        screen2PictureLabel?.text = localize("onboarding_exceptions_navigation_path",
                                             comment: "Welcome guide screen 2 picture label")
        screen2Button?.setTitle(localize("Finish", comment: "Welcome guide screen 2 button"), for: UIControlState())
    }

    @IBAction func onOneMoreStepTouch(_ sender: UIView?) {
        progressDelegate?.next()
    }

    @IBAction func onFinishTouch(_ sender: UIView?) {
        progressDelegate?.finished()
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: WelcomeController.WelcomeGuideSeen)
        defaults.synchronize()
    }

    class func shouldShowWelcomeController() -> Bool {
        return !UserDefaults.standard.bool(forKey: WelcomeGuideSeen)
    }
}
