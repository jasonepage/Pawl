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

    /// 2.4: the OS window never starts sooner than this. With "No wait" the app lifts the
    /// shield itself right away; the window starting a minute later only lifts it again (no
    /// change) and owns the relock. A window starting "now" could already be in the past by
    /// the time iOS reads it.
    static let minimumLead: TimeInterval = 60

    /// The window to ask iOS for. Pure, so PawlTests covers it.
    /// - `shownStart`: when apps open, as the app shows it and as relaunches read it.
    /// - `osStart`/`osEnd`: the DeviceActivity window. At least `minimumLead` away, and at least
    ///   15 minutes long (iOS refuses shorter). "Until I lock it" asks for the 15 minutes; the
    ///   monitor then leaves apps open at the end instead of relocking.
    struct Window: Equatable {
        let shownStart: Date
        let osStart: Date
        let osEnd: Date
    }

    static func window(coolingOff: TimeInterval, grace: TimeInterval, now: Date) -> Window {
        let shownStart = now.addingTimeInterval(max(0, coolingOff))
        let osStart = now.addingTimeInterval(max(coolingOff, minimumLead))
        let length = PawlDefaults.isUntilLocked(grace) ? PawlDefaults.graceFloor
                                                       : max(grace, PawlDefaults.graceFloor)
        // End at the time the app shows (start + open time), so the "locked again" reminder and
        // the real relock match. Only stretch it when iOS's 15 minute minimum needs it.
        let osEnd = max(shownStart.addingTimeInterval(length), osStart.addingTimeInterval(PawlDefaults.graceFloor))
        return Window(shownStart: shownStart, osStart: osStart, osEnd: osEnd)
    }

    public static func scheduleUnlock(coolingOff: TimeInterval, grace: TimeInterval, now: Date = Date()) throws {
        let cal = Calendar.current
        let w = window(coolingOff: coolingOff, grace: grace, now: now)
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(fields, from: w.osStart),
            intervalEnd: cal.dateComponents(fields, from: w.osEnd),
            repeats: false
        )
        // Replace any in-flight window first.
        center.stopMonitoring([.pawlUnlock])
        try center.startMonitoring(.pawlUnlock, during: schedule)

        // Record the window + phase so the app UI can reflect reality after a relaunch.
        SharedState.setWindow(start: w.shownStart, end: w.osEnd)
        SharedState.setOpenUntilLocked(PawlDefaults.isUntilLocked(grace))
        SharedState.setPhase("cooling")
    }

    /// Cancel a pending/active unlock window (used when the user cancels cooling-off, and by
    /// Lock now).
    public static func cancel() {
        center.stopMonitoring([.pawlUnlock])
        SharedState.clearWindow()
        SharedState.setOpenUntilLocked(false)
        SharedState.setPhase("locked")
    }
}
