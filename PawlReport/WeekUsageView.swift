// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WeekUsageView.swift
//  PawlReport
//
//  The card Home shows: a total and seven small bars. Plain facts, no grade. Drawn to match
//  the app's cards without sharing code (an extension cannot use the app's files).
//

import SwiftUI

struct WeekUsageView: View {
    let usage: WeekUsage

    private let brand = Color(red: 0x97 / 255, green: 0xC4 / 255, blue: 0x59 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("In the blocked apps")
                    .font(.headline)
                Spacer()
                Text(totalText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if usage.days.isEmpty {
                Text("Nothing yet this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                bars
                Text("Apple's Screen Time numbers, shown here only. Pawl never sees them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var totalText: String {
        let m = usage.totalMinutes
        if m < 60 { return "\(m) min this week" }
        if m % 60 == 0 { return "\(m / 60) hr this week" }
        return "\(m / 60) hr \(m % 60) min this week"
    }

    private var bars: some View {
        let maxMinutes = max(1, usage.days.map(\.minutes).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(usage.days) { day in
                VStack(spacing: 4) {
                    Text(day.minutes > 0 ? "\(day.minutes)" : "")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(day.minutes > 0 ? brand : brand.opacity(0.18))
                        .frame(height: max(4, 72 * CGFloat(day.minutes) / CGFloat(maxMinutes)))
                    Text(day.id, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 110, alignment: .bottom)
    }
}
