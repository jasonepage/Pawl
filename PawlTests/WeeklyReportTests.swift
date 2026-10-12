// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class WeeklyReportTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
    private func daysAgo(_ n: Int, from now: Date) -> Date {
        cal.date(byAdding: .day, value: -n, to: now)!
    }

    func testSevenDaysOldestFirstEndingToday() {
        let now = date(2026, 10, 12, 15)
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [], urges: [],
                                  attempts: [], completedUnlocks: [], now: now, calendar: cal)
        XCTAssertEqual(r.days.count, 7)
        XCTAssertEqual(r.days.first?.date, cal.startOfDay(for: daysAgo(6, from: now)))
        XCTAssertEqual(r.days.last?.date, cal.startOfDay(for: now))
        XCTAssertEqual(r.daysProtected, 7)
        XCTAssertTrue(r.days.allSatisfy { $0.kind == .protected })
    }

    func testDaysBeforeCommitmentAreMarked() {
        let now = date(2026, 10, 12, 15)
        let start = daysAgo(2, from: now)                      // started the day before yesterday
        let r = WeeklyReport.make(commitmentStart: start, relapses: [], urges: [],
                                  attempts: [], completedUnlocks: [], now: now, calendar: cal)
        XCTAssertEqual(r.daysProtected, 3)
        XCTAssertEqual(r.days.prefix(4).map(\.kind), Array(repeating: .beforeStart, count: 4))
        XCTAssertEqual(r.days.suffix(3).map(\.kind), Array(repeating: .protected, count: 3))
    }

    func testRelapseMarksItsDayAndIsCounted() {
        let now = date(2026, 10, 12, 15)
        let relapse = daysAgo(3, from: now)
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [relapse], urges: [],
                                  attempts: [], completedUnlocks: [], now: now, calendar: cal)
        XCTAssertEqual(r.days[3].kind, .relapse)
        XCTAssertEqual(r.relapsesLogged, 1)
        XCTAssertEqual(r.daysProtected, 7, "a relapse day is still a day the commitment was on")
    }

    func testCountsOnlyInsideTheWindow() {
        let now = date(2026, 10, 12, 15)
        let inside = daysAgo(1, from: now)
        let edge = cal.startOfDay(for: daysAgo(6, from: now))   // first second of the window
        let outside = daysAgo(7, from: now)
        let future = cal.date(byAdding: .hour, value: 2, to: now)!
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now),
                                  relapses: [outside],
                                  urges: [inside, edge, outside],
                                  attempts: [inside, inside, outside, future],
                                  completedUnlocks: [inside, outside],
                                  now: now, calendar: cal)
        XCTAssertEqual(r.urgesLogged, 2)
        XCTAssertEqual(r.attemptsCaught, 2)
        XCTAssertEqual(r.unlocksCompleted, 1)
        XCTAssertEqual(r.relapsesLogged, 0)
        XCTAssertTrue(r.days.allSatisfy { $0.kind == .protected })
    }
}
