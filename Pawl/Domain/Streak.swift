// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  Streak.swift
//  Pawl — Domain core
//
//  Clean-day streak computation (SRS FR-STREAK-001). Pure function; no stored truth.
//

import Foundation

public enum Streak {
    /// Whole days since the later of the commitment start or the most recent relapse.
    /// (FR-STREAK-001 / 003). Returns 0 on the day of start or relapse.
    public static func cleanDays(
        commitmentStart: Date,
        lastRelapse: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let anchor = max(commitmentStart, lastRelapse ?? .distantPast)
        // Count by calendar day boundaries, not raw 24h, so "since yesterday" reads correctly.
        let startDay = calendar.startOfDay(for: anchor)
        let nowDay = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startDay, to: nowDay).day ?? 0
        return max(0, days)
    }
}
