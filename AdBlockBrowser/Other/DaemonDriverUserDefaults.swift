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

protocol DaemonStartStoppable: AnyObject {
    var running: Bool { get }

    func start()
    func stop()
}

/**
 Will drive instance of DaemonStartStoppable implementation by current and future (observed)
 NSUserDefaults boolean value. The value key is set in constructor.
 
 Must inherit NSObject because NSNotificationCenter selector requires it.
 */
class DaemonDriverUserDefaults: NSObject {
    fileprivate let defaultsKey: String

    required init(_ defaultsKey: String) {
        self.defaultsKey = defaultsKey
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DaemonDriverUserDefaults.userDefaultsDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    weak var daemon: DaemonStartStoppable? {
        didSet {
            if let daemon = daemon {
                DaemonDriverUserDefaults.checkToggle(daemon, defaultsKey: defaultsKey)
            }
        }
    }

    @objc
    func userDefaultsDidChange(_ notification: Notification) {
        guard
            let myDefault = notification.object as? UserDefaults,
            myDefault === UserDefaults.standard,
            let daemon = daemon else {
                return
        }
        DaemonDriverUserDefaults.checkToggle(daemon, defaultsKey: defaultsKey)
    }

    fileprivate class func checkToggle(_ daemon: DaemonStartStoppable, defaultsKey: String) {
        let newState = UserDefaults.standard.bool(forKey: defaultsKey)
        if newState != daemon.running {
            // switch only when the value is really changed
            if newState {
                daemon.start()
            } else {
                daemon.stop()
            }
        }
    }
}
