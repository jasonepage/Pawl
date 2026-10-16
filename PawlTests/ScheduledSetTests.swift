// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class ScheduledSetTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    /// 2026-10-12 is a Monday.
    private func monday(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: h, minute: m))!
    }
    private func sunday(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: h, minute: m))!
    }

    func testWeekdayWindow() {
        let work = ScheduledSet(name: "Work", weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 17 * 60)
        XCTAssertTrue(work.isActive(at: monday(9), calendar: cal))
        XCTAssertTrue(work.isActive(at: monday(16, 59), calendar: cal))
        XCTAssertFalse(work.isActive(at: monday(17), calendar: cal), "end is exclusive")
        XCTAssertFalse(work.isActive(at: monday(8, 59), calendar: cal))
        XCTAssertFalse(work.isActive(at: sunday(12), calendar: cal), "not a weekday")
        XCTAssertEqual(work.coverage.count, 5 * 8 * 60)
    }

    func testOvernightWindowCrossesMidnight() {
        // Sunday 22:00 to 06:00 covers early Monday morning.
        let night = ScheduledSet(name: "Night", weekdays: [1], startMinute: 22 * 60, endMinute: 6 * 60)
        XCTAssertTrue(night.isActive(at: sunday(23), calendar: cal))
        XCTAssertTrue(night.isActive(at: monday(5, 59), calendar: cal))
        XCTAssertFalse(night.isActive(at: monday(6), calendar: cal))
        XCTAssertFalse(night.isActive(at: sunday(21, 59), calendar: cal))
        XCTAssertEqual(night.coverage.count, 8 * 60)
    }

    func testDisabledOrNoDaysIsNeverActive() {
        var s = ScheduledSet(name: "x", weekdays: [1, 2, 3, 4, 5, 6, 7], startMinute: 0, endMinute: 23 * 60 + 59)
        s.isEnabled = false
        XCTAssertFalse(s.isActive(at: monday(12), calendar: cal))
        XCTAssertTrue(s.coverage.isEmpty)
        var none = ScheduledSet(name: "y", weekdays: [], startMinute: 0, endMinute: 60)
        none.isEnabled = true
        XCTAssertFalse(none.isActive(at: monday(0, 30), calendar: cal))
    }

    func testLooseningRules() {
        let base = ScheduledSet(name: "Work", weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 17 * 60)

        var longer = base; longer.endMinute = 18 * 60
        XCTAssertFalse(ScheduledSet.isLoosening(old: base, new: longer), "more hours is tightening")

        var moreDays = base; moreDays.weekdays.insert(7)
        XCTAssertFalse(ScheduledSet.isLoosening(old: base, new: moreDays))

        var shorter = base; shorter.endMinute = 16 * 60
        XCTAssertTrue(ScheduledSet.isLoosening(old: base, new: shorter))

        var fewerDays = base; fewerDays.weekdays.remove(6)
        XCTAssertTrue(ScheduledSet.isLoosening(old: base, new: fewerDays))

        var off = base; off.isEnabled = false
        XCTAssertTrue(ScheduledSet.isLoosening(old: base, new: off))

        var shifted = base; shifted.startMinute = 10 * 60; shifted.endMinute = 18 * 60
        XCTAssertTrue(ScheduledSet.isLoosening(old: base, new: shifted), "a shift drops 9 to 10, so it waits")

        var renamed = base; renamed.name = "Office"
        XCTAssertFalse(ScheduledSet.isLoosening(old: base, new: renamed))
    }

    func testRoundTripsThroughJSON() throws {
        let s = ScheduledSet(name: "Evenings", weekdays: [1, 7], startMinute: 20 * 60, endMinute: 23 * 60, isEnabled: true)
        let data = try JSONEncoder().encode([s])
        let back = try JSONDecoder().decode([ScheduledSet].self, from: data)
        XCTAssertEqual(back, [s])
    }
}
