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

import DBAlertController
import Foundation

#if canImport(Crashlytics)
import Crashlytics
#endif
#if canImport(Fabric)
import Fabric
#endif

// abstract the logger implementation type and make the logging invocations reasonably short
typealias Log = LoggingManager

let defaultsKeyCrashReportingStatus = "CrashReportingStatus"

enum CrashReportingStatus: Int {
    case always
    case never
    case ask
}

enum CrashReportType: Int {
    case crash
    case error
}

class FabricManager: NSObject, CrashlyticsDelegate {

    static let shared = FabricManager()

    #if DEVBUILD_FEATURES
        let watchdog = MemoryWatchdog(interval: 0.5, changeBytesThreshold: 1024 * 1024)
        let driver = DaemonDriverUserDefaults(defaultsKeyShowMemoryPressure)
    #endif

    private override init() {}

    var crashReportingStatus: CrashReportingStatus {
        get {
            if UserDefaults.standard.value(forKey: defaultsKeyCrashReportingStatus) != nil {
                return CrashReportingStatus(rawValue: UserDefaults.standard.integer(forKey: defaultsKeyCrashReportingStatus))!
            } else {
                return .ask
            }
        }
        set (status) {
            UserDefaults.standard.set(status.rawValue, forKey: defaultsKeyCrashReportingStatus)
        }
    }

    func setup() {

        // Setup the logger.
        LoggingManager.createInstance()
        KittCoreLogger.loggerSinkType = LoggingManager.self

        #if DEVBUILD_FEATURES
            DevSettingsViewController.setDefaultShowMemoryPressure()
            driver.daemon = watchdog
        #endif

        // Then if possible, activate Crash Reporting.
        #if canImport(Fabric)
        if FabricManager.fabricKeyIsPresent() {
            Crashlytics.sharedInstance().delegate = self
            UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
            Fabric.with([Crashlytics.self()])
        }
        #endif
    }

    func status(from index: Int) -> CrashReportingStatus? {
        switch index {
        case 0:
            return .always
        case 1:
            return .never
        case 2:
            return .ask
        default:
            return nil
        }
    }

    func title(for status: CrashReportingStatus) -> String {
        switch status {
        case .always:
            return localize("Always", comment: "Crash/Error reports settings")
        case .never:
            return localize("Never", comment: "Crash/Error reports settings")
        case .ask:
            return localize("Ask Me After a Crash or Error", comment: "Crash/Error reports settings")
        }
    }

    func forwardErrorToManager(error: Error) {
        switch crashReportingStatus {
        case .always:
            self.sendError(error: error)
        case .never:
            return
        case .ask:
            promptUserToSendReport(for: .error) { shouldSend in
                if shouldSend {
                    self.sendError(error: error)
                }
            }
        }
    }

    // MARK: - private
    private class func fabricKeyIsPresent() -> Bool {
        guard let fabricDict = Bundle.main.object(forInfoDictionaryKey: "Fabric") as? [String: AnyObject] else { return false }
        return fabricDict["APIKey"] != nil
    }

    private func promptUserToSendReport(for type: CrashReportType, completionHandler: @escaping (Bool) -> Void) {

        // Creates an Alert Controller that will be used to ask the user if they wish to
        // submit the report from the previous crash/error.

        let title: String
        let message: String
        var actions = [UIAlertAction]()

        let send = UIAlertAction(title: localize("Send Report",
                                                 comment: "Crash/Error Report Sending Modal"),
                                 style: .default) { _ in
                                    completionHandler(true)
        }
        actions.append(send)

        let dontSend = UIAlertAction(title: localize("Don't Send",
                                                     comment: "Crash/Error Report Sending Modal"),
                                     style: .default) { _ in
                                        completionHandler(false)
        }
        actions.append(dontSend)

        switch type {
        case .crash:
            title = localize("Adblock Unexpectedly Quit",
                             comment: "Crash/Error Report Sending Modal")
            message = localize("Would you like to send a report to fix the problem?",
                               comment: "Crash/Error Report Sending Modal")

            let alwaysSend = UIAlertAction(title: localize("Always Send",
                                                           comment: "Crash/Error Report Sending Modal"),
                                           style: .default) { _ in
                                            FabricManager.shared.crashReportingStatus = .always
                                            completionHandler(true)
            }
            actions.append(alwaysSend)

        case .error:
            title = Utils.applicationName()
            message = localize("Unable to start browser.", comment: "Critical abort alert message")
        }

        let alert = DBAlertController(title: title, message: message, preferredStyle: .alert)
        for action in actions {
            alert.addAction(action)
        }

        alert.show()
    }

    private func sendError(error: Error) {
        #if canImport(Fabric)
        // Log the error to be sent on next launch.
        Crashlytics.sharedInstance().recordError(error)
        #endif
    }

    // MARK: - CrashlyticsDelegate
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {

        // Because we need to ensure that the user's crash reports are ONLY sent with the
        // user's consent, we either do, don't, or ask to send the crash report depending on
        // the user's preference. Default is ASK.

        let status = FabricManager.shared.crashReportingStatus
        switch status {
        case .always:
            completionHandler(true)
        case .never:
            completionHandler(false)
        case .ask:
            promptUserToSendReport(for: .crash) { shouldSend in
                completionHandler(shouldSend)
            }
        }
    }
}
