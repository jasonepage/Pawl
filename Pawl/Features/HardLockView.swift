// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  HardLockView.swift
//  Pawl — Phase 3 scaffolding (sponsor-set Screen Time passcode)
//
//  The guided "guide → test → attest" flow (docs/11_Phase3_Passcode.md). NON-FUNCTIONAL by
//  necessity: iOS gives no API to set, read, or even detect the Screen Time passcode, so this
//  walks the sponsor through doing it in Settings, has them verify it in person, and records
//  their attestation. iOS enforces the lock; Pawl never holds it. Server attestation + the
//  high-priority tamper escalation are later build steps.
//

import SwiftUI

struct HardLockView: View {
    var onAttest: () -> Void
    var onReset: () -> Void = {}
    let alreadyAttested: Bool
    let attestedDate: Date?

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if alreadyAttested {
                    attestedState
                } else {
                    content
                    footer
                }
            }
            .padding(20)
        }
        .background(PawlColor.groupedBg)
        .navigationTitle("Hard lock")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            heading("The hard lock", "The only truly unfakeable tier.")
            body("Pawl's shield is strong, but a determined person can still delete the app or turn off Screen Time. The one thing that closes those last doors is a Screen Time passcode they don't know — set by you, their sponsor, in person.")
            body("Pawl can't see, set, or recover this passcode. iOS enforces it; you hold it. If it's ever forgotten, only Apple's device-reset process can clear it.")
        case 1:
            heading("1 · Set the passcode", "In the Settings app — not here.")
            steps([
                "Open Settings → Screen Time.",
                "Tap \u{201C}Use Screen Time Passcode.\u{201D}",
                "Choose a 4-digit code they never see.",
                "Set the recovery Apple ID to yours (or skip it).",
                "While there, turn on Content & Privacy Restrictions."
            ])
        case 2:
            heading("2 · Test it", "Prove the lock actually holds.")
            body("Still in Settings → Screen Time, try to turn off Pawl's access (or change a restriction). If the passcode is set right, iOS will demand the passcode and block the change.")
            body("It must demand the secret Screen Time passcode. If Face ID, a fingerprint, or your device passcode lets the change through, the lock is NOT set right — fix that before you attest, or it's a false sense of security.")
            body("Do this now, together. Only attest if the Screen Time passcode prompt is the only way through.")
        default:
            heading("3 · Confirm", "You set it and saw it work.")
            body("You're attesting that you set the Screen Time passcode and verified it blocks changes. Pawl records this as your attestation — not something Pawl can check itself. If protection is ever removed anyway, you'll get a tamper alert.")
        }
    }

    @ViewBuilder private var footer: some View {
        if step < 3 {
            primary("Continue") { step += 1 }
        } else {
            primary("Passcode set and verified") { onAttest(); dismiss() }
        }
        if step > 0 {
            Button("Back") { step -= 1 }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private var attestedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Hard lock is on", "Set by a sponsor.")
            if let d = attestedDate {
                Text("Attested \(d.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            body("A sponsor set the device Screen Time passcode and verified it. iOS enforces it — Pawl can't see or change it. If protection is ever removed, the sponsor is alerted.")

            Divider().padding(.vertical, 6)

            body("Set it up by mistake, or found a way past it? If a fingerprint, Face ID, or your device passcode let you change Pawl's restrictions, the lock isn't really on. Reset the attestation and set it up again.")
            Button("Reset hard lock", role: .destructive) { showResetConfirm = true }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .confirmationDialog("Reset the hard lock?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset hard lock", role: .destructive) { onReset(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears Pawl's record so you can set it up again. It does NOT change the device Screen Time passcode itself — to turn that off, go to Settings → Screen Time.")
        }
    }

    // MARK: Pieces

    private func heading(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.largeTitle.bold())
            Text(s).font(.title3).foregroundStyle(PawlColor.cleanText)
        }
        .padding(.top, 8)
    }

    private func body(_ t: String) -> some View {
        Text(t).font(.body).foregroundStyle(.secondary).lineSpacing(3)
    }

    private func steps(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(PawlColor.brand)
                    Text(s).font(.body)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity) }
            .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
    }
}

#Preview {
    NavigationStack { HardLockView(onAttest: {}, alreadyAttested: false, attestedDate: nil) }
}
