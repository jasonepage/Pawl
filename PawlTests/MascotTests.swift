// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
import UIKit
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
    }

    // Every pose's drawing is in the asset catalog, so the hero is never blank.
    @MainActor
    func test_everyPoseHasAnImage() {
        for pose in [PawlMascot.Pose.locked, .waiting, .open, .noKey] {
            XCTAssertNotNil(UIImage(named: pose.assetName), pose.assetName)
        }
    }
}
