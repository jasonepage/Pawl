// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  TimingOptionsTests.swift
//  2.4: "No wait", "Until I lock it", custom times and Lock now.
//

import XCTest
@testable import Pawl

final class TimingOptionsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Limits

    func test_clampCoolingOff_allowsNoWait_andCapsAt24h() {
        XCTAssertEqual(PawlDefaults.clampCoolingOff(0), 0)
        XCTAssertEqual(PawlDefaults.clampCoolingOff(-60), 0)
        XCTAssertEqual(PawlDefaults.clampCoolingOff(5 * 60), 5 * 60)
        XCTAssertEqual(PawlDefaults.clampCoolingOff(30 * 3600), 24 * 3600)
    }

    func test_clampGrace_keepsUntilLocked_andBoundsTimedWindows() {
        XCTAssertEqual(PawlDefaults.clampGrace(PawlDefaults.openUntilLocked), PawlDefaults.openUntilLocked)
        XCTAssertEqual(PawlDefaults.clampGrace(5 * 60), 15 * 60)        // iOS needs 15 min
        XCTAssertEqual(PawlDefaults.clampGrace(4 * 3600), 4 * 3600)
        XCTAssertEqual(PawlDefaults.clampGrace(20 * 3600), 12 * 3600)
    }

    func test_untilLocked_isTheLongestOpenTime() {
        XCTAssertGreaterThan(PawlDefaults.openLength(PawlDefaults.openUntilLocked),
                             PawlDefaults.openLength(PawlDefaults.graceCeiling))
    }

    // MARK: The unlock loop

    func test_noWait_tapStartsAZeroWait() {
        let m = UnlockMachine(coolingOff: 0, grace: 1800)
        let (state, effects) = m.reduce(.reading, .tap(uidMatches: true), now: t0)
        XCTAssertEqual(state, .coolingOff(endsAt: t0))
        XCTAssertEqual(effects, [.scheduleCoolingOff(endsAt: t0)])
    }

    func test_untilLocked_opensWithNoRelockTimer() {
        let m = UnlockMachine(coolingOff: 900, grace: PawlDefaults.openUntilLocked)
        let (state, effects) = m.reduce(.coolingOff(endsAt: t0), .coolingOffEnded, now: t0)
        XCTAssertEqual(state, .unshielded(graceEndsAt: .distantFuture))
        XCTAssertEqual(effects, [.liftShield])
    }

    func test_lockNow_relocksFromAnOpenWindow() {
        let m = UnlockMachine(coolingOff: 900, grace: 1800)
        for open in [UnlockState.unshielded(graceEndsAt: t0.addingTimeInterval(600)),
                     .unshielded(graceEndsAt: .distantFuture)] {
            let (state, effects) = m.reduce(open, .lockNow, now: t0)
            XCTAssertEqual(state, .locked)
            XCTAssertEqual(effects, [.reapplyShield])
        }
    }

    func test_lockNow_doesNothingWhileLockedOrWaiting() {
        let m = UnlockMachine(coolingOff: 900, grace: 1800)
        for s in [UnlockState.locked, .reading, .coolingOff(endsAt: t0.addingTimeInterval(60))] {
            let (state, effects) = m.reduce(s, .lockNow, now: t0)
            XCTAssertEqual(state, s)
            XCTAssertTrue(effects.isEmpty)
        }
    }

    // MARK: The window iOS is asked for

    func test_window_normalWait() {
        let w = UnlockScheduler.window(coolingOff: 900, grace: 1800, now: t0)
        XCTAssertEqual(w.shownStart, t0.addingTimeInterval(900))
        XCTAssertEqual(w.osStart, t0.addingTimeInterval(900))
        XCTAssertEqual(w.osEnd, t0.addingTimeInterval(2700))
    }

    func test_window_noWait_startsTheOSWindowAMinuteOut() {
        let w = UnlockScheduler.window(coolingOff: 0, grace: 1800, now: t0)
        XCTAssertEqual(w.shownStart, t0)
        XCTAssertEqual(w.osStart, t0.addingTimeInterval(UnlockScheduler.minimumLead))
        XCTAssertEqual(w.osEnd, t0.addingTimeInterval(1800))   // relock matches the time shown
    }

    func test_window_untilLocked_asksForTheShortestWindow() {
        let w = UnlockScheduler.window(coolingOff: 900, grace: PawlDefaults.openUntilLocked, now: t0)
        XCTAssertEqual(w.osEnd.timeIntervalSince(w.osStart), PawlDefaults.graceFloor)
    }

    // MARK: Relaunch and reminders

    func test_relaunch_untilLocked_staysOpenPastTheWindow() {
        let long = t0.addingTimeInterval(5 * 3600)   // hours after the 15 min window ended
        XCTAssertEqual(ShieldService.applyAction(phase: "unshielded", windowStart: t0,
                                                 windowEnd: t0.addingTimeInterval(900), now: long,
                                                 openUntilLocked: true), .keepOpen)
        XCTAssertEqual(ShieldService.applyAction(phase: "unshielded", windowStart: t0,
                                                 windowEnd: t0.addingTimeInterval(900), now: long,
                                                 openUntilLocked: false), .lock)
    }

    func test_reminders_untilLocked_haveNoLockReminders() {
        let opens = t0.addingTimeInterval(900)
        let r = UnlockReminders.plan(opensAt: opens, locksAt: nil, now: t0, timeText: { _ in "5:00 PM" })
        XCTAssertEqual(r.map(\.title), ["Apps open in 5 minutes", "Apps open in 1 minute", "Your apps are open"])
        XCTAssertEqual(r.last?.body, "They stay open until you tap Lock now in Pawl.")
    }

    // MARK: Words on screen

    func test_durationText() {
        XCTAssertEqual(DurationText.wait(seconds: 0), "No wait")
        XCTAssertEqual(DurationText.wait(seconds: 5 * 60), "5 min")
        XCTAssertEqual(DurationText.open(seconds: PawlDefaults.openUntilLocked), "Until I lock it")
        XCTAssertEqual(DurationText.short(minutes: 90), "1.5 hr")
        XCTAssertEqual(DurationText.short(minutes: 130), "2 hr 10 min")
        XCTAssertEqual(DurationText.startsIn(waitSeconds: 0), "now")
        XCTAssertEqual(DurationText.startsIn(waitSeconds: 900), "in 15 min")
        XCTAssertEqual(DurationText.summary(waitSeconds: 0, openSeconds: PawlDefaults.openUntilLocked),
                       "No wait, then open until you lock it")
        XCTAssertEqual(DurationText.summary(waitSeconds: 900, openSeconds: 1800),
                       "15 min wait, then open for 30 min")
    }
}
