// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsView.swift
//  Pawl — settings
//
//  Modernized: a branded header, inset-grouped cards, and colored icon rows (the iOS-Settings
//  look). The long explanations live behind a "How protection works" detail so the main screen
//  stays calm. Functionality is unchanged — every gated action still routes through AppModel
//  (FR-SHIELD-010): adding protection is instant; removing it needs the key + cooling-off.
//

import SwiftUI
import FamilyControls

struct SettingsView: View {
    let model: AppModel

    @State private var cooldownMin = 15
    @State private var graceMin = 30
    @AppStorage(Feedback.enabledKey) private var feedbackEnabled = true
    @State private var editSelection = FamilyActivitySelection()
    @State private var showBlockPicker = false
    @State private var showPaywall = false
    // Mirror of Pro entitlement in local @State so the row re-renders reliably on lifecycle events
    // (purchase, sheet close, appear) without relying on cross-object Observation timing.
    @State private var hasPro = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    brandHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                AccountView(auth: model.account, onSignIn: {
                    Task {
                        await model.syncCommitment()
                        await model.sponsor.refresh()
                    }
                })

                if model.account.isSignedIn {
                    SponsorView(sponsor: model.sponsor,
                                nameMissing: (model.account.displayName ?? "").isEmpty,
                                hasAccountability: hasPro || model.pro.isLegacyFree,
                                onUnlock: { showPaywall = true })
                }

                proSection

                if model.role == .blocker {
                    screenTimeSection
                    protectionSection
                    frictionSection
                    websitesSection

                    Section {
                        NavigationLink {
                            ProtectionInfoView()
                        } label: {
                            iconLabel("info.circle.fill", .gray, "How protection works")
                        }
                    }
                }

                if model.role == .approver {
                    Section {
                        Button {
                            model.setUpBlocking()
                        } label: {
                            iconLabel("shield.lefthalf.filled", .green, "Set up blocking on this phone")
                        }
                        Text("You're set up only to approve someone else. Block gambling, adult sites, or specific apps on your own phone too — you'll still be their approver.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("App") {
                    Toggle(isOn: $feedbackEnabled) {
                        iconLabel("speaker.wave.2.fill", .purple, "Sound & haptics")
                    }
                    Text("Feedback for key taps, the relock click, and the breathing guide.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Privacy & legal") {
                    Link(destination: URL(string: "https://getpawl.com/privacy")!) {
                        iconLabel("hand.raised.fill", .blue, "Privacy Policy")
                    }
                    if model.account.isSignedIn {
                        Text("Manage or delete your account in the Account section at the top of Settings. Deleting removes all your cloud data and can't be undone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Get help") {
                    Link(destination: URL(string: "https://www.ncpgambling.org/help-treatment/")!) {
                        iconLabel("lifepreserver.fill", .teal, "Problem gambling help")
                    }
                    Link(destination: URL(string: "tel://988")!) {
                        iconLabel("phone.fill", .red, "Crisis support — call 988")
                    }
                    Text("Free, confidential, 24/7. Gambling help via the National Council on Problem Gambling; 988 is the U.S. Suicide & Crisis Lifeline.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("Developer") {
                    Button(role: .destructive) {
                        model.resetOnboarding()
                    } label: {
                        iconLabel("arrow.counterclockwise", .orange, "Start over")
                    }
                    Button {
                        model.shield.setDeletionBlock(false)
                    } label: {
                        iconLabel("trash.slash.fill", .red, "Allow deletion (escape)")
                    }
                    Button {
                        model.pro.debugResetLegacy()
                        syncPro()
                    } label: {
                        iconLabel("star.slash.fill", .yellow, "Reset Pro (dev)")
                    }
                    Text("DEBUG only. \u{201C}Start over\u{201D} re-runs onboarding (streak kept). \u{201C}Allow deletion\u{201D} re-enables uninstall so you can reinstall a dev build.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall,
                   onDismiss: { Task { await model.pro.refreshEntitlements(); syncPro() } }) {
                PaywallView(pro: model.pro)
            }
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $editSelection)
            .onChange(of: showBlockPicker) { wasShowing, showing in
                if wasShowing && !showing {           // picker dismissed — apply the edit
                    Task { await model.requestSelectionChange(editSelection) }
                }
            }
            .task {
                await model.pro.refreshEntitlements()
                syncPro()
                if model.account.isSignedIn { await model.sponsor.refresh() }
            }
            .onAppear {
                cooldownMin = max(15, Int(model.cooldownSeconds / 60))
                graceMin = max(1, Int(model.graceSeconds / 60))
                model.auth.refresh()
                syncPro()
            }
            .onChange(of: model.pro.isPro) { _, _ in syncPro() }
        }
    }

    // MARK: - Branded header

    private var brandHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.30, green: 0.50, blue: 0.11),
                                     Color(red: 0.17, green: 0.33, blue: 0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: PawlColor.brand.opacity(0.45), radius: 14, y: 5)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Pawl")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Friction that actually holds")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pawl. Friction that actually holds.")
    }

    // MARK: - Pawl Pro (P1)

    @ViewBuilder
    private var proSection: some View {
        Section("Pawl Pro") {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    iconLabel("star.circle.fill", .yellow, "Pawl Pro")
                    Spacer(minLength: 8)
                    Text(proStatusText).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Text(proBlurb)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var proStatusText: String {
        if model.pro.isLegacyFree { return "Free for life" }
        if hasPro { return "Active" }
        // Sponsor link but no entitlement = a lapsed subscription (docs/12 §8).
        return model.sponsor.asProtected.contains { $0.status == "active" } ? "Lapsed" : "Free"
    }

    private var proBlurb: String {
        (hasPro || model.pro.isLegacyFree)
            ? "Accountability is unlocked — link a sponsor in the Account section above."
            : "Add a sponsor who approves your unlocks and is alerted if your protection drops. Blocking and the crisis tools stay free."
    }

    /// Pull the current entitlement into @State so the row re-renders. Pro status can change while
    /// Settings is on screen (right after a purchase), and @State mutation guarantees the update.
    private func syncPro() { hasPro = model.pro.isPro }

    // MARK: - Sections

    @ViewBuilder
    private var screenTimeSection: some View {
        Section("Screen Time") {
            if model.auth.isApproved {
                HStack {
                    iconLabel("checkmark.seal.fill", .green, "Screen Time access")
                    Spacer(minLength: 8)
                    Text("On").foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    iconLabel("exclamationmark.triangle.fill", .red, "Screen Time access")
                    Spacer(minLength: 8)
                    Text("Off").foregroundStyle(.red)
                }
                Button {
                    Task { await model.reenableScreenTime() }
                } label: {
                    iconLabel("clock.arrow.circlepath", .green, "Enable Screen Time")
                }
                Text("Pawl can't block anything without Screen Time access. iOS removes this permission when you reinstall the app, so re-enable it here. If your blocked apps look empty afterward, re-add them under \u{201C}Edit blocked apps\u{201D} below.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var protectionSection: some View {
        Section("Protection") {
            let summary = model.blockedSummary
            if model.gamblingOn {
                valueRow("dice.fill", .green, "Gambling sites", "On · \(model.webBlockCount) sites")
            }
            if model.adultOn {
                valueRow("eye.slash.fill", .indigo, "Adult sites", "On")
            }
            valueRow("apps.iphone", .blue, "Apps & categories", summary.apps == 0 ? "None" : "\(summary.apps)")
            if summary.sites > 0 {
                valueRow("globe", .teal, "Other websites", "\(summary.sites)")
            }

            Button {
                editSelection = model.currentSelection
                showBlockPicker = true
            } label: {
                iconLabel("pencil", .blue, "Edit blocked apps")
            }

            NavigationLink {
                HardLockView(onAttest: { model.attestHardLock() },
                             onReset: { model.resetHardLock() },
                             alreadyAttested: model.hardLockAttested,
                             attestedDate: model.hardLockDate)
            } label: {
                valueRow("lock.shield.fill", .brown, "Hard lock", model.hardLockAttested ? "On" : "Set up")
            }

            if let endsAt = model.pendingSelectionChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Removal applies in", value: durationCountdown(to: endsAt))
                }
                Button("Cancel removal", role: .cancel) { model.cancelSelectionChange() }
            }
            if let m = model.blockChangeMessage {
                Text(m).font(.caption).foregroundStyle(PawlColor.brand)
            }
            Text("Adding apps applies right away. Removing one needs your key + a cooling-off — it stays blocked until the wait ends.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var frictionSection: some View {
        Section("Friction") {
            Stepper(value: $cooldownMin, in: 15...120, step: 5) {
                iconLabel("hourglass", .teal, "Cooling-off: \(cooldownMin) min")
            }
            Stepper(value: $graceMin, in: 1...180, step: 1) {
                iconLabel("clock.arrow.circlepath", .teal, "Grace: \(graceMin) min")
            }
            Button {
                Task {
                    await model.requestDurations(cooldown: Double(cooldownMin) * 60,
                                                 grace: Double(graceMin) * 60)
                }
            } label: {
                iconLabel("checkmark.circle.fill", .green, "Apply")
            }
            .disabled(Double(cooldownMin) * 60 == model.cooldownSeconds
                      && Double(graceMin) * 60 == model.graceSeconds)

            if let pending = model.pendingDurations {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Looser settings apply in", value: durationCountdown(to: pending.endsAt))
                }
                Button("Cancel change", role: .cancel) { model.cancelPendingDurations() }
            }
            Text("Stricter settings — longer cooling-off, shorter grace — apply right away. Looser settings wait out your cooling-off first, so there's no shortcut in the moment.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var websitesSection: some View {
        Section("Websites") {
            if model.gamblingOn {
                Button(role: .destructive) {
                    Task { await model.requestWebCategories(gambling: false, adult: model.adultOn) }
                } label: {
                    iconLabel("dice.fill", .green, "Stop blocking gambling sites")
                }
            } else {
                Button {
                    Task { await model.requestWebCategories(gambling: true, adult: model.adultOn) }
                } label: {
                    iconLabel("dice.fill", .green, "Block gambling sites")
                }
            }
            if model.adultOn {
                Button(role: .destructive) {
                    Task { await model.requestWebCategories(gambling: model.gamblingOn, adult: false) }
                } label: {
                    iconLabel("eye.slash.fill", .indigo, "Turn off adult-site filter")
                }
            } else {
                Button {
                    Task { await model.requestWebCategories(gambling: model.gamblingOn, adult: true) }
                } label: {
                    iconLabel("eye.slash.fill", .indigo, "Turn on adult-site filter")
                }
            }
            if let endsAt = model.pendingCategoryChange {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    LabeledContent("Turn-off applies in", value: durationCountdown(to: endsAt))
                }
                Button("Cancel", role: .cancel) { model.cancelCategoryChange() }
            }
            Text("Gambling sites use our maintained list; adult sites use Apple's built-in filter. Turning a category on is instant; turning one off needs your key + a cooling-off.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Reusable bits

    /// A colored rounded-square icon — the iOS-Settings badge look.
    private func badge(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// A row label: colored badge + title. Works inside Button / NavigationLink.
    private func iconLabel(_ symbol: String, _ color: Color, _ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            badge(symbol, color)
        }
    }

    /// A row with a badge + title on the left and a trailing value on the right. A plain HStack
    /// (instead of LabeledContent) so it composes cleanly inside List rows and NavigationLinks.
    private func valueRow(_ symbol: String, _ color: Color, _ title: String, _ value: String) -> some View {
        HStack {
            iconLabel(symbol, color, title)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func durationCountdown(to endsAt: Date) -> String {
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

// MARK: - "How protection works" detail (keeps the long copy off the main screen)

private struct ProtectionInfoView: View {
    @State private var trustedName = ""
    @State private var trustedPhone = ""

    var body: some View {
        List {
            Section("How Pawl protects you") {
                Text("Pawl's shield can't be removed from iOS Settings — only Pawl can, and only after your physical key plus a 15-minute wait. While Pawl is protecting you it also can't be deleted by long-pressing the icon — only \u{201C}Remove from Home Screen\u{201D} is allowed, and it keeps running underneath. The one remaining way out is turning off Screen Time in Settings, which removes protection but alerts your sponsor. The only fully hard lock is a sponsor-set Screen Time passcode.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Removing Pawl") {
                Text("While Pawl is protecting you it can't be deleted by long-pressing its icon — that's intentional. To remove it completely:\n\n1.  Open Settings → Screen Time.\n2.  Turn off Screen Time, or remove Pawl under \u{201C}Apps with Screen Time Access.\u{201D}\n3.  Then delete Pawl from your Home Screen.\n\nTurning off Screen Time removes your protection and notifies your sponsor.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Someone you trust") {
                HStack(spacing: 12) {
                    contactBadge("person.fill")
                    TextField("Name (optional)", text: $trustedName)
                        .textContentType(.name)
                }
                HStack(spacing: 12) {
                    contactBadge("phone.fill")
                    TextField("Phone number", text: $trustedPhone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                Text("Add someone to call in a tough moment. They show up as a one-tap call on the urge screen — a person to reach when it's hard.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How protection works")
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

    private func contactBadge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(Color.pink, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview {
    SettingsView(model: AppModel())
}
