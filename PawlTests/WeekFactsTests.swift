// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class WeekFactsTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 30 * 86_400 + 12 * 3600)   // noon, day 30

    func test_fullWeek_countsEverything() {
        let start = now.addingTimeInterval(-20 * 86_400)
        let unlocks = [
            WeekFacts.Unlock(openedAt: now.addingTimeInterval(-2 * 86_400), closedAt: now.addingTimeInterval(-2 * 86_400 + 1800)),
            WeekFacts.Unlock(openedAt: now.addingTimeInterval(-1 * 86_400), closedAt: now.addingTimeInterval(-1 * 86_400 + 1500)),
            WeekFacts.Unlock(openedAt: now.addingTimeInterval(-10 * 86_400), closedAt: now.addingTimeInterval(-10 * 86_400 + 1800)),   // outside
        ]
        let f = WeekFacts.make(commitmentStart: start, hoursPerDay: 2, unlocks: unlocks,
                               attempts: [now.addingTimeInterval(-3600), now.addingTimeInterval(-9 * 86_400)],
                               urges: [now.addingTimeInterval(-7200)], now: now, calendar: cal)
        XCTAssertEqual(f.daysBlocked, 7)
        XCTAssertEqual(f.daysInWindow, 7)
        XCTAssertEqual(f.unlocks, 2)
        XCTAssertEqual(f.openMinutes, 55)
        XCTAssertEqual(f.hitTheWall, 1)
        XCTAssertEqual(f.urgesRidden, 1)
        XCTAssertEqual(f.hoursBack, 13)   // 2 x 7 = 14, minus 55 min, rounds to 13
    }

    // The first week: only days since the start count as blocked.
    func test_firstWeek_partialDays() {
        let start = now.addingTimeInterval(-2 * 86_400)
        let f = WeekFacts.make(commitmentStart: start, hoursPerDay: 0, unlocks: [], attempts: [], urges: [], now: now, calendar: cal)
        XCTAssertEqual(f.daysBlocked, 3)
        XCTAssertNil(f.hoursBack)
    }

    // An unlock still open counts up to now, not into the future.
    func test_openUnlock_countsToNow() {
        let f = WeekFacts.make(commitmentStart: now.addingTimeInterval(-10 * 86_400), hoursPerDay: 1,
                               unlocks: [WeekFacts.Unlock(openedAt: now.addingTimeInterval(-600), closedAt: now.addingTimeInterval(3000))],
                               attempts: [], urges: [], now: now, calendar: cal)
        XCTAssertEqual(f.openMinutes, 10)
    }

    // Under an hour back is nil, so the view can leave it out instead of saying "0 hr".
    func test_tinyHoursBack_isNil() {
        let f = WeekFacts.make(commitmentStart: now.addingTimeInterval(-10 * 86_400), hoursPerDay: 0.05,
                               unlocks: [], attempts: [], urges: [], now: now, calendar: cal)
        XCTAssertNil(f.hoursBack)
    }
}
