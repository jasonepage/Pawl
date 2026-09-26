// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PartnerCodeRow.swift
//  Pawl — Settings
//
//  How a partner program gives Pawl Pro to the people it serves (FR-PART-001/002).
//
//  WHY THIS AND NOT A HOMEGROWN CODE SYSTEM. App Store Review Guideline 3.1.1 says apps
//  "may not use their own mechanisms to unlock content or functionality, such as license
//  keys." A private redemption table for partner cohorts sits directly in the path of that
//  sentence. Apple's subscription offer codes do the same job and are the sanctioned route,
//  so a treatment program or a gaming regulator buys codes, hands them out, and the person
//  redeems in Apple's own sheet.
//
//  Apple is explicit that redemption must use the system sheet and that a custom user
//  interface is not allowed, so this row presents the sheet and nothing else. The resulting
//  transaction arrives through Transaction.updates, which ProStore already listens to, so
//  entitlement updates itself with no extra code.
//
//  Owner setup before this does anything: App Store Connect, Subscriptions, Pawl Pro,
//  Offer Codes. Create a custom code batch per partner so redemptions can be counted per
//  program, which is also the number a pilot report needs.
//
//  Spec: docs/16_SRS_SDS_ShieldActions_and_PartnerCodes.md
//

import SwiftUI
import StoreKit

struct PartnerCodeRow: View {
    @State private var presenting = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                presenting = true
            } label: {
                Label("Redeem a program code", systemImage: "ticket")
            }

            Text("If a treatment program, a recovery group, or a tribal responsible gaming desk gave you a code, enter it here. It costs you nothing.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        // Apple's sheet. Confirm the modifier name against Xcode autocomplete: the StoreKit
        // view API has moved more than once across iOS 16 to 18.
        .offerCodeRedemption(isPresented: $presenting) { result in
            switch result {
            case .success:
                // Do not claim Pro here. Entitlement is decided by Transaction.updates in
                // ProStore, not by this sheet closing.
                message = "Checking your code with the App Store."
            case .failure:
                message = "That code could not be redeemed. Check it with whoever gave it to you."
            }
        }
    }
}
