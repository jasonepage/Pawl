// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlReportScenes.swift
//  PawlReport: the Screen Time report extension (2.4, docs/24)
//
//  Apple lets an app show Screen Time usage only inside a report extension like this one.
//  The numbers are drawn here and shown in Home, but they never reach Pawl's own code, this
//  extension cannot talk to the app, and it has no network. So Pawl still learns nothing
//  about which apps you use or for how long. It only lets you see it.
//
//  One scene: the last seven days of the blocked apps, as minutes per day and a total.
//

import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    /// Must match the context Home asks for.
    static let weekUsage = Self("pawl.weekUsage")
}

/// What the scene hands the view: minutes per day, oldest first, and the total.
struct WeekUsage {
    struct Day: Identifiable {
        let id: Date
        let minutes: Int
    }
    let days: [Day]
    let totalMinutes: Int
}

struct WeekUsageReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weekUsage
    let content: (WeekUsage) -> WeekUsageView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> WeekUsage {
        var perDay: [Date: TimeInterval] = [:]
        let calendar = Calendar.current
        for await item in data {
            for await segment in item.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                perDay[day, default: 0] += segment.totalActivityDuration
            }
        }
        let days = perDay.keys.sorted().map { WeekUsage.Day(id: $0, minutes: Int((perDay[$0]! / 60).rounded())) }
        let total = Int((perDay.values.reduce(0, +) / 60).rounded())
        return WeekUsage(days: days, totalMinutes: total)
    }
}
