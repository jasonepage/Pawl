// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PaywallView.swift
//  Pawl — 2.0 (P1: Pawl Pro subscription)
//
//  The Pawl Pro paywall. Built on StoreKit's declarative `SubscriptionStoreView` so the
//  App-Review-required controls (Restore, Terms, Privacy) come almost for free and the
//  plans / prices / 7-day intro offer render straight from the StoreKit configuration (locally)
//  or App Store Connect (production) — no hand-rolled price strings to drift out of date.
//
//  Uses `productIDs:` rather than `groupID:` on purpose: the local Configuration.storekit group id
//  differs from the real App Store Connect group id, but the product IDs are identical across both.
//
//  NOTE (verify against Xcode autocomplete — the StoreKit SwiftUI API shifted across iOS 17→18):
//   • `.subscriptionStorePolicyDestination(url:for:)`
//   • `.onInAppPurchaseCompletion { product, result in }`
//   • `.storeButton(.visible, for: .restorePurchases)`
//  If any name/signature is off on the first build, the fix is mechanical — paste me the error.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    let pro: ProStore
    @Environment(\.dismiss) private var dismiss

    private let privacyURL = URL(string: "https://getpawl.com/privacy")!
    // Apple's standard EULA satisfies the Terms-of-Use link requirement (docs/12 §9) until a
    // dedicated terms page lives on getpawl.com.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        SubscriptionStoreView(productIDs: [ProStore.yearlyID, ProStore.monthlyID]) {
            marketingContent
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            // On a verified purchase, recompute entitlement immediately (don't wait on the async
            // Transaction.updates stream, which can lag) so Pro status reflects right away, then dismiss.
            if case .success(let purchase) = result, case .success = purchase {
                Task { await pro.refreshEntitlements() }
                dismiss()
            }
        }
    }

    private var marketingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")            // mascot slot later (P4)
                .font(.system(size: 44))
                .foregroundStyle(PawlColor.brand)
            Text("Pawl Pro")
                .font(.largeTitle.bold())
            Text("You're not doing this alone.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                proFeature("person.2.fill", "Link your own sponsor",
                           "A trusted person approves your unlocks — so the impulsive choice isn't yours alone.")
                proFeature("bell.badge.fill", "Protection-drop alerts",
                           "Your sponsor is alerted the moment your protection is removed.")
            }
            .padding(.top, 4)

            Text("Blocking, the security key, cooling-off, your streak, the crisis tools, and helping someone else stay free are always free.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    private func proFeature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(PawlColor.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
    }
}
