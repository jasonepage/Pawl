// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CaughtCard.swift
//  Pawl — Home
//
//  Shows how many times the shield actually did its job this week (FR-SHACT-006).
//
//  Tone rules this view follows, from the product brief:
//    * Plain and factual. It reports what the block did, never what the person is.
//    * No score, no grade, no streak language, no encouragement that could read as praise
//      for a hard week.
//    * Hidden entirely at zero, so a quiet week is not turned into an empty statistic
//      staring at someone.
//
//  Data comes from the App Group, written by the PawlShieldAction extension. It works with
//  the app force quit and it never touches the network.
//
//  Spec: docs/16_SRS_SDS_ShieldActions_and_PartnerCodes.md
//

import SwiftUI

struct CaughtCard: View {
    /// Window to report. Seven days is short enough to feel current.
    var days: Int = 7

    @State private var count: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if count > 0 {
                PawlCard {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title2)
                            .foregroundStyle(PawlColor.brand)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Caught this week")
                                .font(.title3)
                            Text(count == 1
                                 ? "Pawl blocked 1 attempt to open a blocked app or site"
                                 : "Pawl blocked \(count) attempts to open a blocked app or site")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(count == 1
                                    ? "Pawl blocked 1 attempt this week"
                                    : "Pawl blocked \(count) attempts this week")
            }
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        count = SharedState.blockAttempts(inLastDays: days)
    }
}
