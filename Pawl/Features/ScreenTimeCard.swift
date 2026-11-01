// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ScreenTimeCard.swift
//  Pawl: Home (2.4, docs/24)
//
//  Apple's own Screen Time numbers for the blocked apps, drawn by the PawlReport extension
//  and shown here. The app passes the blocked selection and a seven day window in; the
//  extension draws the card; nothing comes back. Pawl never sees the numbers.
//

import SwiftUI
import DeviceActivity
import FamilyControls

extension DeviceActivityReport.Context {
    /// Must match PawlReport's context.
    static let weekUsage = Self("pawl.weekUsage")
}

struct ScreenTimeCard: View {
    /// The blocked apps, categories and sites, from the shared selection.
    let selection: FamilyActivitySelection

    private var filter: DeviceActivityFilter {
        let now = Date()
        let start = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now)
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: now)),
            users: .all,
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    var body: some View {
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
            EmptyView()
        } else {
            DeviceActivityReport(.weekUsage, filter: filter)
                .frame(minHeight: 190)
        }
    }
}
