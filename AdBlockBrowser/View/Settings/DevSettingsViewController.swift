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
import HockeySDK

let defaultsKeyShowMemoryPressure = "ShowMemoryPressure"

enum TestingError: StringCodeConvertibleError {
    case devbuildTest

    var shortCode: String {

        switch self {
        case .devbuildTest:
            return "DevbuildTestError"
        }
    }
}

final class DevSettingsViewController: SettingsTableViewController<DevSettingsViewModel>, SwitchCellDelegate {
    @IBOutlet weak var showMemoryLabel: UILabel?
    @IBOutlet weak var crashAppButton: UIButton?
    @IBOutlet weak var produceErrorButton: UIButton?
    @IBOutlet weak var nextAppStartFailureButton: UIButton?

    static func setDefaultShowMemoryPressure() {
        UserDefaults.standard.register(defaults: [
            defaultsKeyShowMemoryPressure: false
            ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        showMemoryLabel?.text = NSLocalizedString("Show Memory Pressure Indication",
                                                  comment: "Devbuild setting")
        crashAppButton?.setTitle(
            NSLocalizedString("Crash Application Now", comment: "Devbuild setting"),
            for: .normal)
        produceErrorButton?.setTitle(
            NSLocalizedString("Produce Error Now", comment: "Devbuild setting"),
            for: .normal)
        nextAppStartFailureButton?.setTitle(
            NSLocalizedString("Next App Start Failure", comment: "Devbuild setting"),
            for: .normal)
        navigationItem.title = NSLocalizedString("Devbuild Settings", comment: "Navigation control title")
        #if DEVBUILD_FEATURES
            nextAppStartFailureButton?.isEnabled = !BootstrapController.failOnNextBootstrap
        #else
            nextAppStartFailureButton?.isEnabled = false
        #endif
    }

    @IBAction func onCrashAppButtonClicked(_ sender: UIButton) {
        BITHockeyManager.shared().crashManager.generateTestCrash()
    }

    @IBAction func onProduceErrorButtonClicked(sender: UIButton) {
        Log.critical(TestingError.devbuildTest)
        let alert = UIAlertController(
            title: NSLocalizedString("Dev notification", comment: "Devbuild setting"),
            message: NSLocalizedString("Error prepared for sending", comment: "Devbuild setting"),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Devbuild setting"),
                                      style: .default, handler: nil))
        present(alert, animated: false, completion: nil)
    }

    @IBAction func onNextAppStartFailureButtonClicked(sender: UIButton) {
        #if DEVBUILD_FEATURES
            BootstrapController.failOnNextBootstrap = true
        #endif
        nextAppStartFailureButton?.isEnabled = false
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if indexPath.section == 0 && indexPath.row == 0 {
            if let cell = cell as? SwitchCell {
                cell.type = .switch
                cell.isOn = UserDefaults.standard.bool(forKey: defaultsKeyShowMemoryPressure)
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
            header?.text = localize("MEMORY PRESSURE", comment: "Devbuild setting section header")
        case 1:
            header?.text = localize("CRASH AND ERROR REPORTING", comment: "Devbuild setting section header")
        default:
            break
        }

        return header
    }

    // MARK: - SwitchCellDelegate

    func switchValueDidChange(_ sender: SwitchCell) {
        UserDefaults.standard.set(sender.isOn, forKey: defaultsKeyShowMemoryPressure)
        UserDefaults.standard.synchronize()
    }
}
