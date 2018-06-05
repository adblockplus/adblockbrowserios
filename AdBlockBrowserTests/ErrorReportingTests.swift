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

@testable import AdblockBrowser
import XCTest

class ErrorReportingTests: XCTestCase {
    enum TestError: String, StringCodeConvertibleError {
        case caseA
        case caseB
        case caseC

        var shortCode: String {
            return "Test_\(rawValue)Error"
        }
    }

    class TestCrashStatusAccess: EventHandlingStatusAccess {
        let approvalStatus: EventHandlingStatus
        var willApprove: Bool

        init(approvalStatus: EventHandlingStatus, willApprove: Bool) {
            self.approvalStatus = approvalStatus
            self.willApprove = willApprove
        }

        var eventHandlingStatus: EventHandlingStatus {
            get { return approvalStatus }
            set { }
        }

        public func askUserSendApproval(eventType: EventType, userInputHandler: @escaping UserInputHandler) {
            switch approvalStatus {
            case .disabled:
                userInputHandler(.dontSend)
            case .autoSend:
                userInputHandler(.alwaysSend)
            case .alwaysAsk:
                userInputHandler(willApprove ? .send : .dontSend)
            }
        }
    }

    struct TestEventSender: EventSender {
        // expectation nil: not expected to be called
        let callExpectation: XCTestExpectation?
        let dataExpectation: [StringCodeConvertibleError]

        func send(event: StringCodeConvertibleError) {
        }

        func send(events: [StringCodeConvertibleError]) {
            if let callExpectation = callExpectation {
                callExpectation.fulfill()
                XCTAssertEqual(events.map { $0.shortCode }, dataExpectation.map { $0.shortCode })
            } else {
                XCTFail("Event Sender Failed")
            }
        }
    }

    func testBacklog() {
        let statusAccess = TestCrashStatusAccess(approvalStatus: .alwaysAsk, willApprove: false)
        let eventSender = TestEventSender(callExpectation: nil, dataExpectation: [])
        let funnel = EventSendingFunnel(statusAccess: statusAccess, eventSender: eventSender, reportingTimeoutSecs: 0, reportingEventCount: 10)
        funnel.register(error: TestError.caseA)
        statusAccess.willApprove = true
        // create
        funnel.register(error: TestError.caseA)
        XCTAssertEqual(funnel.backlog, [
            EventBacklogEntry(event: TestError.caseA, count: 1)
            ])
        // create other
        funnel.register(error: TestError.caseB)
        XCTAssertEqual(funnel.backlog, [
            EventBacklogEntry(event: TestError.caseA, count: 1),
            EventBacklogEntry(event: TestError.caseB, count: 1)
            ])
        // update
        funnel.register(error: TestError.caseA)
        XCTAssertEqual(funnel.backlog, [
            EventBacklogEntry(event: TestError.caseA, count: 2),
            EventBacklogEntry(event: TestError.caseB, count: 1)
            ])
    }

    private func sendExpectedHelper(_ statusAccess: EventHandlingStatusAccess, _ forcedRegisteringCompletion: (() -> Void)? = nil) {
        let callExpectation = expectation(description: "Event send")
        let event = TestError.caseA
        let eventSender = TestEventSender(callExpectation: callExpectation, dataExpectation: [event])
        let funnel = EventSendingFunnel(statusAccess: statusAccess, eventSender: eventSender, reportingTimeoutSecs: 0, reportingEventCount: 10)
        funnel.register(error: event, forcedRegisteringCompletion: forcedRegisteringCompletion)
    }

    private func sendNotExpectedHelper(_ statusAccess: EventHandlingStatusAccess, _ forcedRegisteringCompletion: (() -> Void)? = nil) {
        let eventSender = TestEventSender(callExpectation: nil, dataExpectation: [])
        let funnel = EventSendingFunnel(statusAccess: statusAccess, eventSender: eventSender, reportingTimeoutSecs: 0, reportingEventCount: 10)
        funnel.register(error: TestError.caseA, forcedRegisteringCompletion: forcedRegisteringCompletion)
    }

    func testSending() {
        sendExpectedHelper(TestCrashStatusAccess(approvalStatus: .autoSend, willApprove: true))
        sendExpectedHelper(TestCrashStatusAccess(approvalStatus: .alwaysAsk, willApprove: true))
        sendNotExpectedHelper(TestCrashStatusAccess(approvalStatus: .alwaysAsk, willApprove: false))
        sendNotExpectedHelper(TestCrashStatusAccess(approvalStatus: .disabled, willApprove: false))
        waitForExpectations(timeout: TimeInterval(0), handler: nil)
    }

    func testForcedSending() {
        let forcedCompletionExpectation = expectation(description: "Forced completion")
        sendExpectedHelper(TestCrashStatusAccess(approvalStatus: .autoSend, willApprove: true), { () in
            forcedCompletionExpectation.fulfill()
        })
        sendNotExpectedHelper(TestCrashStatusAccess(approvalStatus: .disabled, willApprove: false), { () in })
        waitForExpectations(timeout: TimeInterval(0), handler: nil)
    }

    func testDistiller() {
        var input: EventBacklogType
        var output: [TestError]
        var distilled: [StringCodeConvertibleError]
        // single event
        input = [
            EventBacklogEntry(event: TestError.caseA, count: 1)
        ]
        output = [TestError.caseA]
        distilled = EventSendingFunnel.distill(backlog: input, toMaxCount: 3)
        XCTAssertEqual(distilled.map { $0.shortCode }, output.map { $0.shortCode })
        // multiple events but not more than max
        input = [
            EventBacklogEntry(event: TestError.caseA, count: 1),
            EventBacklogEntry(event: TestError.caseB, count: 2)
        ]
        output = [TestError.caseB, TestError.caseA, TestError.caseB ]
        distilled = EventSendingFunnel.distill(backlog: input, toMaxCount: 3)
        XCTAssertEqual(distilled.map { $0.shortCode }, output.map { $0.shortCode })
        // multiple events but more than max
        input = [
            EventBacklogEntry(event: TestError.caseA, count: 1),
            EventBacklogEntry(event: TestError.caseB, count: 3)
        ]
        output = [TestError.caseB, TestError.caseA, TestError.caseB]
        distilled = EventSendingFunnel.distill(backlog: input, toMaxCount: 3)
        XCTAssertEqual(distilled.map { $0.shortCode }, output.map { $0.shortCode })
        // various events of same count but different times
        input = [
            EventBacklogEntry(event: TestError.caseA, count: 1, last: TimeInterval(0)),
            EventBacklogEntry(event: TestError.caseB, count: 1, last: TimeInterval(1)),
            EventBacklogEntry(event: TestError.caseC, count: 1, last: TimeInterval(2))
        ]
        output = [TestError.caseC, TestError.caseB, TestError.caseA]
        distilled = EventSendingFunnel.distill(backlog: input, toMaxCount: 3)
        XCTAssertEqual(distilled.map { $0.shortCode }, output.map { $0.shortCode })
        // various events, more than max
        input = [
            EventBacklogEntry(event: TestError.caseA, count: 2, last: TimeInterval(0)),
            EventBacklogEntry(event: TestError.caseB, count: 2, last: TimeInterval(1)),
            EventBacklogEntry(event: TestError.caseC, count: 2, last: TimeInterval(2))
        ]
        output = [ TestError.caseC, TestError.caseB, TestError.caseA, TestError.caseC, TestError.caseB]
        distilled = EventSendingFunnel.distill(backlog: input, toMaxCount: 5)
        XCTAssertEqual(distilled.map { $0.shortCode }, output.map { $0.shortCode })
    }
}
