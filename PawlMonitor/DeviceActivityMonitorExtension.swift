// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  DeviceActivityMonitorExtension.swift
//  PawlMonitor — Device Activity Monitor extension
//
//  The OS calls these when the scheduled unlock window opens and closes — even if the
//  Pawl app is force-quit (HC-6, FR-UNLOCK-006/009). This is what makes the cooling-off
//  and auto-relock un-cheatable.
//
//  Requires: PawlShared.swift added to THIS target's membership (for .pawlUnlock,
//  SharedShield, SharedState) — see docs/06_Extensions_Setup_Checklist.md step B5.
//

import DeviceActivity
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // Window opens (cooling-off elapsed) → lift the shield.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // 2.2: a scheduled set's window opened. Recompute the union; no-op during grace.
        if activity.rawValue.hasPrefix(DeviceActivityName.scheduledSetPrefix) {
            SharedShield.reapplyIfLocked()
            return
        }
        guard activity == .pawlUnlock else { return }
        SharedShield.lift()
        SharedState.setPhase("unshielded")
    }

    // Window closes (grace elapsed) → re-apply the shield automatically.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // 2.2: a scheduled set's window closed. Its apps leave the union on their own; that
        // is the feature. Shrinking the window from the app is gated like any removal.
        if activity.rawValue.hasPrefix(DeviceActivityName.scheduledSetPrefix) {
            SharedShield.reapplyIfLocked()
            return
        }
        guard activity == .pawlUnlock else { return }
        // 2.4: "Until I lock it". iOS made this window end after 15 minutes, but the person
        // chose to keep apps open until they tap Lock now in Pawl. Leave the shield down.
        if SharedState.openUntilLocked() {
            SharedState.setPhase("unshielded")
            return
        }
        SharedShield.apply(SharedState.loadSelection())
        SharedState.setPhase("locked")
        SharedState.clearWindow()
    }
}
