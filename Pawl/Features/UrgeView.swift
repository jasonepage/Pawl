// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UrgeView.swift
//  Pawl, the tough-moment screen
//
//  2.2: rebuilt around what helps in the moment. A ten-minute wait timer (urges peak and
//  fade), the person's own notes from past moments, their numbers, then the log, a call
//  button and help lines. Never offers an unblock control (FR-URGE-003).
//

import SwiftUI

struct UrgeView: View {
    let streakDays: Int
    /// Times the person has logged an urge and ridden it out. Only ever goes up.
    var rodeOutCount: Int = 0
    /// "about 210 hours kept since your count started", or nil when unknown.
    var keptLine: String? = nil
    /// Their own notes from past tough moments and relapses, newest first.
    var pastNotes: [String] = []
    /// 2.3: show the problem gambling help link only when gambling is the focus.
    var showGamblingHelp: Bool = false
    var onLog: (_ intensity: Int?, _ trigger: String?, _ note: String?) -> Void

    private static let waitSeconds: TimeInterval = 10 * 60

    @State private var waitEndsAt: Date?
    @State private var intensity = 5.0
    @State private var trigger = ""
    @State private var note = ""
    @State private var logged = false
    @State private var trustedName = ""
    @State private var trustedPhone = ""
    @State private var showNoContactHint = false
    @State private var showAllNotes = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                waitCard
                numbersLine
                if !pastNotes.isEmpty { ownWordsCard }

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
                    if showGamblingHelp {
                        Link("Problem gambling help, 24/7",
                             destination: URL(string: "https://www.ncpgambling.org/help-treatment/")!)
                    }
                    Link("Crisis support, call 988",
                         destination: URL(string: "tel://988")!)
                }
                .font(.callout)
                .tint(PawlColor.brand)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(PawlColor.groupedBg)
        .navigationTitle("Tempted")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trustedName = TrustedContact.name() ?? ""
            trustedPhone = TrustedContact.phone() ?? ""
        }
    }

    // MARK: Wait timer

    private var waitCard: some View {
        VStack(spacing: 14) {
            if let endsAt = waitEndsAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, endsAt.timeIntervalSince(context.date))
                    if remaining > 0 {
                        VStack(spacing: 14) {
                            ZStack {
                                PawlRing(progress: 1 - remaining / Self.waitSeconds,
                                         color: PawlColor.brand, track: PawlColor.brand.opacity(0.18))
                                VStack(spacing: 2) {
                                    Text(countdown(remaining))
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                    Text("don't decide yet")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(PawlColor.cleanText)
                            }
                            .frame(width: 180, height: 180)
                            Text("Urges peak and fade on their own, usually in 10 to 20 minutes. All you have to do is nothing.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(PawlColor.brand)
                            Text("Ten minutes. You stayed.")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(PawlColor.cleanText)
                            Text("If it's still there, start another ten. It is weaker than it was.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Another ten minutes") { startWait() }
                                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
                        }
                    }
                }
            } else {
                Text("This passes.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(PawlColor.cleanText)
                Text("Urges peak and fade on their own, usually in 10 to 20 minutes. Give it ten before you decide anything.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    startWait()
                } label: {
                    Label("Wait 10 minutes", systemImage: "hourglass")
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [PawlColor.urgeBg.opacity(0.9), PawlColor.urgeBg.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom),
            ignoresSafeAreaEdges: []
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func startWait() {
        waitEndsAt = Date().addingTimeInterval(Self.waitSeconds)
    }

    private func countdown(_ remaining: TimeInterval) -> String {
        let r = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", r / 60, r % 60)
    }

    // MARK: Numbers

    private var numbersLine: some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                stat("\(streakDays)", streakDays == 1 ? "day on track" : "days on track")
                if rodeOutCount > 0 {
                    stat("\(rodeOutCount)", rodeOutCount == 1 ? "time resisted" : "times resisted")
                }
            }
            if let keptLine {
                Text(keptLine.prefix(1).uppercased() + keptLine.dropFirst())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PawlColor.cleanText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ number: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(number)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PawlColor.cleanText)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Their own words

    private var ownWordsCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("In your own words").font(.headline)
                Text("What you wrote in past moments.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array((showAllNotes ? pastNotes : Array(pastNotes.prefix(2))).enumerated()), id: \.offset) { _, n in
                    Text("\u{201C}\(n)\u{201D}")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                }
                if pastNotes.count > 2 {
                    Button(showAllNotes ? "Show fewer" : "Show more") {
                        withAnimation { showAllNotes.toggle() }
                    }
                    .font(.footnote)
                    .foregroundStyle(PawlColor.brand)
                }
            }
        }
    }

    // MARK: Log

    private func callTrustedContact() {
        let cleaned = trustedPhone.filter { $0.isNumber || $0 == "+" }
        guard !cleaned.isEmpty, let url = URL(string: "tel://\(cleaned)") else {
            withAnimation { showNoContactHint = true }
            return
        }
        openURL(url)
    }

    private var logCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Write it down").font(.headline)
                Text("Future you will read this next time you're tempted.")
                    .font(.caption).foregroundStyle(.secondary)

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

                PawlField("What set it off?", prompt: "bored, stressed, a notification", text: $trigger)
                PawlField("What would you tell yourself right now?", prompt: "a note to future you", text: $note, multiline: true)

                Button {
                    onLog(Int(intensity), trigger, note)
                    withAnimation { logged = true }
                } label: {
                    Text("I resisted")
                }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.urgeBg, foreground: PawlColor.urgeText))
            }
        }
    }
}

#Preview {
    NavigationStack {
        UrgeView(streakDays: 7, rodeOutCount: 3, keptLine: "about 21 hours kept since your count started",
                 pastNotes: ["It was payday and I was bored.", "Called Sam instead. Fine an hour later."]) { _, _, _ in }
    }
}
