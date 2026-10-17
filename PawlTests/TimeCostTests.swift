// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class TimeCostTests: XCTestCase {
    func testArithmetic() {
        XCTAssertEqual(TimeCost.hoursPerYear(hoursPerDay: 2), 730)
        XCTAssertEqual(TimeCost.daysPerYear(hoursPerDay: 2), 30)
        XCTAssertEqual(TimeCost.hoursPerYear(hoursPerDay: 0), 0)
        XCTAssertEqual(TimeCost.hoursPerYear(hoursPerDay: -3), 0)
    }

    func testSentence() {
        XCTAssertEqual(TimeCost.sentence(hoursPerDay: 1), "1 hour a day is about 365 hours a year, or 15 full days.")
        // 2.5 x 365 = 912.5, and .rounded() takes a half up, so 913.
        XCTAssertEqual(TimeCost.sentence(hoursPerDay: 2.5), "2.5 hours a day is about 913 hours a year, or 38 full days.")
        XCTAssertNil(TimeCost.sentence(hoursPerDay: 0))
    }
}
