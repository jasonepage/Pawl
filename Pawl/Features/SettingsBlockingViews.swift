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
            Text("Blocked all day, every day. Adding apps works right away. Removing one needs your key and the wait, and it stays blocked until then.")
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

struct FrictionView: View {
    let model: AppModel

    @State private var cooldownMin = 15
    @State private var graceMin = 30

    var body: some View {
        List {
            Section {
                Stepper(value: $cooldownMin, in: 15...120, step: 5) {
                    minutesRow("Wait before unlocking", cooldownMin)
                }
                Stepper(value: $graceMin, in: 15...180, step: 5) {
                    minutesRow("Then stays open for", graceMin)
                }
                Button("Save") {
                    Task {
                        await model.requestDurations(cooldown: Double(cooldownMin) * 60,
                                                     grace: Double(graceMin) * 60)
                    }
                }
                .disabled(Double(cooldownMin) * 60 == model.cooldownSeconds
                          && Double(graceMin) * 60 == model.graceSeconds)

                if let pending = model.pendingDurations {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent("Looser timing starts in", value: SettingsRows.countdown(to: pending.endsAt))
                    }
                    Button("Keep the current timing", role: .cancel) { model.cancelPendingDurations() }
                }
            } footer: {
                Text("After you use your key, Pawl waits this long before anything opens. Then it stays open this long and locks again by itself. Stricter timing saves right away. Looser timing waits out your current wait first, so there's no shortcut in the moment.")
            }
            BlockChangeMessageSection(model: model)
        }
        .navigationTitle("Unlock timing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cooldownMin = max(15, Int(model.cooldownSeconds / 60))
            graceMin = max(15, Int(model.graceSeconds / 60))
        }
    }

    private func minutesRow(_ title: String, _ minutes: Int) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text("\(minutes) min").monospacedDigit().foregroundStyle(.secondary)
        }
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
                Text("Someone to call when you're tempted. They show up as a one-tap call on the urge screen.")
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
                Text("Pawl's shield can't be removed from iOS Settings. Only Pawl can lift it, and only after your physical key plus a 15-minute wait. While Pawl is protecting you it also can't be deleted by long-pressing the icon. Only \u{201C}Remove from Home Screen\u{201D} is allowed, and it keeps running underneath. The one remaining way out is turning off Screen Time in Settings, which removes protection. For a full lock, someone you trust can set a Screen Time passcode for you. That's Hard lock in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Removing Pawl") {
                Text("While Pawl is protecting you it can't be deleted by long-pressing its icon. That's intentional. To remove it completely:\n\n1.  Open Settings, then Screen Time.\n2.  Turn off Screen Time, or remove Pawl under \u{201C}Apps with Screen Time Access.\u{201D}\n3.  Then delete Pawl from your Home Screen.\n\nTurning off Screen Time removes your protection.")
                    .font(.footnote).foregroundStyle(.secondary)
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
}
