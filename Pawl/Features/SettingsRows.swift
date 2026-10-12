// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsRows.swift
//  Pawl, Settings (2.2)
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

    static func countdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}
