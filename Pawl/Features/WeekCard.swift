// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  WeekCard.swift
//  Pawl, Home (2.2, rebuilt in 2.3)
//
//  The last seven days on one card. Rules carried over from 2.2 (and CaughtCard before it):
//  plain and factual, no score, no grade, no praise, no comparing weeks, and a count of zero
//  is left out rather than shown as an empty number. A slip day is shown as a day, in a
//  neutral color, never red.
//
//  2.3 layout:
//    * Header: "This week", the dates, and how many days Pawl was on.
//    * Day strip: one dot per day. Green = Pawl was on. A number inside = urges resisted that
//      day. A gray dot with a small arrow = a slip was logged. Today has a ring. Free for all.
//    * Pawl Pro (the weekly report): big numbers (hours back, blocked attempts, urges
//      resisted, unlocks), the hardest time of day with a shortcut to a scheduled set, the
//      most common trigger, and the person's own words from this week.
//    * Without Pro, a short preview of what the full week shows.
//

import SwiftUI

struct WeekCard: View {
    let report: WeeklyReport
    /// Setup answer, hours a day that went to the habit. 0 when unknown.
    var hoursPerDay: Double = 0
    /// The full report is part of Pawl Pro; the header and day strip are free.
    var isPro: Bool = false
    /// The newest note the person wrote on an urge this week, if any.
    var latestNote: String? = nil
    var onGetPro: () -> Void = {}
    /// Opens What's blocked, where scheduled sets live.
    var onPlanSet: () -> Void = {}

    var body: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 16) {
                header
                dayStrip
                if isPro {
                    details
                } else {
                    proPreview
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.title3.weight(.semibold))
                Spacer(minLength: 8)
                Text(rangeText).font(.footnote).foregroundStyle(.secondary)
            }
            Text(onLine).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    /// "Oct 13 to 19", or "Sep 29 to Oct 5" across a month.
    private var rangeText: String {
        guard let first = report.days.first?.date, let last = report.days.last?.date else { return "" }
        let cal = Calendar.current
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        let sameMonth = cal.component(.month, from: first) == cal.component(.month, from: last)
        let end = sameMonth ? last.formatted(.dateTime.day()) : last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) to \(end)"
    }

    private var onLine: String {
        let n = report.daysProtected
        if n >= 7 { return "Pawl was on all 7 days" }
        if n == 0 { return "No days on yet" }
        return n == 1 ? "Pawl was on for 1 day" : "Pawl was on for \(n) days"
    }

    // MARK: Day strip

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(report.days.enumerated()), id: \.offset) { index, day in
                    let isToday = index == report.days.count - 1
                    VStack(spacing: 6) {
                        dayDot(day, isToday: isToday)
                        Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(isToday ? .semibold : .regular))
                            .foregroundStyle(isToday ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(dayLabel(day, isToday: isToday))
                }
            }
            if report.days.contains(where: { $0.urges > 0 }) {
                Text("A number is how many urges you resisted that day.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func dayDot(_ day: WeeklyReport.Day, isToday: Bool) -> some View {
        ZStack {
            switch day.kind {
            case .beforeStart:
                Circle().strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            case .relapse:
                Circle().fill(Color.secondary.opacity(0.18))
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            case .protected:
                Circle().fill(PawlColor.brand)
                if day.urges > 0 {
                    Text("\(day.urges)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 30, height: 30)
        .padding(3)
        .overlay {
            if isToday { Circle().strokeBorder(PawlColor.brand.opacity(0.5), lineWidth: 2) }
        }
    }

    private func dayLabel(_ day: WeeklyReport.Day, isToday: Bool) -> String {
        let name = isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide))
        switch day.kind {
        case .beforeStart: return "\(name), before Pawl started"
        case .relapse:     return "\(name), a slip was logged"
        case .protected:
            if day.urges == 0 { return "\(name), Pawl was on" }
            return "\(name), Pawl was on, \(day.urges == 1 ? "1 urge" : "\(day.urges) urges") resisted"
        }
    }

    // MARK: Pro details

    private struct Tile: Identifiable {
        let id: String
        let value: Int
        let label: String
    }

    private var tiles: [Tile] {
        var t: [Tile] = []
        let protectedDays = report.days.filter { $0.kind == .protected }.count
        let hours = Int((max(0, hoursPerDay) * Double(protectedDays)).rounded())
        if hoursPerDay > 0, hours >= 1 {
            t.append(Tile(id: "hours", value: hours, label: hours == 1 ? "hour back" : "hours back"))
        }
        if report.attemptsCaught > 0 {
            t.append(Tile(id: "attempts", value: report.attemptsCaught,
                          label: report.attemptsCaught == 1 ? "blocked attempt" : "blocked attempts"))
        }
        if report.urgesLogged > 0 {
            t.append(Tile(id: "urges", value: report.urgesLogged,
                          label: report.urgesLogged == 1 ? "urge resisted" : "urges resisted"))
        }
        if report.unlocksCompleted > 0 {
            t.append(Tile(id: "unlocks", value: report.unlocksCompleted,
                          label: report.unlocksCompleted == 1 ? "unlock with your key" : "unlocks with your key"))
        }
        return t
    }

    @ViewBuilder
    private var details: some View {
        if !tiles.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      alignment: .leading, spacing: 10) {
                ForEach(tiles) { tile in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(tile.value)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(PawlColor.cleanText)
                        Text(tile.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(PawlColor.cleanBg.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }

        if let time = report.hardestTime {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Most urges and blocked attempts came \(time.phrase).")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: time == .lateNight || time == .evening ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(PawlColor.urgeText)
                }
                .font(.subheadline)
                Button(action: onPlanSet) {
                    Label("Add a \(time.name.lowercased()) set", systemImage: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(PawlColor.brand)
            }
        }

        if let trigger = report.commonTrigger {
            Label {
                Text("What set it off most: \u{201C}\(trigger)\u{201D}")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "bolt.fill").foregroundStyle(PawlColor.urgeText)
            }
            .font(.subheadline)
        }

        if let note = latestNote {
            VStack(alignment: .leading, spacing: 4) {
                Text("In your words").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("\u{201C}\(note)\u{201D}")
                    .font(.body.italic())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PawlColor.groupedBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        if report.relapsesLogged > 0 {
            Text(report.relapsesLogged == 1 ? "1 slip logged" : "\(report.relapsesLogged) slips logged")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Without Pro

    private var proPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("See your whole week")
                .font(.subheadline.weight(.semibold))
            Text("Hours back, blocked attempts, the time of day that's hardest, and your own words. Part of Pawl Pro.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("See Pawl Pro", action: onGetPro)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PawlColor.brand)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PawlColor.groupedBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
