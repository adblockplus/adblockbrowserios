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
import UIKit

final class CrashReportsViewController: SettingsTableViewController<CrashReportsViewModel> {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = localize("Crash and Error Reports", comment: "Crash/Error reports settings")
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let currentStatus = viewModel?.statusAccess?.eventHandlingStatus ?? .disabled
        if let status = status(from: indexPath.row) {
            cell.accessoryType = currentStatus == status ? .checkmark : .none
            cell.textLabel?.text = title(for: status)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? SettingsHeader

        switch section {
        case 0:
            header?.text = localize("SEND CRASH AND ERROR REPORTS", comment: "Crash/Error reports settings")
        default:
            break
        }

        return header
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section != 0 {
            return nil
        }

        guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? SettingsHeader else {
            return nil
        }

        // swiftlint:disable:next line_length
        let information = localize("Only anonymized data containing device information and crash or error details are sent. Please refer to our privacy policy at adblockplus.org for more information.",
                                   comment: "Crash/Error reports settings")
        let privacyPolicy = localize("Open privacy policy.",
                                     comment: "Crash/Error reports settings")

        let ppFormatted = privacyPolicy.components(separatedBy: .whitespaces).joined(separator: "\u{00A0}")
        let detailText = "\(information) *\(ppFormatted)*"

        let innerAttributes = [
            NSAttributedStringKey.link: URL(string: "https://adblockplus.org/privacy")! as Any,
            NSAttributedStringKey.foregroundColor: #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
        ]

        let attributes = [NSNumber(value: EMPH.rawValue): innerAttributes]

        let attrString = attributedStringFromMarkdown(detailText, attributes: attributes)

        if let attrString = attrString, let font = footer.detailTextLabel?.font {
            let attributedText = NSMutableAttributedString(attributedString: attrString)
            let range = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(NSAttributedStringKey.font, value: font, range: range)
            footer.attributedDetailText = attributedText
        } else {
            footer.detailText = detailText
        }

        footer.text = nil

        if (footer.gestureRecognizers?.count ?? 0) == 0 {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGestureRecognizerTap(_:)))
            footer.addGestureRecognizer(recognizer)
        }

        return footer
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            let footer = self.tableView(tableView, viewForFooterInSection: section)
            return footer?.sizeThatFits(CGSize(width: tableView.frame.width, height: CGFloat(MAXFLOAT))).height ?? 0
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let status = status(from: indexPath.row) {
            viewModel?.statusAccess?.eventHandlingStatus = status
            tableView.reloadData()
        }
    }

    // MARK: - Actions

    @objc
    func handleGestureRecognizerTap(_ sender: UITapGestureRecognizer) {
        if sender.state != .ended {
            return
        }

        guard let header = sender.view as? SettingsHeader, let textLabel = header.detailTextLabel else {
            return
        }

        let point = sender.location(in: header)
        let location = header.convert(point, to: textLabel)

        guard let url = extractUrl(at: location, from: textLabel) else {
            return
        }

        viewModel?.browserControlDelegate?.showNewTab(with: url, fromSource: nil)
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Private

    private func status(from index: Int) -> EventHandlingStatus? {
        switch index {
        case 0:
            return .autoSend
        case 1:
            return .disabled
        case 2:
            return .alwaysAsk
        default:
            return nil
        }
    }

    private func title(for status: EventHandlingStatus) -> String {
        switch status {
        case .autoSend:
            return localize("Always", comment: "Crash/Error reports settings")
        case .disabled:
            return localize("Never", comment: "Crash/Error reports settings")
        case .alwaysAsk:
            return localize("Ask Me After a Crash or Error", comment: "Crash/Error reports settings")
        }
    }
}
