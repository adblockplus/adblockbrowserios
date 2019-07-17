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

class FabricWrapper {

    class func setup() {
        #if canImport(Fabric)
        if FabricWrapper.fabricKeyIsPresent() {
            UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
            Fabric.with([Crashlytics.self()])
        }
        #endif
    }

    private class func fabricKeyIsPresent() -> Bool {
        guard let fabricDict = Bundle.main.object(forInfoDictionaryKey: "Fabric") as? [String: AnyObject] else { return false }
        return fabricDict["APIKey"] != nil
    }
}
