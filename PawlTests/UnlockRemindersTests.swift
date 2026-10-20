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
}
