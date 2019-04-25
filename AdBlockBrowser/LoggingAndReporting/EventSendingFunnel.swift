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

public protocol EventSender {
    func send(event: StringCodeConvertibleError)
    func send(events: [StringCodeConvertibleError])
}

public struct EventBacklogEntry: Equatable {
    let event: StringCodeConvertibleError
    let count: UInt
    // NSTimeInterval more practical than NSDate on testing and arithmetic
    let last: TimeInterval

    init(event: StringCodeConvertibleError, count: UInt, last: TimeInterval? = nil) {
        self.event = event
        self.count = count
        self.last = last ?? NSDate.timeIntervalSinceReferenceDate
    }
}

/// Equatable needed for XCTestAssertEqual
public func == (lhs: EventBacklogEntry, rhs: EventBacklogEntry) -> Bool {
    return lhs.event.shortCode == rhs.event.shortCode && lhs.count == rhs.count
}

public typealias EventBacklogType = [EventBacklogEntry]

/**
 Logging of events to HockeyApp service has required restrictions:

 A. should happen only with user's consent
 Ensured by observing HA crash status, presenting the consent dialog
 the same way as with crash reports, and updating the status accordingly

 B. should happen rather sparsely and with moderate data size
 Ensured by funneling the events into a backlog: grouping equal event types,
 and sending only set top number of them, and not more often than a set timeout.

 Implementation:

 1. registers events for the required timeout
 2. optionally asks for approval after the timeout
 3. while the approval is pending, keeps registering events
 4. if not approved, keep registering events until next timeout
 (memory consumption is negligible)
 5. makes an event batch of permitted size from the backlog and sends it out
 6. clears the backlog and restarts timeout
 */
public final class EventSendingFunnel {
    /// The event backlog declaration
    public var backlog = EventBacklogType()

    private var statusAccess: EventHandlingStatusAccess
    private let eventSender: EventSender
    private let reportingTimeoutSecs: UInt64
    private let reportingEventCount: Int

    /// true if the timeout since last sending is still elapsing
    private var isTimerRunning = false

    /// true if timeout elapsed but the user still didn't dismiss the consent dialog
    private var isWaitingOnApproval = false

    /**
     - parameters
         - statusAccess: the provider of HA crash report status
         - eventSender: the provider of logged event sending
         - reportingTimeoutSecs: the shortest time between error sending batches (and consent UI appearance, optionally)
         - reportingEventCount: the max number of events sent to HA service
    */
    init(statusAccess: EventHandlingStatusAccess, eventSender: EventSender, reportingTimeoutSecs: UInt64, reportingEventCount: Int) {
        self.statusAccess = statusAccess
        self.eventSender = eventSender
        self.reportingTimeoutSecs = reportingTimeoutSecs
        self.reportingEventCount = reportingEventCount
    }

    /// - parameter forcedRegisteringCompletion: if set, will send error regardless of
    /// crash reporting status and call the block
    func register(error: StringCodeConvertibleError, forcedRegisteringCompletion: (() -> Void)? = nil) {
        if statusAccess.eventHandlingStatus == .disabled {
            return
        }
        // May invoke UI activity and/or call into HockeyApp SDK
        // so ensure execution on main thread
        if Thread.isMainThread {
            registerImplementation(error: error, forcedRegisteringCompletion)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.registerImplementation(error: error, forcedRegisteringCompletion)
            }
        }
    }

    private func registerImplementation(error: StringCodeConvertibleError, _ forcedRegisteringCompletion: (() -> Void)?) {
        assert(Thread.isMainThread)
        if let index = backlog.firstIndex(where: { $0.event.shortCode == error.shortCode }) {
            // event code already registered, increment grouping count
            let entry = backlog[index]
            backlog[index] = EventBacklogEntry(event: entry.event, count: entry.count + 1)
        } else {
            // event code not registered yet, make fresh entry
            backlog.append(EventBacklogEntry(event: error, count: 1))
        }
        if let registeringCompletion = forcedRegisteringCompletion {
            // Approval forced
            approvalHandler(approved: true, registeringCompletion)
            return
        }
        // Consult timing and approval only if no forced registering
        if !isTimerRunning && !isWaitingOnApproval {
            // Start approval/sending only if timer has elapsed
            // and the previous approval is not waiting still
            // The only use case: the first error after error-free timeout.
            // If there were errors during timeout, sending is invoked right after elapsing
            // @see startTimer
            sendIfApproved()
        }
    }

    private func sendIfApproved() {
        isWaitingOnApproval = true
        statusAccess.askUserSendApproval(eventType: .recoverableError) { [weak self] userInput in
            self?.isWaitingOnApproval = false
            self?.approvalHandler(approved: userInput != .dontSend, nil)
        }
    }

    private func approvalHandler(approved: Bool, _ registeringCompletion: (() -> Void)?) {
        if approved {
            let events = EventSendingFunnel.distill(backlog: backlog, toMaxCount: reportingEventCount)
            eventSender.send(events: events)
        }
        // Clear the backlog regardless of approval. If it was approved, errors are obsolete now.
        // If it was rejected, the user does not want to hear about them anymore
        // (the confirmation would keep popping up otherwise).
        backlog.removeAll()
        if let completion = registeringCompletion {
            completion()
            return
        }
        // Reset the timer for next approval only if there is no registering completion.
        // The block may be producing its own dialog which must not get interfered with.
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(reportingTimeoutSecs), qos: .background) {
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else {
                    return
                }
                sSelf.isTimerRunning = false
                // if there are events in backlog, invoke sending right away
                if sSelf.backlog.count > 0 {
                    sSelf.sendIfApproved()
                }
            }
        }
        isTimerRunning = true
    }

    /**
     The current crippled HA "user event logging" facility allows to log just
     a dimensionless string. It can't report number of occurences. So if an error
     occurs many times, the only option is to report the same string as many times
     as possible. As we can't send ALL errors registered in given timeout
     (see restriction B), the distillation will potentially throw away the less
     frequent errors.
     */
    public static func distill(backlog: EventBacklogType, toMaxCount limit: Int) -> [StringCodeConvertibleError] {
        // Sorting criteria:
        // 1. most occurences first
        // 2. newest occurence first
        let sorted = backlog.sorted {
            $0.count > $1.count || $0.last > $1.last
        }
        // Intermediate structure:
        // First goes one entry per each registered error type (count ignored)
        // To know that the type is occuring at all
        var entries = sorted.map { $0.event }
        // Follows expanded events, by sorting order, as much as there is count of it
        for entry in sorted {
            // Initial entries may have already exceeded the limit
            if entries.count >= limit {
                break
            }
            for _ in 1..<entry.count {
                entries.append(entry.event)
            }
        }
        // Finally cut off the event count at allowed limit and return just the codes
        return Array(entries[0..<min(entries.count, limit)])
    }
}
