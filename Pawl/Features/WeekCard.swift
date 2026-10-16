// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WeekCard.swift
//  Pawl, Home (2.2)
//
//  The last seven days on one card. It takes over from CaughtCard and keeps its rules:
//  plain and factual, no score, no grade, no praise, and a count of zero is left out
//  rather than shown as an empty number. The one thing always shown is the row of
//  seven days, because "Pawl was on" is the point.
//

import SwiftUI

struct WeekCard: View {
    let report: WeeklyReport
    /// Setup answer, hours a day that went to the habit. 0 when unknown.
    var hoursPerDay: Double = 0

    var body: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("This week").font(.title3)
                dayRow
                VStack(alignment: .leading, spacing: 6) {
                    line(report.daysProtected == 1 ? "Pawl was on for 1 day" : "Pawl was on for \(report.daysProtected) days")
                    if let kept = TimeCost.keptText(hoursPerDay: hoursPerDay,
                                                    days: report.days.filter { $0.kind == .protected }.count) {
                        Text("\(kept.prefix(1).uppercased() + kept.dropFirst()) kept this week")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PawlColor.cleanText)
                    }
                    if report.attemptsCaught > 0 {
                        line(report.attemptsCaught == 1
                             ? "Blocked 1 attempt to open a blocked app or site"
                             : "Blocked \(report.attemptsCaught) attempts to open a blocked app or site")
                    }
                    if report.urgesLogged > 0 {
                        line(report.urgesLogged == 1 ? "You logged 1 urge" : "You logged \(report.urgesLogged) urges")
                    }
                    if report.unlocksCompleted > 0 {
                        line(report.unlocksCompleted == 1 ? "1 unlock with your key" : "\(report.unlocksCompleted) unlocks with your key")
                    }
                    if report.relapsesLogged > 0 {
                        line(report.relapsesLogged == 1 ? "1 slip logged" : "\(report.relapsesLogged) slips logged")
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var dayRow: some View {
        HStack(spacing: 8) {
            ForEach(report.days, id: \.date) { day in
                VStack(spacing: 4) {
                    dot(for: day.kind)
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label(for: day))
            }
        }
    }

    @ViewBuilder
    private func dot(for kind: WeeklyReport.DayKind) -> some View {
        switch kind {
        case .protected:
            Circle().fill(PawlColor.brand).frame(width: 14, height: 14)
        case .relapse:
            Circle().strokeBorder(PawlColor.brand, lineWidth: 2).frame(width: 14, height: 14)
        case .beforeStart:
            Circle().fill(Color.secondary.opacity(0.2)).frame(width: 14, height: 14)
        }
    }

    private func label(for day: WeeklyReport.Day) -> String {
        let name = day.date.formatted(.dateTime.weekday(.wide))
        switch day.kind {
        case .protected:   return "\(name), Pawl was on"
        case .relapse:     return "\(name), slip logged"
        case .beforeStart: return "\(name), before you started"
        }
    }
}
