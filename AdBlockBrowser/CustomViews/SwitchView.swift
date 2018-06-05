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

final class SwitchView: UIControl {
    @IBInspectable var onTintColor: UIColor = .white {
        didSet {
            onBackground.backgroundColor = onTintColor
        }
    }

    @IBInspectable var disabledTintColor: UIColor = .darkGray {
        didSet {
            update()
        }
    }

    var isOn: Bool {
        get {
            return _isOn
        }
        set {
            setOn(newValue, animated: true)
        }
    }

    override var isEnabled: Bool {
        didSet {
            update()
        }
    }

    private let size = CGSize(width: 40, height: 24)
    private let dot = UIView(frame: CGRect())
    private let onBackground = UIView(frame: CGRect())
    private let offBackground = UIView(frame: CGRect())
    private var _isOn = false {
        didSet {
            sendActions(for: .valueChanged)
            update()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }

    func setOn(_ isOn: Bool, animated: Bool) {
        if _isOn != isOn {
            if animated {
                UIView.animate(withDuration: 0.2) {
                    self._isOn = isOn
                }
            } else {
                _isOn = isOn
            }
        }
    }

    func prepare() {
        addSubview(offBackground)
        addSubview(onBackground)
        addSubview(dot)

        offBackground.backgroundColor = .clear
        offBackground.layer.borderColor = tintColor.cgColor
        offBackground.layer.borderWidth = 1
        offBackground.layer.cornerRadius = size.height / 2
        offBackground.layer.masksToBounds = true
        offBackground.frame.origin = .zero
        offBackground.frame.size = size

        onBackground.backgroundColor = onTintColor
        onBackground.layer.cornerRadius = size.height / 2
        onBackground.layer.masksToBounds = true
        onBackground.frame.origin = .zero
        onBackground.frame.size = size

        dot.backgroundColor = tintColor
        dot.layer.cornerRadius = 8
        dot.layer.masksToBounds = true
        dot.frame.size = CGSize(width: 16, height: 16)

        addTarget(self, action: #selector(SwitchView.toggle(_:)), for: .touchUpInside)

        update()
    }

    func update() {
        onBackground.alpha = _isOn && isEnabled ? 1 : 0
        offBackground.alpha = _isOn && isEnabled ? 0 : 1
        let offset = _isOn && isEnabled ? 40 - 8 - 4 : 8 + 4
        dot.center = CGPoint(x: offset, y: 12)

        if isEnabled {
            dot.backgroundColor = _isOn ? .white : tintColor
            offBackground.layer.borderColor = tintColor.cgColor
        } else {
            dot.backgroundColor = disabledTintColor
            offBackground.layer.borderColor = disabledTintColor.cgColor
        }
    }

    override var intrinsicContentSize: CGSize {
        return size
    }

    // MARK: - Private

    @objc
    private func toggle(_ sender: UIControl?) {
        _isOn = !_isOn
    }
}
