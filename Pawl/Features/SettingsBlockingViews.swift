// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsBlockingViews.swift
//  Pawl, Settings sub-screens (2.2)
//
//  What's blocked, the friction timers, the trusted contact, and the long "how it works"
//  copy. Each used to be a section on the Settings index; the index got too tall to read.
//  Behavior is unchanged and still goes through AppModel.
//

import SwiftUI
import FamilyControls

// MARK: - What's blocked

struct BlockedItemsView: View {
    let model: AppModel

    @State private var editSelection = FamilyActivitySelection()
    @State private var showBlockPicker = false

    var body: some View {
        List {
            appsSection
            ScheduledSetsSection(model: model)
            websitesSection
            if let m = model.blockChangeMessage {
                Section {
                    Text(m).font(.callout).foregroundStyle(PawlColor.brand)
                }
            }
        }
        .navigationTitle("What's blocked")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showBlockPicker, selection: $editSelection)
        .onChange(of: showBlockPicker) { wasShowing, showing in
            if wasShowing && !showing {           // picker dismissed: apply the edit
                Task { await model.requestSelectionChange(editSelection) }
            }
        }
    }

    private var appsSection: some View {
        Section {
            let summary = model.blockedSummary
            SettingsRows.value("apps.iphone", .blue, "Apps & categories", summary.apps == 0 ? "None" : "\(summary.apps)")
            Button {
                editSelection = model.currentSelection
                showBlockPicker = true
            } label: {
                SettingsRows.label("pencil", .blue, "Edit always-on apps")
            }
            if let endsAt = model.pendingSelectionChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Removal applies in", value: SettingsRows.countdown(to: endsAt))
                }
                Button("Cancel removal", role: .cancel) { model.cancelSelectionChange() }
            }
        } header: {
            Text("Always on")
        } footer: {
            Text("These are blocked around the clock and open only with your key. Adding apps applies right away. Removing one needs your key + a cooling-off, and it stays blocked until the wait ends.")
        }
    }

    private var websitesSection: some View {
        Section {
            if model.gamblingOn {
                Button(role: .destructive) {
                    Task { await model.requestWebCategories(gambling: false, adult: model.adultOn) }
                } label: {
                    SettingsRows.value("dice.fill", .green, "Gambling sites", "On · \(model.webBlockCount)")
                }
            } else {
                Button {
                    Task { await model.requestWebCategories(gambling: true, adult: model.adultOn) }
                } label: {
                    SettingsRows.value("dice.fill", .green, "Gambling sites", "Off")
                }
            }
            if model.adultOn {
                Button(role: .destructive) {
                    Task { await model.requestWebCategories(gambling: model.gamblingOn, adult: false) }
                } label: {
                    SettingsRows.value("eye.slash.fill", .indigo, "Adult sites", "On")
                }
            } else {
                Button {
                    Task { await model.requestWebCategories(gambling: model.gamblingOn, adult: true) }
                } label: {
                    SettingsRows.value("eye.slash.fill", .indigo, "Adult sites", "Off")
                }
            }
            if let endsAt = model.pendingCategoryChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Turn-off applies in", value: SettingsRows.countdown(to: endsAt))
                }
                Button("Cancel", role: .cancel) { model.cancelCategoryChange() }
            }
            NavigationLink {
                CustomDomainsView(model: model)
            } label: {
                SettingsRows.value("globe", .blue, "Specific websites", "\(model.customDomains.count)")
            }
        } header: {
            Text("Websites")
        } footer: {
            Text("Tap a category to turn it on or off. Gambling uses Pawl's own list, adult sites use Apple's filter, and specific websites are ones you type in. Turning something on is instant. Turning it off needs your key + a cooling-off.")
        }
    }
}

// MARK: - Cooling-off and grace

struct FrictionView: View {
    let model: AppModel

    @State private var cooldownMin = 15
    @State private var graceMin = 30

    var body: some View {
        List {
            Section {
                Stepper(value: $cooldownMin, in: 15...120, step: 5) {
                    SettingsRows.label("hourglass", .teal, "Cooling-off: \(cooldownMin) min")
                }
                Stepper(value: $graceMin, in: 15...180, step: 5) {
                    SettingsRows.label("clock.arrow.circlepath", .teal, "Grace: \(graceMin) min")
                }
                Button {
                    Task {
                        await model.requestDurations(cooldown: Double(cooldownMin) * 60,
                                                     grace: Double(graceMin) * 60)
                    }
                } label: {
                    SettingsRows.label("checkmark.circle.fill", .green, "Apply")
                }
                .disabled(Double(cooldownMin) * 60 == model.cooldownSeconds
                          && Double(graceMin) * 60 == model.graceSeconds)

                if let pending = model.pendingDurations {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent("Looser settings apply in", value: SettingsRows.countdown(to: pending.endsAt))
                    }
                    Button("Cancel change", role: .cancel) { model.cancelPendingDurations() }
                }
            } footer: {
                Text("Cooling-off is the wait after your key before apps unlock. Grace is how long they stay unlocked before Pawl relocks them. Stricter settings (longer cooling-off, shorter grace) apply right away. Looser settings wait out your cooling-off first, so there's no shortcut in the moment.")
            }
            if let m = model.blockChangeMessage {
                Section {
                    Text(m).font(.callout).foregroundStyle(PawlColor.brand)
                }
            }
        }
        .navigationTitle("Cooling-off and grace")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cooldownMin = max(15, Int(model.cooldownSeconds / 60))
            graceMin = max(15, Int(model.graceSeconds / 60))
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
        .navigationTitle("How protection works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
