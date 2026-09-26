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
        guard activity == .pawlUnlock else { return }
        SharedShield.lift()
        SharedState.setPhase("unshielded")
    }

    // Window closes (grace elapsed) → re-apply the shield automatically.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .pawlUnlock else { return }
        SharedShield.apply(SharedState.loadSelection())
        SharedState.setPhase("locked")
        SharedState.clearWindow()
    }
}
