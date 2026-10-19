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
//  2.3: each day also carries its own urge and blocked-attempt counts (for the day strip),
//  and the report names the hardest time of day and the most common trigger, but only when
//  the data clearly shows one. Both are facts about the week, never judgments.
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
        /// 2.3: urges logged that day.
        public let urges: Int
        /// 2.3: attempts the shield blocked that day.
        public let attempts: Int
    }

    /// 2.3: a rough part of the day, for "when it was hardest".
    public enum TimeOfDay: String, Equatable, Sendable, CaseIterable {
        case morning      // 5am to noon
        case afternoon    // noon to 5pm
        case evening      // 5pm to 10pm
        case lateNight    // 10pm to 5am

        public init(hour: Int) {
            switch hour {
            case 5..<12:  self = .morning
            case 12..<17: self = .afternoon
            case 17..<22: self = .evening
            default:      self = .lateNight
            }
        }

        /// Reads after "Most of it came": "in the morning", "late at night".
        public var phrase: String {
            switch self {
            case .morning:   return "in the morning"
            case .afternoon: return "in the afternoon"
            case .evening:   return "in the evening"
            case .lateNight: return "late at night"
            }
        }

        /// Short name for a button or a set, "Late night".
        public var name: String {
            switch self {
            case .morning:   return "Morning"
            case .afternoon: return "Afternoon"
            case .evening:   return "Evening"
            case .lateNight: return "Late night"
            }
        }
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
    /// 2.3: the part of the day most urges and blocked attempts fell in. nil unless there were
    /// at least 3 of them and one part of the day clearly had the most (at least 2, no tie).
    public let hardestTime: TimeOfDay?
    /// 2.3: the urge trigger the person typed most often, lowercased and trimmed. nil unless the
    /// same one came up at least twice and nothing tied with it.
    public let commonTrigger: String?

    public static func make(commitmentStart: Date,
                            relapses: [Date],
                            urges: [Date],
                            attempts: [Date],
                            completedUnlocks: [Date],
                            triggers: [(date: Date, text: String)] = [],
                            now: Date,
                            calendar: Calendar = .current) -> WeeklyReport {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let startDay = calendar.startOfDay(for: commitmentStart)
        let relapseDays = Set(relapses.map { calendar.startOfDay(for: $0) })

        func inWindow(_ d: Date) -> Bool { d >= windowStart && d <= now }
        let weekUrges = urges.filter(inWindow)
        let weekAttempts = attempts.filter(inWindow)
        var urgesPerDay: [Date: Int] = [:]
        for u in weekUrges { urgesPerDay[calendar.startOfDay(for: u), default: 0] += 1 }
        var attemptsPerDay: [Date: Int] = [:]
        for a in weekAttempts { attemptsPerDay[calendar.startOfDay(for: a), default: 0] += 1 }

        var days: [Day] = []
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            let kind: DayKind
            if date < startDay { kind = .beforeStart }
            else if relapseDays.contains(date) { kind = .relapse }
            else { kind = .protected }
            days.append(Day(date: date, kind: kind,
                            urges: urgesPerDay[date] ?? 0, attempts: attemptsPerDay[date] ?? 0))
        }

        // Hardest time: urges and blocked attempts together, by part of the day.
        let stamps = weekUrges + weekAttempts
        var byTime: [TimeOfDay: Int] = [:]
        for t in stamps { byTime[TimeOfDay(hour: calendar.component(.hour, from: t)), default: 0] += 1 }
        let hardest = stamps.count >= 3 ? clearWinner(byTime) : nil

        // Most common trigger, from what the person typed this week.
        var byTrigger: [String: Int] = [:]
        for t in triggers where inWindow(t.date) {
            let key = t.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty { byTrigger[key, default: 0] += 1 }
        }

        return WeeklyReport(
            days: days,
            daysProtected: days.filter { $0.kind != .beforeStart }.count,
            attemptsCaught: weekAttempts.count,
            urgesLogged: weekUrges.count,
            unlocksCompleted: completedUnlocks.filter(inWindow).count,
            relapsesLogged: relapses.filter(inWindow).count,
            hardestTime: hardest,
            commonTrigger: clearWinner(byTrigger)
        )
    }

    /// The key with the highest count, only if that count is at least 2 and no other key ties it.
    static func clearWinner<K: Hashable>(_ counts: [K: Int]) -> K? {
        guard let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 else { return nil }
        let ties = counts.values.filter { $0 == top.value }.count
        return ties == 1 ? top.key : nil
    }
}
