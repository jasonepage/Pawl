// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  DurationText.swift
//  Pawl, 2.4
//
//  How wait and open times read on screen, in one place, so Settings, the Unlock screen and
//  the messages after a change all say the same thing. Pure, so PawlTests covers it.
//

import Foundation

public enum DurationText {

    /// "5 min", "15 min", "1 hr", "1.5 hr", "2 hr 10 min".
    public static func short(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes % 60 == 0 { return "\(minutes / 60) hr" }
        if minutes % 60 == 30 { return "\(minutes / 60).5 hr" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }

    public static func short(seconds: TimeInterval) -> String {
        short(minutes: Int((seconds / 60).rounded()))
    }

    /// A wait as a choice label: "No wait" for 0, otherwise "15 min".
    public static func wait(seconds: TimeInterval) -> String {
        seconds <= 0 ? "No wait" : short(seconds: seconds)
    }

    /// An open time as a choice label: "Until I lock it", otherwise "30 min".
    public static func open(seconds: TimeInterval) -> String {
        PawlDefaults.isUntilLocked(seconds) ? "Until I lock it" : short(seconds: seconds)
    }

    /// When a change that blocks less takes effect, for messages: "now" or "in 15 min".
    public static func startsIn(waitSeconds: TimeInterval) -> String {
        waitSeconds <= 0 ? "now" : "in \(short(seconds: waitSeconds))"
    }

    /// One line for a Settings row: "15 min wait, then open for 30 min", "No wait, then open
    /// until you lock it".
    public static func summary(waitSeconds: TimeInterval, openSeconds: TimeInterval) -> String {
        let wait = waitSeconds <= 0 ? "No wait" : "\(short(seconds: waitSeconds)) wait"
        let open = PawlDefaults.isUntilLocked(openSeconds)
            ? "open until you lock it" : "open for \(short(seconds: openSeconds))"
        return "\(wait), then \(open)"
    }

    /// The line under "Tap to unlock", for the saved wait and open time.
    public static func unlockHelp(waitSeconds: TimeInterval, openSeconds: TimeInterval) -> String {
        let untilLocked = PawlDefaults.isUntilLocked(openSeconds)
        if waitSeconds <= 0 {
            return untilLocked
                ? "Using your key opens apps right away. They stay open until you tap Lock now."
                : "Using your key opens apps right away for \(short(seconds: openSeconds)). Then they re-lock on their own."
        }
        let wait = short(seconds: waitSeconds)
        return untilLocked
            ? "Using your key starts a \(wait) wait. Apps stay locked until it's over, then stay open until you tap Lock now."
            : "Using your key starts a \(wait) wait. Apps stay locked until it's over, then re-lock on their own."
    }
}
