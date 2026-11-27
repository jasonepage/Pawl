// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsBlockingViews.swift
//  Pawl, Settings sub-screens (2.2, reworked in 2.3)
//
//  2.3: What's blocked is three small sections (always-on apps, websites, scheduled sets).
//  Each has its own page off the Settings index (Apps, Websites, Scheduled sets), and Home's
//  "What's blocked" card still opens all three together (BlockedItemsView). Then the unlock
//  timing, the trusted contact, and the "how it works" copy. Behavior is unchanged and still
//  goes through AppModel: adding is instant, removing needs the key + the wait.
//

import SwiftUI
import FamilyControls

// MARK: - Pages

/// Everything blocked on one page. Opened from Home's "What's blocked" card.
struct BlockedItemsView: View {
    let model: AppModel

    var body: some View {
        List {
            AppsBlockSection(model: model)
            WebsitesBlockSection(model: model)
            ScheduledSetsSection(model: model)
            BlockChangeMessageSection(model: model)
        }
        .navigationTitle("What's blocked")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedAppsView: View {
    let model: AppModel

    var body: some View {
        List {
            AppsBlockSection(model: model)
            BlockChangeMessageSection(model: model)
        }
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedWebsitesView: View {
    let model: AppModel

    var body: some View {
        List {
            WebsitesBlockSection(model: model)
            BlockChangeMessageSection(model: model)
        }
        .navigationTitle("Websites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScheduledSetsView: View {
    let model: AppModel

    var body: some View {
        List {
            ScheduledSetsSection(model: model)
            BlockChangeMessageSection(model: model)
        }
        .navigationTitle("Scheduled sets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The last thing a block change said ("Removal starts in 15 min..."), shown under the list.
struct BlockChangeMessageSection: View {
    let model: AppModel

    var body: some View {
        if let m = model.blockChangeMessage {
            Section {
                Text(m).font(.callout).foregroundStyle(PawlColor.brand)
            }
        }
    }
}

// MARK: - Sections

/// Always-on apps and categories, picked with Apple's Screen Time picker.
struct AppsBlockSection: View {
    let model: AppModel

    @State private var editSelection = FamilyActivitySelection()
    @State private var showBlockPicker = false

    var body: some View {
        Section {
            Button {
                editSelection = model.currentSelection
                showBlockPicker = true
            } label: {
                SettingsRows.detail("apps.iphone", .blue, "Choose apps", countLine, value: "Edit")
            }
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $editSelection)
            .onChange(of: showBlockPicker) { wasShowing, showing in
                if wasShowing && !showing {           // picker dismissed: apply the edit
                    Task { await model.requestSelectionChange(editSelection) }
                }
            }
            if let endsAt = model.pendingSelectionChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Removal applies in", value: SettingsRows.countdown(to: endsAt))
                }
                Button("Keep them blocked", role: .cancel) { model.cancelSelectionChange() }
            }
        } header: {
            Text("Always on")
        } footer: {
            // 2.3: popular app names for the person's focus (Screen Time can't pre-pick apps).
            Text([model.vertical.suggestedAppsLine,
                  "Blocked all day, every day. Adding apps works right away. Removing one needs your key and the wait, and it stays blocked until then."]
                .compactMap { $0 }.joined(separator: "\n\n"))
        }
    }

    private var countLine: String {
        let n = model.blockedSummary.apps
        switch n {
        case 0:  return "None yet"
        case 1:  return "1 app or category"
        default: return "\(n) apps and categories"
        }
    }
}

/// Website categories (gambling list, Apple's adult filter) and the user's own typed sites.
struct WebsitesBlockSection: View {
    let model: AppModel
    /// The category flags live in the App Group, which SwiftUI can't observe. Bumped after each
    /// change finishes so the toggles re-read the real state (a turn-off that is waiting, or was
    /// cancelled at the key, snaps back to on).
    @State private var refresh = 0

    var body: some View {
        let _ = refresh
        Section {
            Toggle(isOn: Binding(
                get: { model.gamblingOn },
                set: { on in
                    Task {
                        await model.requestWebCategories(gambling: on, adult: model.adultOn)
                        refresh += 1
                    }
                })) {
                SettingsRows.detail("dice.fill", .green, "Gambling sites",
                                    "Pawl's list of \(model.webBlockCount) sites")
            }
            Toggle(isOn: Binding(
                get: { model.adultOn },
                set: { on in
                    Task {
                        await model.requestWebCategories(gambling: model.gamblingOn, adult: on)
                        refresh += 1
                    }
                })) {
                SettingsRows.detail("eye.slash.fill", .indigo, "Adult sites", "Apple's adult website filter")
            }
            if let endsAt = model.pendingCategoryChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Turns off in", value: SettingsRows.countdown(to: endsAt))
                }
                Button("Keep it on", role: .cancel) {
                    model.cancelCategoryChange()
                    refresh += 1
                }
            }
            NavigationLink {
                CustomDomainsView(model: model)
            } label: {
                SettingsRows.detail("globe", .blue, "Your websites", ownLine)
            }
        } header: {
            Text("Websites")
        } footer: {
            Text("Turning a category on works right away. Turning it off needs your key and the wait, and it stays on until then.")
        }
    }

    private var ownLine: String {
        let n = model.customDomains.count
        switch n {
        case 0:  return "Add any site by its address"
        case 1:  return "1 site you added"
        default: return "\(n) sites you added"
        }
    }
}

// MARK: - Unlock timing

/// 2.3 redesign. A picture of what happens after the key (wait, then open, then lock), then
/// one-tap choices instead of 5-minute steppers. "now" marks the saved value. The save button
/// only appears once something changed, and says when the change takes effect. Behavior is
/// unchanged: stricter applies now, looser waits out the current wait (AppModel.requestDurations).
///
/// 2.4: "No wait" (0 minutes), "Until I lock it" (open time 0, PawlDefaults.openUntilLocked),
/// and a Custom time for each. Minutes are the unit here, with 0 meaning those two choices.
struct FrictionView: View {
    let model: AppModel

    @State private var waitMin = 15
    @State private var openMin = 30
    @State private var savedNote: String?
    @State private var customFor: TimeKind?

    private static let waitChoices = [0, 15, 20, 30, 45, 60, 90, 120]
    private static let openChoices = [15, 30, 45, 60, 90, 120, 180, 0]

    private var currentWait: Int { Int((model.cooldownSeconds / 60).rounded()) }
    private var currentOpen: Int { Int((model.graceSeconds / 60).rounded()) }
    private var changed: Bool { waitMin != currentWait || openMin != currentOpen }
    /// Same rule as AppModel: a longer (or equal) wait and a shorter (or equal) open time, where
    /// "Until I lock it" counts as the longest open time of all.
    private var isStricter: Bool { waitMin >= currentWait && Self.openRank(openMin) <= Self.openRank(currentOpen) }

    private static func openRank(_ minutes: Int) -> Int { minutes == 0 ? Int.max : minutes }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                timeline
                choiceCard(.wait, title: "Wait before unlocking",
                           detail: "Starts when you use your key.",
                           choices: options(Self.waitChoices, current: currentWait, picked: waitMin, kind: .wait),
                           selection: $waitMin, current: currentWait)
                choiceCard(.open, title: "Then open for",
                           detail: openMin == 0 ? "Open until you tap Lock now."
                                                : "Then Pawl locks again.",
                           choices: options(Self.openChoices, current: currentOpen, picked: openMin, kind: .open),
                           selection: $openMin, current: currentOpen)
                if waitMin == 0 || openMin == 0 { cautionCard }
                if let pending = model.pendingDurations { pendingCard(pending) }
                if changed { saveButton }
                if let savedNote {
                    Label(savedNote, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PawlColor.cleanText)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("Stricter saves now.", systemImage: "checkmark.circle")
                    Label("Looser waits out your current wait first.", systemImage: "clock")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .padReadableWidth()
        }
        .background(PawlColor.groupedBg)
        .navigationTitle("Unlock timing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            waitMin = currentWait
            openMin = currentOpen
        }
        .sheet(item: $customFor) { kind in
            CustomTimeSheet(kind: kind, startMinutes: kind == .wait ? max(waitMin, 5) : max(openMin, 15)) { minutes in
                if kind == .wait { waitMin = minutes } else { openMin = minutes }
                savedNote = nil
            }
        }
    }

    // MARK: Picture

    private var timeline: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("When you use your key").font(.headline)
                GeometryReader { geo in
                    let spacing: CGFloat = 6
                    let icon: CGFloat = 32
                    let bars = max(0, geo.size.width - icon * 2 - spacing * 3)
                    let showWait = waitMin > 0
                    let untilLocked = openMin == 0
                    let share = untilLocked ? 0.5 : Double(waitMin) / Double(max(1, waitMin + openMin))
                    let waitWidth: CGFloat = !showWait ? 0
                        : (bars < 140 ? bars / 2 : min(max(bars * share, 70), bars - 70))
                    HStack(spacing: spacing) {
                        stepIcon("key.fill", PawlColor.brand)
                        if showWait {
                            segment("\(DurationText.short(minutes: waitMin)) wait", bg: PawlColor.urgeBg, fg: PawlColor.urgeText)
                                .frame(width: waitWidth)
                        }
                        segment(untilLocked ? "open until you lock" : "\(DurationText.short(minutes: openMin)) open",
                                bg: PawlColor.cleanBg, fg: PawlColor.cleanText)
                            .frame(width: showWait ? max(0, bars - waitWidth) : bars + spacing)
                        stepIcon(untilLocked ? "hand.tap.fill" : "lock.fill", .secondary)
                    }
                }
                .frame(height: 36)
                Text(timelineSentence)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timelineSentence: String {
        let open = DurationText.short(minutes: openMin)
        switch (waitMin == 0, openMin == 0) {
        case (true, true):   return "Key, then open until you tap Lock now."
        case (true, false):  return "Key, then \(open) open, then locked again."
        case (false, true):  return "Key, then \(DurationText.short(minutes: waitMin)) wait, then open until you tap Lock now."
        case (false, false): return "Key, then \(DurationText.short(minutes: waitMin)) wait, then \(open) open, then locked again."
        }
    }

    private func stepIcon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(PawlColor.groupedBg, in: Circle())
    }

    private func segment(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
    }

    // MARK: Choices

    /// The preset list plus the saved value and the picked one (a custom time shows as its own
    /// button). "Until I lock it" (0) sorts last in the open list; "No wait" (0) first in the wait list.
    private func options(_ list: [Int], current: Int, picked: Int, kind: TimeKind) -> [Int] {
        let all = Array(Set(list + [current, picked]))
        return kind == .open ? all.sorted { Self.openRank($0) < Self.openRank($1) } : all.sorted()
    }

    private func label(_ minutes: Int, _ kind: TimeKind) -> String {
        kind == .wait ? DurationText.wait(seconds: Double(minutes) * 60)
                      : DurationText.open(seconds: Double(minutes) * 60)
    }

    private func choiceCard(_ kind: TimeKind, title: String, detail: String, choices: [Int],
                            selection: Binding<Int>, current: Int) -> some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(choices, id: \.self) { minutes in
                        let picked = selection.wrappedValue == minutes
                        Button {
                            selection.wrappedValue = minutes
                            savedNote = nil
                        } label: {
                            tile(label(minutes, kind), sub: minutes == current ? "now" : nil, picked: picked)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(minutes == current ? "\(label(minutes, kind)), current" : label(minutes, kind))
                        .accessibilityAddTraits(picked ? .isSelected : [])
                    }
                    Button {
                        customFor = kind
                    } label: {
                        tile("Custom", sub: nil, picked: false, symbol: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kind == .wait ? "Custom wait" : "Custom open time")
                }
            }
        }
    }

    private func tile(_ text: String, sub: String?, picked: Bool, symbol: String? = nil) -> some View {
        VStack(spacing: 1) {
            if let symbol {
                Image(systemName: symbol).font(.caption.weight(.semibold))
            }
            Text(text)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if let sub {
                Text(sub).font(.caption2)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(picked ? PawlColor.brand : PawlColor.groupedBg)
        .foregroundStyle(picked ? Color.white : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Plain words about what the two open-ended choices mean. Not a warning siren.
    private var cautionCard: some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 8) {
                if waitMin == 0 {
                    Label("No wait: your key opens apps at once. Hide it well.",
                          systemImage: "key.fill")
                }
                if openMin == 0 {
                    Label("Until I lock it: apps stay open until you tap Lock now.",
                          systemImage: "hand.tap.fill")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Save and pending

    private var saveButton: some View {
        Button {
            let stricter = isStricter
            Task {
                await model.requestDurations(cooldown: Double(waitMin) * 60, grace: Double(openMin) * 60)
                // Show what is in effect now. A looser change waits in the card above.
                waitMin = currentWait
                openMin = currentOpen
                // 2.4: a looser change needs the key first, so the note comes from the model
                // ("Saved. It applies in 15 min." or "Key check cancelled. Nothing changed.").
                savedNote = stricter ? "Saved. It applies now." : model.blockChangeMessage
            }
        } label: {
            Text(isStricter ? "Save. Applies now" : "Use your key. Starts \(DurationText.startsIn(waitSeconds: model.cooldownSeconds))")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PawlBigButtonStyle(background: PawlColor.brand, foreground: .white))
    }

    private func pendingCard(_ pending: PendingDurations) -> some View {
        PawlCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Looser timing on the way", systemImage: "hourglass")
                    .font(.headline)
                Text(DurationText.summary(waitSeconds: pending.cooldown, openSeconds: pending.grace) + ".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Starts in \(SettingsRows.countdown(to: pending.endsAt))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Button("Keep the current timing", role: .cancel) { model.cancelPendingDurations() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PawlColor.brand)
            }
        }
    }
}

/// 2.4: which of the two times a Custom picker is for.
enum TimeKind: Int, Identifiable {
    case wait, open
    var id: Int { rawValue }
}

/// 2.4: pick any time with hour and minute wheels. A wait can be 1 min to 24 hr ("No wait" has
/// its own button). An open time can be 15 min to 12 hr; iOS won't run a relock timer shorter
/// than 15 minutes (PawlDefaults.graceFloor).
struct CustomTimeSheet: View {
    let kind: TimeKind
    let onDone: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int
    @State private var minutes: Int

    init(kind: TimeKind, startMinutes: Int, onDone: @escaping (Int) -> Void) {
        self.kind = kind
        self.onDone = onDone
        _hours = State(initialValue: startMinutes / 60)
        _minutes = State(initialValue: startMinutes % 60)
    }

    private var total: Int { hours * 60 + minutes }
    private var range: ClosedRange<Int> {
        kind == .wait ? 1...Int(PawlDefaults.coolingOffCeiling / 60)
                      : Int(PawlDefaults.graceFloor / 60)...Int(PawlDefaults.graceCeiling / 60)
    }
    private var valid: Bool { range.contains(total) }
    private var hint: String {
        kind == .wait ? "Pick from 1 min to 24 hr."
                      : "Pick from 15 min to 12 hr. iOS needs at least 15 minutes to lock apps again."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0...(range.upperBound / 60), id: \.self) { Text("\($0) hr").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
                Text(valid ? DurationText.short(minutes: total) : hint)
                    .font(.headline)
                    .foregroundStyle(valid ? Color.primary : PawlColor.dangerText)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(kind == .wait ? "Custom wait" : "Custom open time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { onDone(total); dismiss() }
                        .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Someone to call

struct TrustedContactView: View {
    @State private var trustedName = ""
    @State private var trustedPhone = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SettingsRows.badge("person.fill", .pink)
                    TextField("Name (optional)", text: $trustedName)
                        .textContentType(.name)
                }
                HStack(spacing: 12) {
                    SettingsRows.badge("phone.fill", .pink)
                    TextField("Phone number", text: $trustedPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
            } footer: {
                Text("Someone to call when you're tempted. Pawl calls them with one tap from the \u{201C}I'm tempted\u{201D} screen.")
            }
        }
        .navigationTitle("Someone to call")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trustedName = TrustedContact.name() ?? ""
            trustedPhone = TrustedContact.phone() ?? ""
        }
        .onChange(of: trustedName) { _, _ in
            TrustedContact.save(name: trustedName, phone: trustedPhone)
        }
        .onChange(of: trustedPhone) { _, _ in
            TrustedContact.save(name: trustedName, phone: trustedPhone)
        }
    }
}

// MARK: - How protection works

struct ProtectionInfoView: View {
    /// 2.3: true when gambling is the focus. The 988 line always shows.
    var showGamblingHelp: Bool = true
    var body: some View {
        List {
            Section("How Pawl protects you") {
                infoRow("lock.shield.fill", "iOS Settings can't remove the shield.")
                infoRow("key.fill", "Only your key plus the wait lifts it.")
                infoRow("trash.slash.fill", "While protecting you, Pawl can't be deleted. Remove from Home Screen only hides it.")
                infoRow("hourglass", "The one way out: turn off Screen Time.")
                infoRow("person.badge.key.fill", "Hard lock: someone you trust sets a Screen Time passcode.")
            }
            Section("Removing Pawl") {
                infoRow("1.circle.fill", "Open Settings, then Screen Time.")
                infoRow("2.circle.fill", "Turn off Screen Time, or remove Pawl under Apps with Screen Time Access.")
                infoRow("3.circle.fill", "Delete Pawl from your Home Screen.")
                infoRow("exclamationmark.triangle.fill", "Turning off Screen Time ends your protection.")
            }
            Section("Get help") {
                Text(showGamblingHelp
                     ? "Problem gambling help is through the National Council on Problem Gambling. 988 is the U.S. Suicide & Crisis Lifeline. Both are free, confidential, and open 24/7."
                     : "988 is the U.S. Suicide & Crisis Lifeline. It's free, confidential, and open 24/7.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How Pawl works")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One idea per row.
    private func infoRow(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(PawlColor.brand)
        }
    }
}
