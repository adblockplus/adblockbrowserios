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

final class FindInPageControl: UIView {
    @IBOutlet weak var matchesLabel: UILabel?
    @IBOutlet weak var topConstraint: NSLayoutConstraint?
    @IBOutlet weak var doneButton: UIButton?

    weak var delegate: FindInPageControlDelegate?
    var phrase: String? {
        didSet {
            if let phrase = phrase {
                NotificationCenter.default.post(name: NSNotification.Name.fulltextSearchPhrase,
                                                object: nil,
                                                userInfo: ["phrase": phrase])
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(FindInPageControl.onSearchResultNotification(_:)),
                                               name: NSNotification.Name.fulltextSearchResult,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.fulltextSearchResult,
                                                  object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        doneButton?.setTitle(NSLocalizedString("Done", comment: "Find in Page toolbar button"), for: UIControl.State())
    }

    func clearMatches() {
        NotificationCenter.default.post(name: NSNotification.Name.fulltextSearchClear, object: nil)
        UIView.animate(withDuration: 0.3, animations: {
            self.topConstraint?.constant = 0
            self.layoutIfNeeded()
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    // MARK: - Actions

    @IBAction func onBackButtonTouched(_ sender: UIButton) {
        NotificationCenter.default.post(name: NSNotification.Name.fulltextSearchPrevious, object: nil)
    }

    @IBAction func onForwardButtonTouched(_ sender: UIButton) {
        NotificationCenter.default.post(name: NSNotification.Name.fulltextSearchNext, object: nil)
    }

    @IBAction func onDoneButtonTouched(_ sender: UIButton) {
        delegate?.willFinishFindInPageMode(self)
    }

    @objc
    func onSearchResultNotification(_ notification: Notification) {
        let total = notification.userInfo?["total"] as? Int ?? 0
        let current = total == 0 ? 0 : (notification.userInfo?["current"] as? Int ?? 0) + 1

        let result = NSLocalizedString("%@ of %@ matches", comment: "Find in page bar")
        matchesLabel?.text = String(format: result, "\(current)", "\(total)")
    }

    // MARK: -

    static func create() -> FindInPageControl? {
        let nib = UINib(nibName: "FindInPageControl", bundle: Bundle.main)
        return nib.instantiate(withOwner: nil, options: nil).first as? FindInPageControl
    }

    static let defaultHeight = CGFloat(45)
}

protocol FindInPageControlDelegate: NSObjectProtocol {
    func willFinishFindInPageMode(_ control: FindInPageControl)
}
