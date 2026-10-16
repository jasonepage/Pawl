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
import StoreKit

struct HomeView: View {
    /// True when no security key is paired yet — shows a nudge to pair (unlocking needs a key).
    var needsKey: Bool = false
    /// True when Screen Time authorization is missing (e.g. after a reinstall) — protection is off.
    var screenTimeOff: Bool = false
    /// One line of what is blocked, for example "Gambling · 3 apps · 2 sites". From AppModel.
    var blockedSummary: String = ""
    /// A scheduled set whose hours are on right now, if any.
    var activeSetName: String? = nil
    /// Setup answer, hours a day that went to the habit. 0 when unknown.
    var hoursPerDay: Double = 0
    /// Jump to the Unlock tab, where the (free) first pairing lives.
    var onPairKey: () -> Void = {}
    /// Re-request Screen Time authorization (Settings has the same control).
    var onEnableScreenTime: () -> Void = {}
    /// Open Settings > What's blocked.
    var onShowBlocked: () -> Void = {}
    /// Driven by ContentView when someone pressed "I need a minute" on the block screen.
    /// A binding rather than local state, because a TabView keeps unselected tabs alive and
    /// this view is not always the one on screen when the flag arrives (FR-SHACT-004).
    var showUrge: Binding<Bool> = .constant(false)

    @State private var vm = HomeViewModel()
    @State private var showRelapseSheet = false
    @Environment(\.requestReview) private var requestReview
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 76

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if screenTimeOff { screenTimeBanner }
                    streakHero
                    urgeButton
                    if needsKey { keyNudge }
                    blockedCard
                    if let week = vm.week { WeekCard(report: week, hoursPerDay: hoursPerDay) }
                    if !vm.history.isEmpty { historyCard }
                    relapseButton
                }
                .padding(20)
            }
            .background(PawlColor.groupedBg)
            .toolbar(.hidden, for: .navigationBar)
            .task { await vm.load() }
            .refreshable { await vm.refresh() }
            // A streak milestone is an earned moment: ask for a rating once per milestone.
            .onChange(of: vm.cleanDays, initial: true) { _, days in
                guard milestones.contains(days),
                      ReviewPrompter.shouldAsk(.streakMilestone, tag: "\(days)") else { return }
                askForReview()
            }
            .sheet(isPresented: $showRelapseSheet) {
                RelapseSheet { note, amount, when in
                    Task { await vm.logRelapse(note: note, amount: amount, occurredAt: when) }
                }
            }
            // A shield action extension cannot open its containing app, so the handoff from
            // the block screen is deferred: the extension leaves a flag and ContentView picks
            // it up on launch or on resume, selects this tab, and flips the binding. Same push
            // as the button, so the person sees one urge flow, not two (FR-SHACT-004).
            // Popping back sets the binding false again, since navigationDestination is two way.
            .navigationDestination(isPresented: showUrge) {
                UrgeView(streakDays: vm.cleanDays, rodeOutCount: vm.urges.count,
                         keptLine: keptSinceStart, pastNotes: pastNotes) { intensity, trigger, note in
                    Task {
                        await vm.logUrge(intensity: intensity, trigger: trigger, note: note)
                        // Riding out a few urges with the shield up is the win Pawl exists for.
                        if vm.urges.count >= ReviewPrompter.minUrgesBeforeAsk,
                           ReviewPrompter.shouldAsk(.urgeLogged) {
                            askForReview()
                        }
                    }
                }
            }
        }
        .tint(PawlColor.brand)
    }

    /// Shows the system rating sheet after a short pause so it never lands mid-transition.
    /// iOS decides whether to actually show it (at most three times a year).
    private func askForReview() {
        Task {
            try? await Task.sleep(for: ReviewPrompter.askDelay)
            requestReview()
        }
    }


    // MARK: Tough-moment inputs

    /// "about 210 hours kept since you started", from the setup answer and the days on track.
    private var keptSinceStart: String? {
        guard let kept = TimeCost.keptText(hoursPerDay: hoursPerDay, days: vm.cleanDays) else { return nil }
        return "\(kept) kept since your count started"
    }

    /// The person's own notes from past tough moments and relapses, newest first.
    private var pastNotes: [String] {
        vm.history.compactMap { entry in
            guard let n = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
            return n
        }
    }

    // MARK: Streak hero

    private let milestones = [7, 30, 60, 90, 180, 365]
    private var hitMilestone: Int? { milestones.first { $0 == vm.cleanDays } }
    private var nextMilestone: Int? { milestones.first { $0 > vm.cleanDays } }

    /// The milestone just passed, so the ring shows progress from it to the next one.
    private var lastMilestone: Int { milestones.last { $0 <= vm.cleanDays } ?? 0 }

    /// 0...1 toward the next milestone. Full once the last milestone is passed.
    private var ringProgress: Double {
        guard let n = nextMilestone else { return 1 }
        let span = Double(n - lastMilestone)
        guard span > 0 else { return 1 }
        return Double(vm.cleanDays - lastMilestone) / span
    }

    private var ringColor: Color { screenTimeOff ? PawlColor.dangerText : PawlColor.brand }

    private var streakHero: some View {
        VStack(spacing: 16) {
            ZStack {
                PawlRing(progress: ringProgress, color: ringColor, track: ringColor.opacity(0.18))
                VStack(spacing: 2) {
                    Text("\(vm.cleanDays)")
                        .font(.system(size: heroNumberSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(vm.cleanDays == 1 ? "day on track" : "days on track")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(PawlColor.cleanText)
                .padding(24)
            }
            .frame(width: 200, height: 200)
            .padding(.top, 4)

            if let m = hitMilestone {
                Label("\(m)-day milestone reached", systemImage: "rosette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawlColor.cleanText)
            } else if let n = nextMilestone {
                Text("\(n - vm.cleanDays) \(n - vm.cleanDays == 1 ? "day" : "days") to your \(n)-day milestone")
                    .font(.subheadline)
                    .foregroundStyle(PawlColor.cleanText)
                    .opacity(0.85)
            } else {
                Text("Past every milestone. Keep going.")
                    .font(.subheadline)
                    .foregroundStyle(PawlColor.cleanText)
                    .opacity(0.85)
            }

            if vm.urges.count > 0 {
                Label(vm.urges.count == 1 ? "Rode it out 1 time" : "Rode it out \(vm.urges.count) times",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawlColor.cleanText)
            }

            statusPill
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [PawlColor.cleanBg, PawlColor.cleanBg.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom),
            ignoresSafeAreaEdges: []
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityHeroLabel)
    }

    private var accessibilityHeroLabel: String {
        let days = vm.cleanDays == 1 ? "1 day on track" : "\(vm.cleanDays) days on track"
        if screenTimeOff { return "\(days). Screen Time is off, so nothing is blocked." }
        if needsKey { return "\(days). Blocks are on. No key paired yet." }
        return "\(days). Protected."
    }

    /// One pill under the ring that says, in plain words, the state that matters most.
    @ViewBuilder
    private var statusPill: some View {
        if screenTimeOff {
            pill("Screen Time is off", "exclamationmark.triangle.fill",
                 bg: PawlColor.dangerText.opacity(0.15), fg: PawlColor.dangerText)
        } else if needsKey {
            pill("Blocks on, no key yet", "key", bg: PawlColor.urgeBg, fg: PawlColor.urgeText)
        } else {
            pill("Protected", "lock.fill", bg: PawlColor.cardBg, fg: PawlColor.cleanText)
        }
    }

    private func pill(_ text: String, _ symbol: String, bg: Color, fg: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
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
                    Text("Your blocks are on, but unlocking won't work until a key is paired. Tap to set it up.")
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
            UrgeView(streakDays: vm.cleanDays, rodeOutCount: vm.urges.count,
                     keptLine: keptSinceStart, pastNotes: pastNotes) { intensity, trigger, note in
                Task { await vm.logUrge(intensity: intensity, trigger: trigger, note: note) }
            }
        } label: {
            Label("I'm in a tough moment", systemImage: "lifepreserver")
        }
        .buttonStyle(PawlBigButtonStyle(background: PawlColor.urgeBg, foreground: PawlColor.urgeText))
        .accessibilityHint("Opens a breathing exercise. Never unlocks anything.")
    }

    // MARK: What's blocked

    private var blockedCard: some View {
        Button(action: onShowBlocked) {
        PawlCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("What's blocked").font(.headline)
                    Spacer(minLength: 8)
                    Image(systemName: screenTimeOff ? "lock.open" : "lock.fill")
                        .foregroundStyle(screenTimeOff ? PawlColor.dangerText : PawlColor.brand)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(blockedSummary.isEmpty ? "Nothing yet" : blockedSummary)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let name = activeSetName {
                    Label("\(name) is on right now", systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(screenTimeOff ? "Screen Time is off, so nothing is blocked" : "Locked by your key")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Settings, What's blocked.")
    }

    // MARK: Relapse

    /// Quiet on purpose: easy to find, never the loudest thing on the screen.
    private var relapseButton: some View {
        Button { showRelapseSheet = true } label: {
            Label("Log a relapse", systemImage: "arrow.counterclockwise")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(PawlColor.dangerText)
        }
        .accessibilityHint("Opens a private note. Your shield stays on.")
    }

    // MARK: History

    @State private var entryToRemove: HomeViewModel.HistoryEntry?

    private var historyCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("History").font(.headline)
                ForEach(vm.history.prefix(8)) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        historyBadge(entry)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.occurredAt, format: .dateTime.month().day().year())
                                .font(.subheadline)
                            if let note = entry.note, !note.isEmpty {
                                Text(note).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Button {
                            entryToRemove = entry
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove this entry")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("This log is yours. Remove an entry if it was a mistake.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .confirmationDialog("Remove this entry?", isPresented: Binding(
            get: { entryToRemove != nil },
            set: { if !$0 { entryToRemove = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let e = entryToRemove {
                    Task {
                        switch e {
                        case .relapse(let r): await vm.removeRelapse(r)
                        case .urge(let u):    await vm.removeUrge(u)
                        }
                    }
                }
                entryToRemove = nil
            }
        } message: {
            Text(removalMessage)
        }
    }

    private var removalMessage: String {
        if case .relapse = entryToRemove {
            return "Your count will be recalculated from the entries that are left."
        }
        return "This only removes the note. Nothing else changes."
    }

    /// Green "Rode it out" for an urge, red "Relapse" for a relapse.
    @ViewBuilder
    private func historyBadge(_ entry: HomeViewModel.HistoryEntry) -> some View {
        switch entry {
        case .urge:
            Label("Rode it out", systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(PawlColor.cleanBg)
                .foregroundStyle(PawlColor.cleanText)
                .clipShape(Capsule())
        case .relapse:
            Label("Relapse", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(PawlColor.dangerText.opacity(0.12))
                .foregroundStyle(PawlColor.dangerText)
                .clipShape(Capsule())
        }
    }
}

/// Logging a relapse, one step at a time. The first screen is just a kind line and a
/// button; the note and the amount are each their own screen and each can be skipped.
/// Nothing here scolds. The shield never changes.
private struct RelapseSheet: View {
    var onSave: (String?, Decimal?, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var when = Date()
    @State private var note = ""
    @State private var amountText = ""
    @FocusState private var focused: Bool

    private let totalSteps = 4
    private var doneStep: Int { totalSteps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PawlStepDots(current: min(step, totalSteps - 1), total: totalSteps)
                    .padding(.top, 14)
                ScrollView {
                    VStack(spacing: 22) {
                        content
                    }
                    .padding(20)
                }
                footer
                    .padding(20)
            }
            .background(PawlColor.groupedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step < doneStep {
                        Button(step == 0 ? "Cancel" : "Back") {
                            if step == 0 { dismiss() } else { step -= 1 }
                        }
                    }
                }
            }
        }
        .tint(PawlColor.brand)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            PawlArt("heart.fill", size: 100).padding(.top, 8)
            VStack(spacing: 8) {
                Text("That's okay.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Slips happen. Writing it down is a strong move, not a failure. Your blocks stay on the whole time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
        case 1:
            PawlArt("calendar", size: 100).padding(.top, 8)
            VStack(spacing: 8) {
                Text("When did it happen?")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Today is fine. If it was a few days ago, pick that day so your count is honest.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            DatePicker("When", selection: $when, in: ...Date(), displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding(8)
                .background(PawlColor.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case 2:
            PawlArt("text.bubble", size: 100).padding(.top, 8)
            VStack(spacing: 8) {
                Text("What happened?")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("A few words for your future self. Only you will see this.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            TextField("What was going on, what led up to it", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .focused($focused)
                .padding(14)
                .background(PawlColor.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onAppear { focused = true }
        case 3:
            PawlArt("banknote", size: 100).padding(.top, 8)
            VStack(spacing: 8) {
                Text("Did it cost anything?")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Money, if it did. Leave it blank if not.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($focused)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(PawlColor.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onAppear { focused = true }
        default:
            PawlArt("lock.fill", size: 100).padding(.top, 8)
            VStack(spacing: 8) {
                Text("Logged.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text(Calendar.current.isDateInToday(when)
                     ? "Your shield is still on. Tomorrow is day one, and that counts."
                     : "Your shield is still on. Your count now starts from that day.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch step {
        case 0:
            Button("Write it down") { step = 1 }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
        case 1:
            Button(Calendar.current.isDateInToday(when) ? "It was today" : "Next") { step = 2 }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
        case 2:
            VStack(spacing: 10) {
                Button("Next") { focused = false; step = 3 }
                    .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
                Button("Skip") { focused = false; step = 3 }
                    .font(.footnote).foregroundStyle(PawlColor.brand)
            }
        case 3:
            VStack(spacing: 10) {
                Button("Save") { save() }
                    .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
                Button("Skip and save") { amountText = ""; save() }
                    .font(.footnote).foregroundStyle(PawlColor.brand)
            }
        default:
            Button("Done") { dismiss() }
                .buttonStyle(PawlBigButtonStyle(background: PawlColor.cleanBg, foreground: PawlColor.cleanText))
        }
    }

    private func save() {
        focused = false
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // A past day is logged at noon on that day; today keeps the real time.
        let stamp = Calendar.current.isDateInToday(when)
            ? Date()
            : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: when) ?? when)
        onSave(trimmed.isEmpty ? nil : trimmed, Decimal(string: amountText), stamp)
        step = doneStep
    }
}

#Preview {
    HomeView()
}
