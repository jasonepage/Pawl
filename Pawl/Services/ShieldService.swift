// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ShieldService.swift
//  Pawl — iOS integration layer
//
//  The app-side wrapper over the SHARED named shield store (see PawlShared.swift), so
//  the app and the DeviceActivityMonitor extension touch the exact same shield
//  (SRS FR-SHIELD-005/010, FR-UNLOCK-007; HC-4/HC-6).
//

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
public final class ShieldService {
    public init() {}

    /// Apply the shield for the given selection (FR-SHIELD-005). Also mirrors the
    /// selection into the App Group so the extension can re-apply it on auto-relock.
    public func apply(_ selection: FamilyActivitySelection) {
        SharedState.saveSelection(selection)
        SharedShield.apply(selection)
        SharedState.setPhase("locked")
    }

    /// Lift the shield — only after a valid tap + full cooling-off (FR-UNLOCK-007).
    public func lift() {
        SharedShield.lift()
        SharedState.setPhase("unshielded")
    }

    /// Block / allow uninstalling Pawl itself (FR-P3-HARD-002). On while a commitment is
    /// active; persists across grace cycles (not tied to apply/lift).
    public func setDeletionBlock(_ on: Bool) {
        SharedShield.setDeletionBlock(on)
    }

    /// Require automatic date and time while a commitment is active, so the clock cannot be
    /// moved forward to skip the cooling off window (FR-CLOCK-001). Call it wherever
    /// setDeletionBlock is called, on the same commitment lifecycle.
    ///
    /// UNVERIFIED ON DEVICE under individual Family Controls authorization. Run step six of
    /// the test plan in docs/16 before adding any Settings copy that promises it.
    public func setClockLock(_ on: Bool) {
        SharedShield.setClockLock(on)
    }

    /// How many blocked attempts the shield action extension caught recently (FR-SHACT-006).
    public func caughtAttempts(inLastDays days: Int = 7) -> Int {
        SharedState.blockAttempts(inLastDays: days)
    }

    public var isShielding: Bool {
        let store = ManagedSettingsStore(named: .pawl)
        return store.shield.applications?.isEmpty == false
            || store.shield.webDomains?.isEmpty == false
            || store.shield.applicationCategories != nil
    }
}
