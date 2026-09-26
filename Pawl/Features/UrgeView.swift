// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UrgeView.swift
//  Pawl — urge / panic flow
//
//  A guided breathing exercise + the option to log the urge (SRS FR-URGE-001..005).
//  Never offers an "unblock" control (FR-URGE-003): the only path is through the urge.
//  Redesigned for calm and accessibility (large type, dark mode, VoiceOver).
//

import SwiftUI

struct UrgeView: View {
    let streakDays: Int
    var onLog: (_ intensity: Int?, _ trigger: String?, _ note: String?) -> Void

    @State private var breatheIn = false
    /// Drives the label only. Kept separate from `breatheIn` on purpose: `breatheIn` is set
    /// once inside a repeatForever animation, so its logical value never changes again and
    /// the Text transition it started is left permanently half way through, which is why
    /// "Breathe in" and "Breathe out" were rendering on top of each other. This one is
    /// flipped by the same loop that paces the haptics, with animation switched off.
    @State private var inhaleLabel = true
    @State private var intensity = 5.0
    @State private var trigger = ""
    @State private var note = ""
    @State private var logged = false
    @State private var trustedName = ""
    @State private var trustedPhone = ""
    @State private var showNoContactHint = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                breathingCircle
                streakLine
                Text("These moments peak and pass, usually within minutes. Stay with the breath — you don't have to act.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if logged {
                    Label("Logged. That took strength.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(PawlColor.cleanText)
                        .padding(.vertical, 8)
                } else {
                    logCard
                }

                Button {
                    callTrustedContact()
                } label: {
                    Label(trustedName.isEmpty ? "Call someone I trust" : "Call \(trustedName)",
                          systemImage: "phone.fill")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .tint(PawlColor.brand)
                .buttonStyle(.bordered)

                if showNoContactHint {
                    Text("Add someone you trust in Settings, and this button will call them.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Link("Problem gambling help — 24/7",
                         destination: URL(string: "https://www.ncpgambling.org/help-treatment/")!)
                    Link("Crisis support — call 988",
                         destination: URL(string: "tel://988")!)
                }
                .font(.callout)
                .tint(PawlColor.brand)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(PawlColor.groupedBg)
        .navigationTitle("Ride it out")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breatheIn = true
            }
            trustedName = TrustedContact.name() ?? ""
            trustedPhone = TrustedContact.phone() ?? ""
        }
        // Soft haptic pacer synced to the 4s-in / 4s-out breathing circle. Auto-cancels on exit.
        .task {
            while !Task.isCancelled {
                inhaleLabel = true
                Feedback.breatheInhale()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                inhaleLabel = false
                Feedback.breatheExhale()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func callTrustedContact() {
        let cleaned = trustedPhone.filter { $0.isNumber || $0 == "+" }
        guard !cleaned.isEmpty, let url = URL(string: "tel://\(cleaned)") else {
            withAnimation { showNoContactHint = true }
            return
        }
        openURL(url)
    }

    private var breathingCircle: some View {
        Circle()
            .fill(PawlColor.cleanBg)
            .frame(width: 200, height: 200)
            .scaleEffect(breatheIn ? 1.0 : 0.7)
            .overlay(
                Text(inhaleLabel ? "Breathe in" : "Breathe out")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PawlColor.cleanText)
                    .contentTransition(.identity)
                    // Swap the words instantly. Never inherit the circle's animation.
                    .transaction { $0.animation = nil }
            )
            .padding(.top, 16)
            .accessibilityLabel("Breathing guide")
    }

    private var streakLine: some View {
        VStack(spacing: 2) {
            Text("\(streakDays)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PawlColor.cleanText)
            Text(streakDays == 1 ? "day on the line" : "days on the line")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streakDays) days on the line")
    }

    private var logCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Log this moment").font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("How strong is it?  \(Int(intensity))/10")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $intensity, in: 1...10, step: 1)
                        .tint(PawlColor.brand)
                    HStack {
                        Text("Mild"); Spacer(); Text("Overwhelming")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                PawlField("What set it off?", prompt: "bored, payday, a text…", text: $trigger)
                PawlField("Anything else?", prompt: "a note to future you", text: $note, multiline: true)

                Button {
                    onLog(Int(intensity), trigger, note)
                    Feedback.milestone()   // resisting + logging took strength — affirm it
                    withAnimation { logged = true }
                } label: {
                    Text("Log it")
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.urgeBg, foreground: PawlColor.urgeText))

                Text("Noticing your triggers is how the pattern loses its grip.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { UrgeView(streakDays: 7) { _, _, _ in } }
}
