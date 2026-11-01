// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WeekFacts.swift
//  Pawl, Domain core (2.4, docs/24)
//
//  What Home shows instead of a streak and a slip log: plain facts about the last seven
//  days, from data Pawl already keeps. Nobody types anything. An unlock is the slip.
//
//  Tone rules: it reports, never grades. Zero of something is left out by the view.
//

import Foundation

public struct WeekFacts: Equatable, Sendable {
    /// Days in the window Pawl was on (the commitment existed and a key or ally could unlock).
    public let daysBlocked: Int
    /// Days in the window, 7 at most, fewer in the first week.
    public let daysInWindow: Int
    /// Unlocks that finished (the wait was served and apps opened).
    public let unlocks: Int
    /// Minutes the apps were open because of those unlocks.
    public let openMinutes: Int
    /// Times the block screen was hit and the person walked away.
    public let hitTheWall: Int
    /// "I'm tempted" timers the person rode out.
    public let urgesRidden: Int
    /// Hours back this week: the old daily use times days blocked, minus the open time.
    /// nil when the setup answer was unknown or the result is under an hour.
    public let hoursBack: Int?

    public struct Unlock: Equatable, Sendable {
        public let openedAt: Date
        public let closedAt: Date?
        public init(openedAt: Date, closedAt: Date?) {
            self.openedAt = openedAt
            self.closedAt = closedAt
        }
    }

    public static func make(commitmentStart: Date,
                            hoursPerDay: Double,
                            unlocks: [Unlock],
                            attempts: [Date],
                            urges: [Date],
                            now: Date,
                            calendar: Calendar = .current) -> WeekFacts {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let startDay = calendar.startOfDay(for: commitmentStart)
        func inWindow(_ d: Date) -> Bool { d >= windowStart && d <= now }

        var daysBlocked = 0
        var daysInWindow = 0
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            if date >= startDay { daysBlocked += 1 }
            daysInWindow += 1
        }

        let weekUnlocks = unlocks.filter { inWindow($0.openedAt) }
        var openSeconds: TimeInterval = 0
        for u in weekUnlocks {
            let end = min(u.closedAt ?? now, now)
            openSeconds += max(0, end.timeIntervalSince(u.openedAt))
        }
        let openMinutes = Int((openSeconds / 60).rounded())

        var hoursBack: Int? = nil
        if hoursPerDay > 0 {
            let hours = hoursPerDay * Double(daysBlocked) - Double(openMinutes) / 60
            let rounded = Int(hours.rounded())
            if rounded >= 1 { hoursBack = rounded }
        }

        return WeekFacts(daysBlocked: daysBlocked,
                         daysInWindow: daysInWindow,
                         unlocks: weekUnlocks.count,
                         openMinutes: openMinutes,
                         hitTheWall: attempts.filter(inWindow).count,
                         urgesRidden: urges.filter(inWindow).count,
                         hoursBack: hoursBack)
    }

    public init(daysBlocked: Int, daysInWindow: Int, unlocks: Int, openMinutes: Int,
                hitTheWall: Int, urgesRidden: Int, hoursBack: Int?) {
        self.daysBlocked = daysBlocked
        self.daysInWindow = daysInWindow
        self.unlocks = unlocks
        self.openMinutes = openMinutes
        self.hitTheWall = hitTheWall
        self.urgesRidden = urgesRidden
        self.hoursBack = hoursBack
    }
}
