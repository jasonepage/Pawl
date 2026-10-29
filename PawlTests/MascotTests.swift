// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import Pawl

final class MascotTests: XCTestCase {
    // The pose has to match what the hero title says, so a waiting key never shows during
    // an unlocked window and an unpaired phone never shows a key standing guard.
    @MainActor
    func test_poseFollowsUnlockState() {
        let soon = Date().addingTimeInterval(600)
        XCTAssertEqual(PawlMascot.pose(for: .locked, isPaired: true), .locked)
        XCTAssertEqual(PawlMascot.pose(for: .locked, isPaired: false), .noKey)
        XCTAssertEqual(PawlMascot.pose(for: .reading, isPaired: true), .locked)
        XCTAssertEqual(PawlMascot.pose(for: .reading, isPaired: false), .noKey)
        XCTAssertEqual(PawlMascot.pose(for: .coolingOff(endsAt: soon), isPaired: true), .waiting)
        XCTAssertEqual(PawlMascot.pose(for: .unshielded(graceEndsAt: soon), isPaired: true), .open)
        XCTAssertEqual(PawlMascot.pose(for: .unshielded(graceEndsAt: soon), isPaired: false), .open)
    }

    // 2.4: he is drawn in code. The traced outline has to be there and closed, so the hero is
    // never blank. Every polygon needs at least three points.
    func test_artIsPresent() {
        for polys in [PawlMascotArt.body, PawlMascotArt.innerEars, PawlMascotArt.stemDark, PawlMascotArt.mustache] {
            XCTAssertFalse(polys.isEmpty)
            for poly in polys { XCTAssertGreaterThanOrEqual(poly.count, 3) }
        }
        XCTAssertEqual(PawlMascotArt.innerEars.count, 2)
    }
}
