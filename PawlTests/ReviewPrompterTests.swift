// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ReviewPrompterTests.swift
//  PawlTests
//
//  Pins the rating-ask rules: install grace, spacing, one-shot tags.
//

import XCTest
@testable import Pawl

final class ReviewPrompterTests: XCTestCase {

    private var defaults: UserDefaults!
    private let install = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Int) -> Date { install.addingTimeInterval(Double(n) * 86_400) }

    override func setUp() {
        super.setUp()
        let suite = "ReviewPrompterTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        ReviewPrompter.noteLaunch(now: install, defaults: defaults)
    }

    func test_noAskInsideFirstThreeDays() {
        XCTAssertFalse(ReviewPrompter.shouldAsk(.urgeLogged, now: day(2), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.urgeLogged, now: day(3), defaults: defaults))
    }

    func test_sixtyDaySpacingBetweenAsks() {
        XCTAssertTrue(ReviewPrompter.shouldAsk(.urgeLogged, now: day(10), defaults: defaults))
        XCTAssertFalse(ReviewPrompter.shouldAsk(.urgeLogged, now: day(40), defaults: defaults))
        XCTAssertFalse(ReviewPrompter.shouldAsk(.streakMilestone, tag: "60", now: day(69), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.urgeLogged, now: day(70), defaults: defaults))
    }

    func test_taggedMomentAsksOnceEver() {
        XCTAssertTrue(ReviewPrompter.shouldAsk(.streakMilestone, tag: "7", now: day(7), defaults: defaults))
        XCTAssertFalse(ReviewPrompter.shouldAsk(.streakMilestone, tag: "7", now: day(400), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.streakMilestone, tag: "30", now: day(400), defaults: defaults))
    }

    func test_throttledTagIsNotBurned() {
        // Milestone 7 lands inside the install grace: skipped, but still available later.
        XCTAssertFalse(ReviewPrompter.shouldAsk(.streakMilestone, tag: "7", now: day(1), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.streakMilestone, tag: "7", now: day(8), defaults: defaults))
    }

    func test_writeReviewURLTargetsPawl() {
        XCTAssertEqual(ReviewPrompter.writeReviewURL.absoluteString,
                       "https://apps.apple.com/app/id6783119309?action=write-review")
    }

    // 2.3: the new one-shot moments ask once, ever, and still respect the spacing.
    func test_newMomentsAskOnceEach() {
        XCTAssertTrue(ReviewPrompter.shouldAsk(.proPurchased, tag: "first", now: day(10), defaults: defaults))
        XCTAssertFalse(ReviewPrompter.shouldAsk(.hardLockOn, tag: "first", now: day(20), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.hardLockOn, tag: "first", now: day(80), defaults: defaults))
        XCTAssertFalse(ReviewPrompter.shouldAsk(.proPurchased, tag: "first", now: day(400), defaults: defaults))
        XCTAssertTrue(ReviewPrompter.shouldAsk(.fullWeek, tag: "2026-10-13", now: day(400), defaults: defaults))
    }
}
