// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockScheduler.swift
//  Pawl — app side
//
//  Schedules the OS-owned DeviceActivity window that drives the durable cooling-off
//  and auto-relock (FR-UNLOCK-006/009, HC-6). One window per unlock:
//    • window START  = now + coolingOff   → monitor lifts the shield
//    • window END    = start + grace       → monitor re-applies the shield
//  The gap between "now" and the window start IS the cooling-off (shield stays on).
//
//  Because the schedule lives with the OS, force-quitting the app does not stop it.
//

import Foundation
import DeviceActivity

public enum UnlockScheduler {
    private static let center = DeviceActivityCenter()

    public static func scheduleUnlock(coolingOff: TimeInterval, grace: TimeInterval, now: Date = Date()) throws {
        let cal = Calendar.current
        let start = now.addingTimeInterval(coolingOff)
        let end = start.addingTimeInterval(grace)
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(fields, from: start),
            intervalEnd: cal.dateComponents(fields, from: end),
            repeats: false
        )
        // Replace any in-flight window first.
        center.stopMonitoring([.pawlUnlock])
        try center.startMonitoring(.pawlUnlock, during: schedule)

        // Record the window + phase so the app UI can reflect reality after a relaunch.
        SharedState.setWindow(start: start, end: end)
        SharedState.setPhase("cooling")
    }

    /// Cancel a pending/active unlock window (used when the user cancels cooling-off).
    public static func cancel() {
        center.stopMonitoring([.pawlUnlock])
        SharedState.clearWindow()
        SharedState.setPhase("locked")
    }
}
