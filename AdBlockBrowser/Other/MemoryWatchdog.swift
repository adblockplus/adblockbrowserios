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

/**
 Repeated query of memory status (@see Sys.memoryUsage).
 Resulting values provided via callback onMemoryValuesAvailable.
 Can be stopped/started again.
 */
public final class MemoryValues: NSObject {
    public let resident: Int64
    public let allowed: Int64
    public let physical: Int64

    public init(resident: Int64, allowed: Int64, physical: Int64) {
        self.resident = resident
        self.allowed = allowed
        self.physical = physical
    }
}

final class MemoryWatchdog: NSObject, DaemonStartStoppable {
    // Last value sent out on callback
    @objc dynamic var lastRecordedValues: MemoryValues?
    // Private state
    private let queue = DispatchQueue.global(qos: .background)
    private let timer: DispatchSourceTimer

    // @param interval timer
    // @param changeThreshold bytes difference needed for the callback to be fired
    required init(interval: TimeInterval, changeBytesThreshold: Int64) {
        timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: queue)
        super.init()

        timer.schedule(deadline: DispatchTime.init(uptimeNanoseconds: UInt64(100000)),
                       repeating: DispatchTimeInterval.seconds(Int(interval)),
                       leeway: DispatchTimeInterval.seconds(0))
        timer.setEventHandler(handler: makeTimerEventHandler(changeBytesThreshold))
    }

    deinit {
        stop()
    }

    private func makeTimerEventHandler(_ changeThreshold: Int64) -> () -> Void {
        return { [weak self] in
            let usage = Sys.memoryUsage()
            if let lastValues = self?.lastRecordedValues {
                // invoke callback and value replacing only if at least one value
                // was changed substantially
                if abs(usage.resident - lastValues.resident) > changeThreshold ||
                    abs(usage.allowed - lastValues.allowed) > changeThreshold {
                    self?.set(values: usage)
                }
            }
        }
    }

    private func set(values: Sys.MemoryValues?) {
        DispatchQueue.main.async { [weak self] () in
            self?.lastRecordedValues = values.map { (value) in
                MemoryValues(resident: value.resident, allowed: value.allowed, physical: value.physical)
            }
        }
    }

    // MARK: - DaemonStartStoppable

    private(set) var running = false

    func start() {
        // Reset last values so that the first new value is picked up
        set(values: (0, 0, 0))
        timer.resume()
        running = true
    }

    func stop() {
        running = false
        timer.suspend()
        set(values: nil)
    }
}
