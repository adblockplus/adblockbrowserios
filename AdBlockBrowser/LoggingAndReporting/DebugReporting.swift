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

// abstract the logger implementation type and make the logging invocations reasonably short
typealias Log = LumberjackLogger

#if DEBUG
    public class DebugEventSender: EventSender {
        public func send(event: StringCodeConvertibleError) {
            Log.error("Would send event \(event.shortCode)")
        }

        public func send(events: [StringCodeConvertibleError]) {
            Log.error("Would send array of \(events.count) events")
            events.forEach { send(event: $0) }
        }
    }
#endif

/**
 Wraps configuration of crash reporting, runtime logging and supporting devbuild features.
 Manages BrowserController dependency.
 */
final class DebugReporting {
    public let statusAccess: EventHandlingStatusAccess = HockeyEventDefaultsHandler()
    private let eventSendingFunnel: EventSendingFunnel
    #if DEVBUILD_FEATURES
        let watchdog = MemoryWatchdog(interval: 0.5, changeBytesThreshold: 1024 * 1024)
        let driver = DaemonDriverUserDefaults(defaultsKeyShowMemoryPressure)
    #endif

    init() {
        // @todo xcconfig for the numbers
        #if DEVBUILD_FEATURES
            let timeout = 10
            let count = 100
        #else
            let timeout = 10 * 60
            let count = 10
        #endif
        #if DEBUG
            let eventSender = DebugEventSender()
        #else
            let eventSender = HockeyEventSender()
        #endif
        eventSendingFunnel = EventSendingFunnel(
            statusAccess: statusAccess,
            eventSender: eventSender,
            reportingTimeoutSecs: UInt64(timeout),
            reportingEventCount: count)
        LumberjackLogger.createInstance(eventFunnel: eventSendingFunnel)
        KittCoreLogger.loggerSinkType = LumberjackLogger.self
        configureCrashReporting()
        #if DEVBUILD_FEATURES
            DevSettingsViewController.setDefaultShowMemoryPressure()
            driver.daemon = watchdog
        #endif
    }

    func confirmAppAbortReport(with error: BootstrapError, modalPresentingController: UIViewController?, completion: @escaping () -> Void) {
        switch statusAccess.eventHandlingStatus {
        case .disabled:
            // don't ask don't log
            completion()
        case .autoSend:
            // don't ask but log
            Log.critical(error, forcedRegisteringCompletion: completion)
        case .alwaysAsk:
            let title = Utils.applicationName()
            let alert = UIAlertController(
                title: title,
                message: NSLocalizedString("Unable to start browser.", comment: "Critical abort alert message"),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Send Report", comment: "Crash/Error Report Sending Modal"), style: .default,
                handler: { _ in Log.critical(error, forcedRegisteringCompletion: completion) }
            ))
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("Don't Send", comment: "Crash/Error Report Sending Modal"), style: .default,
                handler: { _ in completion() }))
            modalPresentingController?.present(alert, animated: false, completion: nil)
        }
    }

    private func configureCrashReporting() {
        guard let hockeyAppIdentifier = MacroSettingsExpander.hockeyAppIdentifier(),
            hockeyAppIdentifier != "", hockeyAppIdentifier != "DEBUG",
            hockeyAppIdentifier != "DEVBUILD", hockeyAppIdentifier != "RELEASE" else {
            return
        }

        UserDefaults.standard.register(defaults: [
            "BITCrashManagerStatusOldValue": BITCrashManagerStatus.alwaysAsk.rawValue,
            "BITCrashManagerStatus": BITCrashManagerStatus.alwaysAsk.rawValue
            ])

        let hockeyManager = BITHockeyManager.shared()
        hockeyManager.configure(withIdentifier: hockeyAppIdentifier)
        #if DEBUG
            hockeyManager.isUpdateManagerDisabled = true
        #endif
        // Override default crash handling selection
        let crashManager = hockeyManager.crashManager
        crashManager.setAlertViewHandler { [weak self, weak crashManager] () in
            self?.statusAccess.askUserSendApproval(eventType: .crash) { userInput in
                crashManager?.handle(userInput, withUserProvidedMetaData: nil)
            }
        }
        // A bit of user's privacy. Needs to be set before startManager
        hockeyManager.metricsManager.telemetryFilterMask = .session
        hockeyManager.isInstallTrackingDisabled = true
        hockeyManager.start()
        // Authentication goes after startManager
        // https://support.hockeyapp.net/discussions/problems/52830-ios-influence-of-crash-limit-per-application
        hockeyManager.authenticator.identificationType = .anonymous
        hockeyManager.authenticator.authenticateInstallation()
    }
}
