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

#if canImport(Crashlytics)
import Crashlytics
#endif
#if canImport(Fabric)
import Fabric
#endif

let defaultsKeyCrashReportingStatus = "CrashReportingStatus"

enum CrashReportingStatus: Int {
    case always
    case never
    case ask
}

class FabricManager: NSObject, CrashlyticsDelegate {

    static let shared = FabricManager()

    private override init() {}

    var crashReportingStatus: CrashReportingStatus {
        get {
            if UserDefaults.standard.value(forKey: defaultsKeyCrashReportingStatus) != nil {
                print(UserDefaults.standard.integer(forKey: defaultsKeyCrashReportingStatus))
                return CrashReportingStatus(rawValue: UserDefaults.standard.integer(forKey: defaultsKeyCrashReportingStatus))!
            } else {
                return .ask
            }
        }
        set (status) {
            UserDefaults.standard.set(status.rawValue, forKey: defaultsKeyCrashReportingStatus)
            print(UserDefaults.standard.integer(forKey: defaultsKeyCrashReportingStatus))
        }
    }

    func setup() {
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

    func promptUserToSendReport() -> Bool {
        //TODO:
        return false
    }

    // MARK: - private
    private class func fabricKeyIsPresent() -> Bool {
        guard let fabricDict = Bundle.main.object(forInfoDictionaryKey: "Fabric") as? [String: AnyObject] else { return false }
        return fabricDict["APIKey"] != nil
    }

    // MARK: - CrashlyticsDelegate
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        let status = FabricManager.shared.crashReportingStatus
        switch status {
        case .always:
            completionHandler(true)
        case .never:
            completionHandler(false)
        case .ask:
            promptUserToSendReport()
        default:
            <#code#>
        }
    }
}
