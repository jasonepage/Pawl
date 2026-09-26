// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  HomeView.swift
//  Pawl — Home
//
//  Clean-day streak, the urge/panic entry point, and the relapse log
//  (SRS §3.5, §3.6). Redesigned for calm, high-contrast, large-target accessibility:
//  Dynamic Type, dark mode, and VoiceOver. Runs today without any capabilities.
//

import SwiftUI

struct HomeView: View {
    /// True when no security key is paired yet — shows a nudge to pair (unlocking needs a key).
    var needsKey: Bool = false
    /// True when Screen Time authorization is missing (e.g. after a reinstall) — protection is off.
    var screenTimeOff: Bool = false
    /// Jump to the Unlock tab, where the (free) first pairing lives.
    var onPairKey: () -> Void = {}
    /// Re-request Screen Time authorization (Settings has the same control).
    var onEnableScreenTime: () -> Void = {}
    /// Driven by ContentView when someone pressed "I need a minute" on the block screen.
    /// A binding rather than local state, because a TabView keeps unselected tabs alive and
    /// this view is not always the one on screen when the flag arrives (FR-SHACT-004).
    var showUrge: Binding<Bool> = .constant(false)

    @State private var vm = HomeViewModel()
    @State private var showRelapseSheet = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 76

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if screenTimeOff { screenTimeBanner }
                    streakHero
                    if needsKey { keyNudge }
                    urgeButton
                    statusCard
                    CaughtCard()
                    relapseButton
                    if !vm.relapses.isEmpty { historyCard }
                }
                .padding(20)
            }
            .background(PawlColor.groupedBg)
            .toolbar(.hidden, for: .navigationBar)
            .task { await vm.load() }
            .refreshable { await vm.refresh() }
            .sheet(isPresented: $showRelapseSheet) {
                RelapseSheet { note, amount in
                    Task { await vm.logRelapse(note: note, amount: amount) }
                }
            }
            // A shield action extension cannot open its containing app, so the handoff from
            // the block screen is deferred: the extension leaves a flag and ContentView picks
            // it up on launch or on resume, selects this tab, and flips the binding. Same push
            // as the button, so the person sees one urge flow, not two (FR-SHACT-004).
            // Popping back sets the binding false again, since navigationDestination is two way.
            .navigationDestination(isPresented: showUrge) {
                UrgeView(streakDays: vm.cleanDays) { intensity, trigger, note in
                    Task { await vm.logUrge(intensity: intensity, trigger: trigger, note: note) }
                }
            }
        }
        .tint(PawlColor.brand)
    }


    // MARK: Streak hero

    private let milestones = [7, 30, 60, 90, 180, 365]
    private var hitMilestone: Int? { milestones.first { $0 == vm.cleanDays } }
    private var nextMilestone: Int? { milestones.first { $0 > vm.cleanDays } }

    private var streakHero: some View {
        VStack(spacing: 4) {
            Text("You're on a streak")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PawlColor.cleanText)
            Text("\(vm.cleanDays)")
                .font(.system(size: heroNumberSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PawlColor.cleanText)
            Text(vm.cleanDays == 1 ? "day on track" : "days on track")
                .font(.title2)
                .foregroundStyle(PawlColor.cleanText)
            if let m = hitMilestone {
                Label("\(m)-day milestone reached", systemImage: "rosette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawlColor.cleanText)
                    .padding(.top, 6)
            } else if let n = nextMilestone {
                Text("\(n - vm.cleanDays) \(n - vm.cleanDays == 1 ? "day" : "days") to your \(n)-day milestone")
                    .font(.subheadline)
                    .foregroundStyle(PawlColor.cleanText)
                    .opacity(0.85)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(PawlColor.cleanBg)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vm.cleanDays == 1 ? "1 day on track" : "\(vm.cleanDays) days on track")
    }

    // MARK: Screen Time banner (protection is off — re-enable)

    private var screenTimeBanner: some View {
        Button(action: onEnableScreenTime) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(PawlColor.dangerText)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Time is off")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Pawl isn't blocking anything right now. Tap to re-enable Screen Time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PawlColor.dangerText.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Re-enables Screen Time so Pawl can block apps and sites.")
    }

    // MARK: Pair-key nudge (only while no key is paired)

    private var keyNudge: some View {
        Button(action: onPairKey) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.headline)
                    .foregroundStyle(PawlColor.brand)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pair your security key")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Your blocks are on — but unlocking won't work until a key is paired. Tap to set it up.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PawlColor.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Unlock tab to pair your security key.")
    }

    // MARK: Urge button (the most important action)

    private var urgeButton: some View {
        NavigationLink {
            UrgeView(streakDays: vm.cleanDays) { intensity, trigger, note in
                Task { await vm.logUrge(intensity: intensity, trigger: trigger, note: note) }
            }
        } label: {
            Label("I'm in a tough moment", systemImage: "lifepreserver")
        }
        .buttonStyle(PawlBigButtonStyle(background: PawlColor.urgeBg, foreground: PawlColor.urgeText))
        .accessibilityHint("Opens a breathing exercise. Never unlocks anything.")
    }

    // MARK: Shield status

    private var statusCard: some View {
        PawlCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apps & sites").font(.title2)
                    Text("Locked by your key")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if screenTimeOff {
                    Label("Off", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PawlColor.dangerText.opacity(0.15))
                        .foregroundStyle(PawlColor.dangerText)
                        .clipShape(Capsule())
                } else {
                    Label("Protected", systemImage: "lock.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PawlColor.cleanBg)
                        .foregroundStyle(PawlColor.cleanText)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: Relapse

    private var relapseButton: some View {
        Button { showRelapseSheet = true } label: {
            Text("Log a Relapse")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(PawlColor.dangerText)
                .background(PawlColor.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: History

    private var historyCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("History").font(.headline)
                ForEach(vm.relapses.prefix(5)) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.occurredAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.subheadline)
                        if let note = event.note, !note.isEmpty {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// Sheet to capture an optional note + amount when logging a relapse.
private struct RelapseSheet: View {
    var onSave: (String?, Decimal?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened? (optional)") {
                    TextField("A note to your future self", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Amount lost (optional)") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Text("Logging this is an act of honesty, not failure. Your shield stays on.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log a Relapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(note, Decimal(string: amountText))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
