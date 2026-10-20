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

    /// What re-applying the shield should do, given the unlock window that may be in progress.
    public enum ApplyAction: Equatable, Sendable {
        /// No unlock in progress (or a stale one): block and mark the phase locked.
        case lock
        /// Waiting out the cooling-off: keep blocking, but keep the countdown (phase stays).
        case blockKeepCountdown
        /// Inside the open window after a full unlock: don't re-block. The monitor relocks
        /// at the window's end with the saved selection.
        case keepOpen
    }

    /// 2.3 fix. Pure, so PawlTests covers it. Before this, every apply set the phase to
    /// "locked", so a relaunch mid-unlock (RecoveryService re-applies on launch) wiped the
    /// countdown, and during the open window it re-blocked everything early.
    public nonisolated static func applyAction(phase: String, windowStart: Date?, windowEnd: Date?,
                                               now: Date) -> ApplyAction {
        guard phase == "cooling" || phase == "unshielded",
              let start = windowStart, let end = windowEnd, now < end else { return .lock }
        return now >= start ? .keepOpen : .blockKeepCountdown
    }

    /// Apply the shield for the given selection (FR-SHIELD-005). Also mirrors the
    /// selection into the App Group so the extension can re-apply it on auto-relock.
    /// 2.3: respects an unlock in progress (see `applyAction`). Use `relock` to end one.
    public func apply(_ selection: FamilyActivitySelection) {
        SharedState.saveSelection(selection)
        switch Self.applyAction(phase: SharedState.phase(), windowStart: SharedState.windowStart(),
                                windowEnd: SharedState.windowEnd(), now: Date()) {
        case .keepOpen:
            return
        case .blockKeepCountdown:
            SharedShield.apply(selection)
        case .lock:
            SharedShield.apply(selection)
            SharedState.setPhase("locked")
        }
    }

    /// Re-apply the shield and end any unlock window, no matter where it stands. For the
    /// automatic relock at the end of the open window.
    public func relock(_ selection: FamilyActivitySelection) {
        SharedState.saveSelection(selection)
        SharedShield.apply(selection)
        SharedState.setPhase("locked")
        SharedState.clearWindow()
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
