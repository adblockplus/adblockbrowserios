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
import RxSwift
import UIKit

// Extracted from the embedded extension.
// File: firstRun.js
public let blockingItems = [
    "TrackingCell": (
        title: localize("Disable Tracking", comment: "Ad blocking Settings - Disable tracking"),
        subscription: ListedSubscription(
            url: "https://easylist-downloads.adblockplus.org/easyprivacy.txt",
            title: "EasyPrivacy",
            homepage: "https://easylist.adblockplus.org/")
    ),
    "DomainsCell": (
        title: localize("Disable Malware Domains", comment: "Ad blocking Settings - Disable malware domains"),
        subscription: ListedSubscription(
            url: "https://easylist-downloads.adblockplus.org/malwaredomains_full.txt",
            title: "Malware Domains",
            homepage: "http://malwaredomains.com/")
    ),
    "ButtonsCell": (
        title: localize("Disable Social Media Buttons", comment: "Ad blocking Settings - Disable social media buttons"),
        subscription: ListedSubscription(
            url: "https://easylist-downloads.adblockplus.org/fanboy-social.txt",
            title: "Fanboy\\'s Social Blocking List",
            homepage: "https://easylist.adblockplus.org/")
    ),
    "MessagesCell": (
        title: localize("Disable Anti-Ad blocking Messages", comment: "Ad blocking Settings - Disable anti-adblocking messages"),
        subscription: ListedSubscription(
            url: "https://easylist-downloads.adblockplus.org/antiadblockfilters.txt",
            title: "Adblock Warning Removal List",
            homepage: "https://easylist.adblockplus.org/")
    )
]

final class AdblockingSettingsViewController: SettingsTableViewController<AdblockingSettingsViewModel>, SwitchCellDelegate {
    @IBOutlet weak var adblockingLabel: UILabel?
    @IBOutlet weak var exceptionsLabel: UILabel?
    @IBOutlet weak var languagesLabel: UILabel?

    let items = blockingItems

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = localize("Ad blocking", comment: "Ad blocking Settings - title")
        adblockingLabel?.text = localize("Ad blocking", comment: "Ad blocking Settings - cell title")
        exceptionsLabel?.text = localize("Exceptions", comment: "Ad blocking Settings - show more blocking options")
        languagesLabel?.text = localize("Languages", comment: "Ad blocking Settings - enable/disable acceptable ads")
    }

    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: nil)
        switch segue.destination {
        case let controller as ExceptionsViewController:
            if let viewModel = viewModel {
                controller.viewModel = ExceptionsViewModel(components: viewModel.components,
                                                           isAcceptableAdsEnabled: viewModel.isAcceptableAdsEnabled)
            }
        default:
            break
        }
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    override func observe(viewModel: ViewModelEx) {
        super.observe(viewModel: viewModel)

        viewModel.extensionFacade.getListedSubscriptions { [weak self] (listedSubscriptions: [String: ListedSubscription]?, error: Error?) in
            if let error = error {
                Log.error("Listed subscriptions query returned \(error)")
                return
            }

            guard let listedSubscriptions = listedSubscriptions else {
                Log.warn("Listed subscriptions query returned nil dictionary")
                return
            }

            self?.viewModel?.update(subscriptions: listedSubscriptions)
            self?.tableView.reloadData()
        }

        viewModel.isAcceptableAdsEnabled.asDriver()
            .drive(onNext: { [weak self] _ in
                self?.tableView?.reloadSections(IndexSet(integer: 0), with: .none)
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: - SwitchCellDelegate

    func switchValueDidChange(_ cell: SwitchCell) {
        if cell.reuseIdentifier == "AdBlockingCell" {
            viewModel?.extensionEnabled = cell.isOn
            tableView.reloadData()
        } else if let identifier = cell.reuseIdentifier,
            let item = items[identifier],
            let status = viewModel?.subscriptionsStatus[item.subscription] {
                switch status {
                case .notInstalled:
                    viewModel?.extensionFacade.addSubscription(item.subscription)
                    viewModel?.subscriptionsStatus[item.subscription] = .enabled
                case .installedButDisabled:
                    viewModel?.extensionFacade.subscription(item.subscription, enabled: true)
                    viewModel?.subscriptionsStatus[item.subscription] = .enabled
                case .enabled:
                    // Remove (not disable) subscription
                    viewModel?.extensionFacade.removeSubscription(item.subscription)
                    viewModel?.subscriptionsStatus[item.subscription] = .notInstalled
                }
        }
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.numberOfLines = 2
        if #available(iOS 9.0, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }

        let isEnabled = viewModel?.extensionEnabled ?? false

        if cell.reuseIdentifier == "AdBlockingCell", let cell = cell as? SwitchCell {
            cell.isOn = isEnabled
            cell.delegate = self
            return cell
        }

        (cell as? SwitchCell)?.isEnabled = isEnabled
        cell.isUserInteractionEnabled = isEnabled
        cell.selectionStyle = isEnabled ? .default : .none
        cell.textLabel?.isEnabled = isEnabled

        if cell.reuseIdentifier == "ExceptionsCell" {
            let allow = localize("Yes", comment: "Allow Google search")
            let deny = localize("No", comment: "Deny Google search")
            cell.detailTextLabel?.text = viewModel?.isAcceptableAdsEnabled.value ?? false ? allow : deny
        } else {
            cell.detailTextLabel?.text = nil
        }

        if let identifier = cell.reuseIdentifier, let item = items[identifier] {
            cell.textLabel?.text = item.title
            if let cell = cell as? SwitchCell {
                if let status = viewModel?.subscriptionsStatus[item.subscription] {
                    cell.type = .switch
                    cell.isOn = status == .enabled
                    cell.delegate = self
                } else {
                    cell.type = .activityIndicator
                }
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
            header?.text = localize("ADBLOCK BROWSER", comment: "Ad blocking Settings - section header")
        case 1:
            header?.text = localize("MORE OPTIONS", comment: "Ad blocking Settings - section header")
        default:
            header?.text = nil
        }

        return header
    }
}
