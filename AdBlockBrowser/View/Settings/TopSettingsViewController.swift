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

final class TopSettingsViewController: SettingsTableViewController<TopSettingsViewModel>, SwitchCellDelegate {
    @IBOutlet weak var adBlockingLabel: UILabel?
    @IBOutlet weak var clearDataLabel: UILabel?
    @IBOutlet weak var searchEngineLabel: UILabel?
    @IBOutlet weak var searchSuggestionsLabel: UILabel?
    @IBOutlet weak var versionLabel: UILabel?
    @IBOutlet weak var crashAndErrorReportsLabel: UILabel?
    let sectionGeneral = 3
    let sectionGeneralRows = 2

    override func viewDidLoad() {
        super.viewDidLoad()

        if let object = viewModel?.extensionFacade as? NSObject {
            object.addObserver(self,
                               forKeyPath: keyPathExtensionEnabled,
                               options: .new,
                               context: nil)
        }

        let doneTitle = localize("Done", comment: "Settings - Done button")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: doneTitle,
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(dismissView))

        adBlockingLabel?.text = localize("Ad blocking", comment: "Settings - cell title")
        clearDataLabel?.text = localize("Clear Browsing Data", comment: "Settings status option")
        searchEngineLabel?.text = localize("Search Engine", comment: "Settings status option")
        searchSuggestionsLabel?.text = localize("URL Search Suggestions", comment: "Settings status option")

        #if DEVBUILD_FEATURES
            versionLabel?.text = String(format: "%@ build %@ (core %@)", arguments:
                [Settings.applicationVersion(), Settings.applicationBuild(), Settings.coreVersion()])
        #else
            versionLabel?.text = String(format: "%@ (core %@)", arguments:
                [Settings.applicationVersion(), Settings.coreVersion()])
        #endif

        crashAndErrorReportsLabel?.text = localize("Crash and Error Reports", comment: "Settings status option")

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onUserDefaultsDidChange(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }

    deinit {
        if let object = viewModel?.extensionFacade as? NSObject {
            object.removeObserver(self, forKeyPath: keyPathExtensionEnabled)
        }

        NotificationCenter.default.removeObserver(self)
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case .some(keyPathExtensionEnabled):
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)],
                                 with: .none)
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - SwitchCellDelegate

    func switchValueDidChange(_ cell: SwitchCell) {
        UserDefaults.standard.set(cell.isOn, forKey: defaultsKeyAutocomplete)
        UserDefaults.standard.synchronize()
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // only interested in 4th section
        if section == sectionGeneral {
            #if DEVBUILD_FEATURES
                // show everything
                return super.tableView(tableView, numberOfRowsInSection: section)
            #else
                // hide devbuild menu by default
                return sectionGeneralRows
            #endif
        } else {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.numberOfLines = 2

        if cell.reuseIdentifier == "AdblockPlus"{
            let enabled = viewModel?.extensionFacade.extensionEnabled ?? false
            cell.detailTextLabel?.text = enabled ?
                NSLocalizedString("On", comment: "Settings - extension enabled status") :
                NSLocalizedString("Off", comment: "Settings - extension enabled status")

        } else if cell.reuseIdentifier == "SearchSuggestions", let cell = cell as? SwitchCell {
            cell.isOn = UserDefaults.standard.bool(forKey: defaultsKeyAutocomplete)
            cell.delegate = self
        } else if cell.reuseIdentifier == "SearchEngine" {
            let engine = UserDefaults.standard.selectedSearchEngine()
            cell.detailTextLabel?.text = engine.name
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
            header?.text = localize("ADBLOCK BROWSER", comment: "Settings - section header")
        case 1:
            header?.text = localize("SEARCH", comment: "Settings - section header")
        case 2:
            header?.text = localize("VERSION", comment: "Settings - section header")
        case 3:
            header?.text = localize("GENERAL", comment: "Settings - section header")
        default:
            break
        }

        return header
    }

    // MARK: - Private

    @objc
    private func dismissView(_ sender: AnyObject?) {
        dismiss(animated: true, completion: nil)
    }

    @objc
    private func onUserDefaultsDidChange(_ sender: Notification) {
        let newSearchEngine = UserDefaults.standard.selectedSearchEngine()
        if newSearchEngine !== viewModel?.searchEngine {
            viewModel?.searchEngine = newSearchEngine
            tableView.reloadData()
        }
    }
}
