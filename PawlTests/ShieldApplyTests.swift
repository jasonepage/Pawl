// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ShieldApplyTests.swift
//  2.3: re-applying the shield (for example on launch) must not wipe an unlock in progress.
//

import XCTest
@testable import Pawl

final class ShieldApplyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var start: Date { t0.addingTimeInterval(900) }     // wait ends after 15 min
    private var end: Date { start.addingTimeInterval(1800) }   // open for 30 min

    func test_noUnlockInProgress_locks() {
        XCTAssertEqual(ShieldService.applyAction(phase: "locked", windowStart: nil, windowEnd: nil, now: t0), .lock)
    }

    // The bug: a relaunch during the wait set the phase to locked and the countdown vanished.
    func test_duringTheWait_keepsBlockingAndKeepsTheCountdown() {
        XCTAssertEqual(ShieldService.applyAction(phase: "cooling", windowStart: start, windowEnd: end,
                                                 now: t0.addingTimeInterval(60)), .blockKeepCountdown)
    }

    // Worse version: a relaunch during the open window re-blocked everything early.
    func test_duringTheOpenWindow_doesNotReblock() {
        XCTAssertEqual(ShieldService.applyAction(phase: "unshielded", windowStart: start, windowEnd: end,
                                                 now: start.addingTimeInterval(60)), .keepOpen)
        // Also when the monitor lifted late and the phase still says cooling.
        XCTAssertEqual(ShieldService.applyAction(phase: "cooling", windowStart: start, windowEnd: end,
                                                 now: start.addingTimeInterval(5)), .keepOpen)
    }

    // A window that already ended (a missed relock) never keeps anything open.
    func test_staleWindow_locks() {
        XCTAssertEqual(ShieldService.applyAction(phase: "unshielded", windowStart: start, windowEnd: end,
                                                 now: end.addingTimeInterval(1)), .lock)
        XCTAssertEqual(ShieldService.applyAction(phase: "cooling", windowStart: nil, windowEnd: nil,
                                                 now: t0), .lock)
    }
}
