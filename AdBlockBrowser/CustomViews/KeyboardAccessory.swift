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

class KeyboardAccessory: UIInputView, UIInputViewAudioFeedback {
    // factory method
    class func attachTo(_ textField: UITextField!, parentFrame: CGRect) {
        let accessoryFrame = CGRect(x: 0, y: 0, width: parentFrame.width, height: 45)
        // KeyboardAccessory does not have its own constructor but the constructor used
        // is equal to UIInputView. Strangely both XCode 6.1 and XCode 6.3 allow compilation
        // of partial constructor (just frame:) but the instance is very broken then!
        // (buttons array crashing with EXC_BAD_ACCESS)
        let keyboardAccessory = KeyboardAccessory(frame: accessoryFrame, inputViewStyle: UIInputViewStyle.default)
        keyboardAccessory.addButton(":", extraTyping: nil, widthMultiplier: 1)
        keyboardAccessory.addButton("/", extraTyping: nil, widthMultiplier: 1)
        keyboardAccessory.addButton("-", extraTyping: nil, widthMultiplier: 1)
        keyboardAccessory.addButton(".", extraTyping: nil, widthMultiplier: 1)
        keyboardAccessory.addButton(".com", extraTyping: [".com", ".net", ".org"], widthMultiplier: 2)
        keyboardAccessory.attachAccessoryTo(textField)
        keyboardAccessory.setNeedsUpdateConstraints()
    }

    fileprivate struct ButtonSpec {
        let button: CYRKeyboardButton
        let widthMultiplier: Float
    }

    fileprivate var buttons = [ButtonSpec]()

    fileprivate struct KeyboardButtonMetric {
        let width: Float // button width
        let height: Float // button height
        let horizontalSpacing: Float // inter-button spacing horizontal
        let verticalSpacing: Float // inter-button spacing vertical
        let topPadding: Float // top padding
    }

    // There is no enum just with Portrait/Landscape in Cocoa
    // Only Portrait left, portrait right, and upside down
    // But we need just two orientations
    fileprivate enum KeyboardOrientation {
        case portrait
        case landscape
    }

    // Metric for the device model. Contains both orientations
    fileprivate typealias ModelMetric = [KeyboardOrientation: KeyboardButtonMetric]

    fileprivate var _modelMetric: ModelMetric?

    fileprivate var modelMetric: ModelMetric {
        if let uwModelMetric = _modelMetric {
            return uwModelMetric
        }

        var deviceModelName = Sys.deviceModelName
        // Can't think of a better way to provide something for simulator
        if deviceModelName.hasPrefix("Simulator") {
            deviceModelName = "iPhone 6"
        }

        if let modelMetric = modelMetricMatching[deviceModelName] {
            _modelMetric = modelMetric
            return modelMetric
        }

        for (matchName, metric) in modelMetricMatching {
            if deviceModelName.hasPrefix(matchName) {
                _modelMetric = metric
                return metric
            }
        }

        // Default option when the model name is not recognized
        let metric = modelMetricMatching["iPhone 6"]!
        _modelMetric = metric
        return metric
    }

    // @todo vertical spacing and top padding was meant to provide accurate vertical position
    // of the additional button line. But it's not possible to change the accessory view frame
    // dynamically, it holds the height given with constructor. So the values are not applicable
    // in a simple way. The accessory view would have to be basically destroyed and reinitialized
    // with each device rotation. Arcane.
    fileprivate let modelMetricMatching: [String: ModelMetric] = [
        "iPhone 4": [
            KeyboardOrientation.portrait: KeyboardButtonMetric(width: 26, height: 39, horizontalSpacing: 6, verticalSpacing: 15, topPadding: 12),
            KeyboardOrientation.landscape: KeyboardButtonMetric(width: 42, height: 33, horizontalSpacing: 6, verticalSpacing: 7, topPadding: 6)
        ],
        "iPhone 5": [
            KeyboardOrientation.portrait: KeyboardButtonMetric(width: 26, height: 39, horizontalSpacing: 6, verticalSpacing: 15, topPadding: 12),
            KeyboardOrientation.landscape: KeyboardButtonMetric(width: 51, height: 33, horizontalSpacing: 6, verticalSpacing: 7, topPadding: 6)
        ],
        "iPhone 6": [
            KeyboardOrientation.portrait: KeyboardButtonMetric(width: 31.5, height: 43, horizontalSpacing: 6, verticalSpacing: 11, topPadding: 10),
            KeyboardOrientation.landscape: KeyboardButtonMetric(width: 48, height: 33, horizontalSpacing: 5, verticalSpacing: 7, topPadding: 6)
        ],
        "iPhone 6 Plus": [ // multiplier 3
            KeyboardOrientation.portrait: KeyboardButtonMetric(width: 35, height: 46, horizontalSpacing: 6, verticalSpacing: 10, topPadding: 8),
            KeyboardOrientation.landscape: KeyboardButtonMetric(width: 48, height: 33, horizontalSpacing: 5, verticalSpacing: 7, topPadding: 6)
        ]
    ]
    // Needed for click sounds
    var enableInputClicksWhenVisible: Bool {
        return true
    }

    func addButton(_ typing: String!, extraTyping: [String]?, widthMultiplier: Float) {
        let button = CYRKeyboardButton()
        button.translatesAutoresizingMaskIntoConstraints = false // SUPER IMPORTANT !!!!
        button.input = typing
        button.inputOptions = extraTyping
        addSubview(button)
        buttons.append(ButtonSpec(button: button, widthMultiplier: widthMultiplier))
    }

    func attachAccessoryTo(_ textField: UITextField!) {
        textField.inputAccessoryView = self
        for buttonSpec in buttons {
            // set the text input to which the buttons will be typing
            buttonSpec.button.textInput = textField
        }
    }

    override func updateConstraints() {
        updateConstraintsForOrientation(UIApplication.shared.statusBarOrientation)
        super.updateConstraints()
    }

    func updateConstraintsForOrientation(_ orientation: UIInterfaceOrientation) {
        // Remove any existing constraints
        removeConstraints(constraints)

        let orientationMetric = modelMetric[UIInterfaceOrientationIsPortrait(orientation) ?
            KeyboardOrientation.portrait : KeyboardOrientation.landscape ]!

        // Left and right horizontal centering spacers
        var bindings = [String: UIView]()
        for spacerName in ["spacer1", "spacer2"] {
            let view = UIView(frame: CGRect.zero)
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            bindings[spacerName] = view
        }

        // Horizontal: centered and spaced array of buttons
        let horizMetrics: [String: Float] = ["spacing": orientationMetric.horizontalSpacing]
        var horizVFL = "H:|"
        for (idx, buttonSpec) in buttons.enumerated() {
            let buttonName = "keyboardButton\(idx)"
            bindings[buttonName] = buttonSpec.button
            let width: Float =
                orientationMetric.width * buttonSpec.widthMultiplier + orientationMetric.horizontalSpacing * (buttonSpec.widthMultiplier - 1)
            let buttonFormat = "\(buttonName)(\(width))"
            if idx == 0 {
                horizVFL += "-[spacer1(>=spacing)]-[\(buttonFormat)]"
            } else if idx < buttons.count - 1 {
                horizVFL += "-spacing-[\(buttonFormat)]"
            } else {
                horizVFL += "-spacing-[\(buttonFormat)]-[spacer2(==spacer1)]-"
            }
        }
        horizVFL += "|"
        addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: horizVFL, options: NSLayoutFormatOptions(), metrics: horizMetrics, views: bindings))

        let top = Float(6)
        let vertMetrics = [
            "top": top,
            "height": orientationMetric.height,
            // Disabled rule due to false positive
            // swiftlint:disable:next operator_usage_whitespace
            "bottom": Float(self.frame.height)-top-orientationMetric.height
        ]
        for buttonName in bindings.keys {
            let vertVFL = "V:|-top-[\(buttonName)(height)]-bottom-|"
            addConstraints(
                NSLayoutConstraint.constraints(
                    withVisualFormat: vertVFL, options: NSLayoutFormatOptions(), metrics: vertMetrics, views: bindings))
        }
    }
}
