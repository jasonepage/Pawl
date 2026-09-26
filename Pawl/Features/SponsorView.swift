// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SponsorView.swift
//  Pawl — Phase 2 (slice 3: sponsor linking)
//
//  Settings UI for inviting/redeeming a sponsor. Shown only when signed in. The protected
//  person invites (one-time code); a sponsor redeems a code. Slice 4 makes the link actually
//  gate unlocks.
//

import SwiftUI

struct SponsorView: View {
    let sponsor: SponsorService
    var nameMissing: Bool = false
    /// Protected-person accountability is Pro-gated (docs/12 §2). Approver side below stays free.
    var hasAccountability: Bool = true
    var onUnlock: () -> Void = {}
    @State private var codeEntry = ""

    private var activeProtected: SponsorService.Link? {
        sponsor.asProtected.first { $0.status == "active" }
    }
    private var pendingProtected: SponsorService.Link? {
        sponsor.asProtected.first { $0.status == "pending" }
    }

    var body: some View {
        Section("Your sponsor") {
            if let link = activeProtected {
                LabeledContent("Status", value: "Linked ✓")
                lapsedRenewRow   // no-op unless Pro has lapsed (docs/12 §8)
                Button("Remove sponsor", role: .destructive) {
                    Task { await sponsor.revoke(link) }
                }
            } else if let pending = pendingProtected {
                LabeledContent("Invite code", value: pending.invite_code)
                    .font(.body.monospaced())
                    .tracking(2)
                    .textSelection(.enabled)
                Text("Share this code with your sponsor. It links once they enter it on their phone. Waiting for them…")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Cancel invite", role: .destructive) {
                    Task { await sponsor.cancelInvites() }
                }
                lapsedRenewRow
            } else if !hasAccountability {
                Button("Unlock with Pawl Pro") { onUnlock() }
                Text("Linking a sponsor who approves your unlocks and is alerted if your protection drops is part of Pawl Pro. Blocking and the crisis tools stay free.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Invite a sponsor") {
                    Task { await sponsor.createInvite() }
                }
                .disabled(sponsor.isBusy)
                Text("Generates a one-time code your sponsor enters to link. They'll approve your unlocks and get alerted if protection drops.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if nameMissing && (activeProtected != nil || pendingProtected != nil) {
                Text("Add your name in Account above so your sponsor knows it's you.")
                    .font(.caption).foregroundStyle(PawlColor.brand)
            }
        }

        Section("Are you a sponsor?") {
            TextField("Enter invite code", text: $codeEntry)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .tracking(2)
            Button("Link as sponsor") {
                Task { await sponsor.redeem(code: codeEntry); codeEntry = "" }
            }
            .disabled(sponsor.isBusy || codeEntry.isEmpty)

            ForEach(sponsor.asSponsor.filter { $0.status == "active" }) { link in
                LabeledContent("Sponsoring", value: sponsor.sponseeName(for: link))
                Button("Stop sponsoring", role: .destructive) {
                    Task { await sponsor.revokeAsSponsor(link) }
                }
                .disabled(sponsor.isBusy)
            }
            Text("You can sponsor more than one person — enter another code above to add them. Approve unlock requests in the Approvals tab; stopping returns someone to solo mode.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if let message = sponsor.message {
            Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    // MARK: - Lapse behavior (docs/12 §8)

    /// Shown under an existing (active or pending) link when Pro has lapsed. The link is never
    /// auto-severed — removing someone's safety net mid-relapse is the one thing we won't do — and
    /// the existing approval loop keeps working client-side. What lapsing costs you is NEW invites
    /// (gated above). Alert *suppression* on full lapse is server-side work (docs/12 §7) — until the
    /// sponsor RPCs check `is_pro`, alerts keep flowing; this row just prompts the renewal honestly.
    @ViewBuilder
    private var lapsedRenewRow: some View {
        if !hasAccountability {
            Button("Renew Pawl Pro") { onUnlock() }
            Text("Your Pro subscription has lapsed. Your sponsor link stays — nothing is severed — but you'll need Pro to link a new sponsor.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
