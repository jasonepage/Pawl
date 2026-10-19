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

    // MARK: - 2.3: day counts, hardest time, common trigger

    func testEachDayCarriesItsOwnUrgeAndAttemptCounts() {
        let now = date(2026, 10, 12, 15)
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [],
                                  urges: [date(2026, 10, 11, 9), date(2026, 10, 11, 20)],
                                  attempts: [date(2026, 10, 12, 8), date(2026, 10, 12, 9), date(2026, 10, 12, 10)],
                                  completedUnlocks: [], now: now, calendar: cal)
        XCTAssertEqual(r.days[5].urges, 2)       // Oct 11
        XCTAssertEqual(r.days[5].attempts, 0)
        XCTAssertEqual(r.days[6].attempts, 3)    // today, Oct 12
        XCTAssertEqual(r.days[6].urges, 0)
        XCTAssertEqual(r.days.prefix(5).map(\.urges), [0, 0, 0, 0, 0])
    }

    func testHardestTimeNeedsAClearWinner() {
        let now = date(2026, 10, 12, 15)
        // Three late-night moments and one morning one: late night wins.
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [],
                                  urges: [date(2026, 10, 10, 23), date(2026, 10, 12, 1), date(2026, 10, 11, 10)],
                                  attempts: [date(2026, 10, 11, 23)],
                                  completedUnlocks: [], now: now, calendar: cal)
        XCTAssertEqual(r.hardestTime, .lateNight)

        // Fewer than three moments: nothing to say.
        let few = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [],
                                    urges: [date(2026, 10, 10, 23), date(2026, 10, 11, 23)],
                                    attempts: [], completedUnlocks: [], now: now, calendar: cal)
        XCTAssertNil(few.hardestTime)

        // A tie: nothing to say.
        let tie = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [],
                                    urges: [date(2026, 10, 10, 9), date(2026, 10, 11, 9),
                                            date(2026, 10, 10, 19), date(2026, 10, 11, 19)],
                                    attempts: [], completedUnlocks: [], now: now, calendar: cal)
        XCTAssertNil(tie.hardestTime)
    }

    func testTimeOfDayBuckets() {
        XCTAssertEqual(WeeklyReport.TimeOfDay(hour: 4), .lateNight)
        XCTAssertEqual(WeeklyReport.TimeOfDay(hour: 5), .morning)
        XCTAssertEqual(WeeklyReport.TimeOfDay(hour: 12), .afternoon)
        XCTAssertEqual(WeeklyReport.TimeOfDay(hour: 17), .evening)
        XCTAssertEqual(WeeklyReport.TimeOfDay(hour: 22), .lateNight)
    }

    func testCommonTriggerIsTrimmedLowercasedAndNeedsTwo() {
        let now = date(2026, 10, 12, 15)
        let r = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [], urges: [],
                                  attempts: [], completedUnlocks: [],
                                  triggers: [(date(2026, 10, 10), "Stressed"), (date(2026, 10, 11), " stressed "),
                                             (date(2026, 10, 12, 9), "bored")],
                                  now: now, calendar: cal)
        XCTAssertEqual(r.commonTrigger, "stressed")

        let once = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [], urges: [],
                                     attempts: [], completedUnlocks: [],
                                     triggers: [(date(2026, 10, 10), "bored"), (date(2026, 10, 11), "lonely")],
                                     now: now, calendar: cal)
        XCTAssertNil(once.commonTrigger)

        // A trigger from before this week does not count.
        let old = WeeklyReport.make(commitmentStart: daysAgo(30, from: now), relapses: [], urges: [],
                                    attempts: [], completedUnlocks: [],
                                    triggers: [(date(2026, 9, 1), "bored"), (date(2026, 10, 11), "bored")],
                                    now: now, calendar: cal)
        XCTAssertNil(old.commonTrigger)
    }
}
