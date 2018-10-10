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

public enum EventType {
    case crash
    case recoverableError
}

public protocol EventHandlingStatusAccess: class {
    var eventHandlingStatus: EventHandlingStatus { get set }

    func askUserSendApproval(eventType: EventType, userInputHandler: @escaping UserInputHandler)
}

public typealias UserInputHandler = (BITCrashManagerUserInput) -> Void

/**
 The alert modal created and displayed by askUserSendApproval is now used as custom handler
 for HockeyApp SDK (@see DebugReporting.configureCrashReporting) so it must stay visible
 on top even if window.rootViewController is changed meanwhile (i.e. at app startup).
 iOS8+ UIAlertController is not capable of that cleanly, so legacy UIAlertView is needed.

 https://github.com/bitstadium/HockeySDK-iOS/blob/3305675a8738f54a8c8b314d978752b61b772779/Classes/BITCrashManager.m#L1088

 UIAlertViewDelegate implementation is required and a member variable for
 UserInputHandler for access from the delegate.
 */
final class HockeyEventDefaultsHandler: NSObject, EventHandlingStatusAccess, UIAlertViewDelegate {
    private var userInputHandler: UserInputHandler?

    private var rawCrashManagerStatus = UInt(UserDefaults.standard.integer(forKey: "BITCrashManagerStatusOldValue"))

    var eventHandlingStatus: EventHandlingStatus {
        get {
            let status = BITCrashManagerStatus(rawValue: rawCrashManagerStatus) ?? .disabled
            switch status {
            case .alwaysAsk:
                return .alwaysAsk
            case .autoSend:
                return .autoSend
            case .disabled:
                return .disabled
            }
        }

        set {
            let status: BITCrashManagerStatus
            switch newValue {
            case .alwaysAsk:
                status = .alwaysAsk
            case .autoSend:
                status = .autoSend
            case .disabled:
                status = .disabled
            }
            BITHockeyManager.shared().crashManager.crashManagerStatus = status
        }
    }

    static func setStatus(status: BITCrashManagerStatus) {
        BITHockeyManager.shared().crashManager.crashManagerStatus = status
    }

    private var showStatusChangeHintFlag = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HockeyEventDefaultsHandler.userDefaultsDidChange(_:)),
            name: UserDefaults.didChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc
    func userDefaultsDidChange(_ notification: NSNotification) {
        let userDefaults = UserDefaults.standard

        guard let rawStatus = userDefaults.value(forKey: "BITCrashManagerStatus") as? UInt, rawStatus != rawCrashManagerStatus else {
            return
        }

        rawCrashManagerStatus = rawStatus
        userDefaults.setValue(rawStatus, forKey: "BITCrashManagerStatusOldValue")
        userDefaults.synchronize()

        guard let status = BITCrashManagerStatus(rawValue: rawStatus), status == .autoSend else {
            return
        }
        // was changed to no send/autosend, show config reverting hint
        if showStatusChangeHintFlag {
            showStatusChangeHint()
        }
    }

    private func showStatusChangeHint() {
        let title = NSLocalizedString("Crash and Error Reports",
                                      comment: "Crash Reports Dialogs")
        let message = NSLocalizedString("You can change this setting at any time in: **Settings → Crash and Error Reports**",
                                        comment: "Crash Reports Dialogs")
        let accept = NSLocalizedString("Got it",
                                       comment: "Crash Reports Dialogs")

        let attributes = [
            NSNumber(value: STRONG.rawValue): [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 17)] as Any,
            NSNumber(value: PARA.rawValue): [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 17)]
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

    /// This is a copy of HockeyApp crash confirmation dialog appearance/texting.
    /// It needs to be copied because it will be displayed not only upon crash but
    /// also critical errors. The advantage also is that more translations can be
    /// provided (HA SDK has a limited size of i18n)
    func askUserSendApproval(eventType: EventType, userInputHandler: @escaping UserInputHandler) {
        let title: String
        switch eventType {
        case .crash:
            title = NSLocalizedString("Adblock Unexpectedly Quit", comment: "Crash/Error Report Sending Modal")
        case .recoverableError:
            title = NSLocalizedString("Adblock Browser Encountered an Error", comment: "Crash/Error Report Sending Modal")
        }
        let message = NSLocalizedString("Would you like to send a report to fix the problem?",
                                        comment: "Crash/Error Report Sending Modal")

        self.userInputHandler = userInputHandler
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: NSLocalizedString("Don't Send", comment: "Crash/Error Report Sending Modal"),
                                         style: .cancel) { _ in
            userInputHandler(.dontSend)
        }
        let sendButton = UIAlertAction(title: NSLocalizedString("Send Report", comment: "Crash/Error Report Sending Modal"),
                                       style: .default) { _ in
            userInputHandler(.send)
        }
        let alwaysSendButton = UIAlertAction(title: NSLocalizedString("Always Send", comment: "Crash/Error Report Sending Modal"),
                                             style: .default) { _ in
            userInputHandler(.send)
        }
        alertView.addAction(cancelButton)
        alertView.addAction(sendButton)
        alertView.addAction(alwaysSendButton)

        guard let windowReference = UIApplication.shared.delegate?.window,
            let root = windowReference?.rootViewController else {
                return
        }

        alertView.show(root, sender: nil)
    }
}
