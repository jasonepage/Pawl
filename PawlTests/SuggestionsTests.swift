// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class SuggestionsTests: XCTestCase {
    // Every suggested site must go through the same cleaner as a typed site, unchanged, so a
    // tap adds exactly the chip the person saw.
    @MainActor
    func test_suggestedSitesAreCleanAndUnique() {
        for focus in Vertical.allCases {
            let sites = focus.suggestedSites
            XCTAssertEqual(Set(sites).count, sites.count, "\(focus) has a duplicate")
            for site in sites {
                XCTAssertEqual(BlocklistService.cleanHostname(site), site, "\(focus): \(site)")
            }
        }
    }

    func test_appsLineOnlyWhenThereAreNames() {
        XCTAssertNil(Vertical.adultContent.suggestedAppsLine)
        XCTAssertEqual(Vertical.gambling.suggestedAppsLine,
                       "Popular picks: DraftKings, FanDuel, PrizePicks, Stake. Search for them in Apple's list.")
    }
}
