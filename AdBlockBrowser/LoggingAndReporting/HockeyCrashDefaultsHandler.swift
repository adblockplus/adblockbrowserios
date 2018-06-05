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
import HockeySDK

final class HockeyCrashDefaultsHandler: NSObject {
    var crashManagerStatus: UInt

    override init() {
        crashManagerStatus = UInt(UserDefaults.standard.integer(forKey: "BITCrashManagerStatusOldValue"))
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HockeyCrashDefaultsHandler.userDefaultsDidChanged(_:)),
            name: UserDefaults.didChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc
    func userDefaultsDidChanged(_ notification: Notification) {
        let userDefaults = UserDefaults.standard

        guard let rawStatus = userDefaults.value(forKey: "BITCrashManagerStatus") as? UInt, rawStatus != crashManagerStatus else {
            return
        }

        crashManagerStatus = rawStatus
        userDefaults.setValue(rawStatus, forKey: "BITCrashManagerStatusOldValue")
        userDefaults.synchronize()

        guard let status = BITCrashManagerStatus(rawValue: rawStatus), status == .disabled || status == .autoSend else {
            return
        }

        if HockeyCrashDefaultsHandler.disableDialogs {
            return
        }

        let title = NSLocalizedString("Crash Reports",
                                      comment: "Crash Reports Dialogs")
        let message = NSLocalizedString("You can change this setting at any time in: **Settings → Crash Reports**",
                                        comment: "Crash Reports Dialogs")
        let accept = NSLocalizedString("Got it",
                                       comment: "Crash Reports Dialogs")

        let attributes = [
            NSNumber(value: STRONG.rawValue as UInt32): [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 17)] as Any,
            NSNumber(value: PARA.rawValue as UInt32): [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 17)]
        ]

        let attributedMessage = attributedStringFromMarkdown(message, attributes: attributes)

        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: accept, style: .default, handler: nil))
        alertController.setValue(attributedMessage, forKey: "attributedMessage")

        guard let windowReference = UIApplication.shared.delegate?.window,
            let root = windowReference?.rootViewController else {
                return
        }

        UIHandler.presentModal(alertController, inController: root)
    }

    static var disableDialogs = false

    static func set(_ status: BITCrashManagerStatus) {
        disableDialogs = true
        BITHockeyManager.shared().crashManager.crashManagerStatus = status
        disableDialogs = false
    }
}
