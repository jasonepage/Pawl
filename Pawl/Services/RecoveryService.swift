// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  RecoveryService.swift
//  Pawl — reinstall recovery
//
//  Runs on launch. If the user had an active commitment (restored from iCloud), pull
//  the shield selection back into the App Group and re-apply the shield, so deleting +
//  reinstalling produces NO reduction in friction (SRS FR-PERSIST-002/003, HC-4).
//

import Foundation
import FamilyControls

public enum RecoveryService {
    @MainActor
    public static func restoreOnLaunch() async {
        // Bring the shield selection back from iCloud if the App Group was wiped.
        SelectionStore().restoreFromCloudIfNeeded()

        // Only the app can re-apply shields, and only while authorized (HC-4, FR-AUTH-003).
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }

        let repo = CloudCommitmentRepository()
        guard let snapshot = try? await repo.loadActiveCommitment(),
              snapshot.commitment.status == .active else { return }

        // Re-apply the shield from the restored selection. Idempotent on normal launches.
        let selection = SelectionStore().load()
        ShieldService().apply(selection)
    }
}
