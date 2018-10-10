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

enum SwitchCellAccessoryType {
    case activityIndicator
    case `switch`
}

protocol SwitchCellDelegate: NSObjectProtocol {
    func switchValueDidChange(_ sender: SwitchCell)
}

final class SwitchCell: TableViewCell {
    private let `switch` = UISwitch()
    private let activityIndicator = UIActivityIndicatorView(style: .gray)

    var type = SwitchCellAccessoryType.switch {
        didSet {
            if oldValue == .activityIndicator {
                activityIndicator.stopAnimating()
            }
            switch type {
            case .activityIndicator:
                accessoryView = activityIndicator
                activityIndicator.startAnimating()
            case .switch:
                accessoryView = `switch`
            }
        }
    }

    weak var delegate: SwitchCellDelegate?

    var isOn: Bool {
        get {
            return `switch`.isOn
        }
        set {
            `switch`.isOn = newValue
        }
    }

    var isEnabled: Bool = true {
        didSet {
            isUserInteractionEnabled = isEnabled
            selectionStyle = isEnabled ? .default : .none
            `switch`.isEnabled = isEnabled
            textLabel?.isEnabled = isEnabled
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        type = .switch
        selectionStyle = .none
        `switch`.addTarget(self, action: #selector(handleSwitchValueChange(_:)), for: .valueChanged)
    }

    // MARK: - Action

    @objc
    private func handleSwitchValueChange(_ sender: UISwitch) {
        delegate?.switchValueDidChange(self)
    }
}
