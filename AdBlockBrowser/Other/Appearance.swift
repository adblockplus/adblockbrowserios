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

import AttributedMarkdown
import Foundation
import UIKit

let animationDuration = TimeInterval(0.35)
let defaultTransitionDuration = TimeInterval(0.35)

public func attributedStringFromMarkdown(_ string: String, attributes: [AnyHashable: Any]) -> NSAttributedString? {
    guard let attributedString = markdown_to_attr_string(string, 0, attributes) else {
        return nil
    }

    let output = attributedString.string

    // Markdow is putting two newline characters at the end of string.
    // This code will remove them.
    let set = CharacterSet.whitespacesAndNewlines

    var count = 0

    for char in output.unicodeScalars.reversed() {
        if !set.contains(char) {
            break
        }
        count += 1
    }

    if count > 0 {
        let range = NSRange(location: output.unicodeScalars.count - count, length: count)
        attributedString.deleteCharacters(in: range)
    }

    return attributedString
}

extension UIColor {
    static let abbBlue = #colorLiteral(red: 0.03137254902, green: 0.6156862745, blue: 0.8039215686, alpha: 1)

    static let abbLightGray = #colorLiteral(red: 0.9568627451, green: 0.9529411765, blue: 0.9450980392, alpha: 1)

    static let abbSilver = #colorLiteral(red: 0.7764705882, green: 0.7843137255, blue: 0.7921568627, alpha: 1)

    static let abbCoolGray = #colorLiteral(red: 0.6705882353, green: 0.6784313725, blue: 0.6862745098, alpha: 1)

    static let abbSlateGray = #colorLiteral(red: 0.368627451, green: 0.3725490196, blue: 0.3803921569, alpha: 1)

    static let abbCharcoalGray = #colorLiteral(red: 0.2156862745, green: 0.231372549, blue: 0.2509803922, alpha: 1)

    static let abbGhostMode = #colorLiteral(red: 0.1294117647, green: 0.1254901961, blue: 0.1490196078, alpha: 1)

    static let abbRulerGray = #colorLiteral(red: 0.8235294118, green: 0.8274509804, blue: 0.8352941176, alpha: 1)
}
