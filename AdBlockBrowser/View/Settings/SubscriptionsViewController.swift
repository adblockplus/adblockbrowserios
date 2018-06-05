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

final class SubscriptionsViewController: SettingsTableViewController<SubscriptionsViewModel>, SwitchCellDelegate {
    enum CellIdentifiers: String, CellIdentifier {
        case subscribedCell
        case availableCell
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel?.extensionFacade.getAvailableSubscriptions { [weak self] array, _ -> Void in
            if let subscriptions = array {
                self?.viewModel?.activeSubscriptions = subscriptions.lazy.filter { $0.listed }
                self?.viewModel?.subscriptions = subscriptions.lazy.filter { !$0.listed }
                self?.viewModel?.isLoading = false
                self?.tableView.reloadData()
            }
        }

        navigationItem.title = localize("Languages", comment: "Languages Settings - title")
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.count(for: section) ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifiers = indexPath.section == 0
            ? CellIdentifiers.subscribedCell
            : CellIdentifiers.availableCell

        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifiers, for: indexPath)

        if let subscription = viewModel?.subscription(for: indexPath) {
            switch cellIdentifiers {
            case .subscribedCell:
                (cell as? TableViewCell)?.style = .subtitle
                cell.textLabel?.text = subscription.specialization
                cell.detailTextLabel?.text = subscription.title
            case .availableCell:
                cell.textLabel?.text = subscription.specialization
            }

            if let cell = cell as? SwitchCell {
                cell.isOn = indexPath.section == 0
                cell.delegate = self
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? SettingsHeader

        switch section {
        case 0:
            header?.text = localize("Block ads for websites in", comment: "Languages Settings - section header")
        case 1:
            header?.text = localize("OTHER LANGUAGES", comment: "Languages Settings - section header")
        default:
            break
        }

        header?.isAnimating = viewModel?.isLoading ?? false
        return header
    }

    // MARK: - SwitchCellDelegate

    func switchValueDidChange(_ cell: SwitchCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            if let newIndexPath = viewModel?.addOrRemoveSubscription(for: indexPath) {
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .automatic)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
                tableView.endUpdates()
            }
        }
    }
}
