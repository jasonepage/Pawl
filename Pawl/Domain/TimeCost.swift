// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  TimeCost.swift
//  Pawl, Domain core (2.2)
//
//  One line on the welcome screen: hours a day, as hours and whole days a year. Plain
//  arithmetic, nothing stored, nothing about "years of your life". Pure so it is tested.
//

import Foundation

public enum TimeCost {
    /// Hours per year for a daily habit.
    public static func hoursPerYear(hoursPerDay: Double) -> Int {
        Int((max(0, hoursPerDay) * 365).rounded())
    }

    /// Whole 24-hour days per year for a daily habit.
    public static func daysPerYear(hoursPerDay: Double) -> Int {
        Int((max(0, hoursPerDay) * 365 / 24).rounded())
    }

    /// The sentence the welcome screen shows. nil below half an hour, where it would be noise.
    public static func sentence(hoursPerDay: Double) -> String? {
        guard hoursPerDay >= 0.5 else { return nil }
        let hours = hoursPerYear(hoursPerDay: hoursPerDay)
        let days = daysPerYear(hoursPerDay: hoursPerDay)
        let perDay = hoursPerDay == hoursPerDay.rounded()
            ? "\(Int(hoursPerDay)) hour\(Int(hoursPerDay) == 1 ? "" : "s")"
            : String(format: "%.1f hours", hoursPerDay)
        return "\(perDay) a day is about \(hours) hours a year, or \(days) full days."
    }
}
