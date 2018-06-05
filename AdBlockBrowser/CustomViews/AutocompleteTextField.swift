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

class AutocompleteTextField: UITextField {
    @IBInspectable var suggestionTextColor: UIColor {
        get { return autocompleteLabel.textColor }
        set { autocompleteLabel.textColor = newValue }
    }

    let autocompleteLabel = UILabel()

    var previousText: String?

    var historyManager: BrowserHistoryManager?

    // Override Swiftlint force_try rule as we are using a fixed valid pattern.
    // swiftlint:disable:next force_try
    private let urlSchemePrefix = try! NSRegularExpression(pattern: "^(https?):",
                                                           options: .caseInsensitive)

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        autocompleteLabel.textColor = UIColor.lightGray
        autocompleteLabel.font = font
        autocompleteLabel.text = ""
        autocompleteLabel.isHidden = true
        addSubview(autocompleteLabel)
        addTarget(self, action: #selector(onEditingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(onTextChanged), for: .editingChanged)
        addTarget(self, action: #selector(onEditingDidEnd), for: .editingDidEnd)
    }

    override var font: UIFont? {
        didSet {
            autocompleteLabel.font = font
        }
    }

    // When text is set and autocompleteLabel is displayed, set also the autocomplete text.
    // Otherwise the commit...() below overwrites it again with the last suggestion.
    override var text: String? {
        didSet {
            if !autocompleteLabel.isHidden {
                autocompleteLabel.text = text
            }
        }
    }

    func commitAutocompleteSuggestion() {
        if !autocompleteLabel.isHidden {
            text = autocompleteLabel.text
        }
    }

    func setCursorToBeginning() {
        let isCurrentlyFirstResponder = isFirstResponder
        // Optional function which reverts the original state of responder and delegate
        var responderReset: (() -> Void)?
        // Cursor can be set only if UITextField is first responder
        if !isCurrentlyFirstResponder {
            let lastDelegate = delegate
            delegate = nil
            becomeFirstResponder()
            responderReset = { () in
                self.resignFirstResponder()
                self.delegate = lastDelegate
            }
        }

        if let end = position(from: beginningOfDocument, offset: 1) {
            let range = textRange(from: beginningOfDocument, to: end)
            selectedTextRange = range
            if isCurrentlyFirstResponder {
                selectAll(nil)
            }
        }
        responderReset?()
    }

    // Safari-like functionality: when text is partially typed and autocompleted with a suggestion,
    // first backspace should just cancel the suggestion, not delete the actually typed character.
    // Further backspaces with no autocomplete suggestion displayed should operate normally.
    func shouldChangeCharactersInRange(_ range: NSRange, replacementString string: String) -> Bool {
        guard let currentText = text else {
            return true
        }

        let textRange = currentText.index(currentText.startIndex,
                                          offsetBy: range.location) ..< currentText.index(currentText.startIndex,
                                                                                          offsetBy: range.location + range.length)
        let futureText = currentText.replacingCharacters(in: textRange, with: string)

        guard futureText.isBackspaceEditOf(currentText) else {
            // interested only in potential backspacing
            return true
        }
        if autocompleteLabel.isHidden {
            // autocomplete is already hidden, let the backspace happen
            return true
        }
        // autocomplete is still shown, hide it and cancel the backspace
        autocompleteLabel.isHidden = true
        return false
    }

    // MARK: - Actions

    @objc
    func onEditingDidBegin(_ sender: UITextField) {
        showAutocomplete(for: text)
    }

    @objc
    func onEditingDidEnd(_ sender: UITextField) {
        autocompleteLabel.isHidden = true
    }

    @objc
    func onTextChanged(_ sender: UITextField) {
        if isEditing {
            showAutocomplete(for: text)
        }
        previousText = text
    }

    // MARK: - Private

    fileprivate func showAutocomplete(for text: String?) {
        autocompleteLabel.isHidden = true

        guard let text = self.text, !text.isEmpty else {
            return
        }

        guard let previousText = previousText, !text.isBackspaceEditOf(previousText) else {
            // Text was backspaced, do not provide autocompletion
            return
        }

        let autocompleteText: String

        if let suggestions = historyManager?.historySuggestions(for: text),
            let suggestion = suggestions.max(by: { suggestion1, suggestion2 in return suggestion1.counter < suggestion2.counter }) {

            if let scheme = urlSchemePrefix.match(text)?.first {
                autocompleteText = "\(scheme)://\(suggestion.host)"
            } else {
                autocompleteText = suggestion.host
            }
        } else if let phrase = historyManager?.omniboxHistoryFindPhrase(withPrefix: text, limit: 1)?.first?.phrase {
            autocompleteText = text + phrase[text.endIndex...]
        } else {
            return
        }

        if autocompleteText.count <= text.count {
            return
        }

        guard let range = textRange(from: beginningOfDocument, to: endOfDocument) else {
            return
        }

        let textRect = firstRect(for: range)
        let rect = convert(textRect, from: textInputView)

        autocompleteLabel.isHidden = false
        autocompleteLabel.text = autocompleteText
        autocompleteLabel.sizeToFit()
        autocompleteLabel.frame.origin.x = rect.minX
        autocompleteLabel.frame.origin.y = rect.origin.y
        autocompleteLabel.frame.size.height = rect.height
    }
}

extension String {
    func isBackspaceEditOf(_ text: String) -> Bool {
        return text.hasPrefix(self) && self.count < text.count
    }
}

extension NSRegularExpression {
    func match(_ text: String) -> [String]? {
        return self
        .firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count))
        .map { (result) in
            return (1 ..< result.numberOfRanges).map { (index) in
                return (text as NSString).substring(with: result.range(at: index))
            }
        }
    }
}
