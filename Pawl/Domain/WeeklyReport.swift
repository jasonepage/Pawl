// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WeeklyReport.swift
//  Pawl, Domain core (2.2)
//
//  The last seven days, as plain counts from data Pawl already keeps. Pure: no iOS
//  imports, no storage, so PawlTests/WeeklyReportTests.swift covers every rule.
//
//  Tone rules (the same ones CaughtCard followed):
//    * It reports what happened. It never scores, grades, ranks or compares.
//    * A relapse day is shown as a day, not as a failure. The streak logic elsewhere
//      already handles what a relapse means; this view only shows that it was logged.
//    * Zero of something is left out by the view, not announced.
//

import Foundation

public struct WeeklyReport: Equatable, Sendable {

    public enum DayKind: Equatable, Sendable {
        case beforeStart     // the commitment did not exist yet
        case protected       // a day Pawl was on and no relapse was logged
        case relapse         // a relapse was logged that day
    }

    public struct Day: Equatable, Sendable {
        public let date: Date        // start of that calendar day
        public let kind: DayKind
    }

    /// Oldest first, exactly seven entries ending today.
    public let days: [Day]
    /// Days in the window on or after the commitment start.
    public let daysProtected: Int
    /// Attempts the shield blocked in the window.
    public let attemptsCaught: Int
    /// Urges the person logged in the window.
    public let urgesLogged: Int
    /// Unlocks that finished (the key was used and the wait was served) in the window.
    public let unlocksCompleted: Int
    /// Relapses logged in the window.
    public let relapsesLogged: Int

    public static func make(commitmentStart: Date,
                            relapses: [Date],
                            urges: [Date],
                            attempts: [Date],
                            completedUnlocks: [Date],
                            now: Date,
                            calendar: Calendar = .current) -> WeeklyReport {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let startDay = calendar.startOfDay(for: commitmentStart)
        let relapseDays = Set(relapses.map { calendar.startOfDay(for: $0) })

        var days: [Day] = []
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            let kind: DayKind
            if date < startDay { kind = .beforeStart }
            else if relapseDays.contains(date) { kind = .relapse }
            else { kind = .protected }
            days.append(Day(date: date, kind: kind))
        }

        func inWindow(_ d: Date) -> Bool { d >= windowStart && d <= now }

        return WeeklyReport(
            days: days,
            daysProtected: days.filter { $0.kind != .beforeStart }.count,
            attemptsCaught: attempts.filter(inWindow).count,
            urgesLogged: urges.filter(inWindow).count,
            unlocksCompleted: completedUnlocks.filter(inWindow).count,
            relapsesLogged: relapses.filter(inWindow).count
        )
    }
}
