// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsRows.swift
//  Pawl, Settings (2.2, rows reworked in 2.3)
//
//  The row pieces every Settings screen shares: the colored badge, a badge plus title, a
//  badge plus title plus trailing value, and the mm:ss countdown. Pulled out of
//  SettingsView so the sub-screens look identical to the index.
//

import SwiftUI

enum SettingsRows {
    /// A colored rounded square icon, the iOS Settings badge look.
    static func badge(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// Badge plus title. Works inside Button and NavigationLink.
    static func label(_ symbol: String, _ color: Color, _ title: String) -> some View {
        Label { Text(title) } icon: { badge(symbol, color) }
    }

    /// Badge plus title on the left, a value on the right.
    static func value(_ symbol: String, _ color: Color, _ title: String, _ value: String) -> some View {
        HStack {
            label(symbol, color, title)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.secondary)
        }
    }

    /// 2.3: badge, a title with one plain line under it, and an optional value on the right.
    /// The Settings index uses this so every row says what it is and how it is set right now,
    /// instead of a cryptic value like "15 / 30 min".
    static func detail(_ symbol: String, _ color: Color, _ title: String, _ subtitle: String,
                       value: String? = nil) -> some View {
        HStack(spacing: 12) {
            badge(symbol, color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// 2.3: a row that leaves Pawl (a web page or a phone call). Plain text like every other row,
    /// not tinted, with a small arrow so it reads as "opens somewhere else".
    static func external(_ symbol: String, _ color: Color, _ title: String) -> some View {
        HStack {
            Label { Text(title).foregroundStyle(.primary) } icon: { badge(symbol, color) }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    static func countdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
