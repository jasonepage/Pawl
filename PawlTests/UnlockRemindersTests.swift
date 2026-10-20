// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class UnlockRemindersTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func plan(waitMin: Double, openMin: Double, startedAgo: Double = 0) -> [UnlockReminders.Reminder] {
        let start = now.addingTimeInterval(-startedAgo * 60)
        let opens = start.addingTimeInterval(waitMin * 60)
        return UnlockReminders.plan(opensAt: opens, locksAt: opens.addingTimeInterval(openMin * 60),
                                    now: now, timeText: { _ in "5:00 PM" })
    }

    func test_fullUnlockGetsSixRemindersInOrder() {
        let r = plan(waitMin: 15, openMin: 30)
        XCTAssertEqual(r.map(\.title), ["Apps open in 5 minutes", "Apps open in 1 minute", "Your apps are open",
                                        "Apps lock again in 5 minutes", "Apps lock again in 1 minute",
                                        "Apps are locked again"])
        XCTAssertEqual(r.map(\.at), r.map(\.at).sorted())
        XCTAssertEqual(r[2].body, "They lock again at 5:00 PM.")
    }

    func test_remindersAlreadyPastAreLeftOut() {
        // 12 minutes into a 15 minute wait: the 5-minute warning is already past.
        let r = plan(waitMin: 15, openMin: 30, startedAgo: 12)
        XCTAssertFalse(r.contains { $0.title == "Apps open in 5 minutes" })
        XCTAssertTrue(r.contains { $0.title == "Apps open in 1 minute" })
    }

    // 2.3 fix: when an unlock ends or changes early, only Pawl's reminders that are still
    // more than a few seconds away get removed. One due right now stays, so the normal
    // "Apps are locked again" still shows at the end of a real unlock.
    func test_idsToClear_dropsFutureKeepsDueNowAndIgnoresOthers() {
        let ids = ["pawl.unlock.open5", "pawl.unlock.lock5", "pawl.unlock.lock0"]
        let pending: [(id: String, fireDate: Date?)] = [
            (id: "pawl.unlock.open5", fireDate: now.addingTimeInterval(600)),   // future: clear
            (id: "pawl.unlock.lock5", fireDate: nil),                           // no date: clear
            (id: "pawl.unlock.lock0", fireDate: now.addingTimeInterval(2)),     // due now: keep
            (id: "someone.else", fireDate: now.addingTimeInterval(600)),        // not Pawl's: keep
        ]
        XCTAssertEqual(UnlockReminders.idsToClear(pending: pending, ids: ids, now: now),
                       ["pawl.unlock.open5", "pawl.unlock.lock5"])
    }

    // Moving the lock reminders (open time started early) uses only the lock half of the plan.
    func test_lockOnlyPlanHasJustTheLockReminders() {
        let locksAt = now.addingTimeInterval(30 * 60)
        let r = UnlockReminders.plan(opensAt: .distantPast, locksAt: locksAt, now: now,
                                     timeText: { _ in "5:00 PM" })
        XCTAssertEqual(r.map(\.id), ["pawl.unlock.lock5", "pawl.unlock.lock1", "pawl.unlock.lock0"])
    }
}
