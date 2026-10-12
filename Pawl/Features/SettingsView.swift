// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsView.swift
//  Pawl, settings
//
//  2.2: an index, not a wall. The top level is a short list of rows that fits on one
//  screen; what is blocked, the friction timers, the hard lock, and the long explanations
//  each live one tap deeper (SettingsBlockingViews.swift). Functionality is unchanged:
//  every gated action still routes through AppModel (FR-SHIELD-010), adding protection
//  is instant, and removing it needs the key + cooling-off.
//

import SwiftUI

struct SettingsView: View {
    let model: AppModel

    @AppStorage(Feedback.enabledKey) private var feedbackEnabled = true
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

                if model.role == .blocker, !model.auth.isApproved {
                    screenTimeOffSection
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
                    blockingSection
                } else {
                    approverSection
                }

                helpSection
                appSection

                #if DEBUG
                developerSection
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall,
                   onDismiss: { Task { await model.pro.refreshEntitlements(); syncPro() } }) {
                PaywallView(pro: model.pro)
            }
            .task {
                await model.pro.refreshEntitlements()
                syncPro()
                if model.account.isSignedIn { await model.sponsor.refresh() }
            }
            .onAppear {
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

    // MARK: - Screen Time off (only shown when it is a problem)

    private var screenTimeOffSection: some View {
        Section {
            Button {
                Task { await model.reenableScreenTime() }
            } label: {
                SettingsRows.value("exclamationmark.triangle.fill", .red, "Screen Time access is off", "Fix")
            }
        } footer: {
            Text("Pawl can't block anything without Screen Time access. iOS removes it when you reinstall the app. If your blocked apps look empty afterward, re-add them under What's blocked.")
        }
    }

    // MARK: - Pawl Pro (P1)

    private var proSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                SettingsRows.value("star.circle.fill", .yellow, "Pawl Pro", proStatusText)
            }
            .buttonStyle(.plain)
        } footer: {
            if !(hasPro || model.pro.isLegacyFree) {
                Text("A sponsor who approves your unlocks and hears if your protection drops. Blocking stays free.")
            }
        }
    }

    private var proStatusText: String {
        if model.pro.isLegacyFree { return "Free for life" }
        if hasPro { return "Active" }
        // Sponsor link but no entitlement = a lapsed subscription (docs/12 §8).
        return model.sponsor.asProtected.contains { $0.status == "active" } ? "Lapsed" : "Free"
    }

    /// Pull the current entitlement into @State so the row re-renders. Pro status can change while
    /// Settings is on screen (right after a purchase), and @State mutation guarantees the update.
    private func syncPro() { hasPro = model.pro.isPro }

    // MARK: - Blocking (the index rows; detail lives one tap deeper)

    private var blockingSection: some View {
        Section("Blocking") {
            NavigationLink {
                BlockedItemsView(model: model)
            } label: {
                SettingsRows.value("shield.lefthalf.filled", .green, "What's blocked", blockedSummaryText)
            }
            NavigationLink {
                FrictionView(model: model)
            } label: {
                SettingsRows.value("hourglass", .teal, "Cooling-off and grace",
                                   "\(Int(model.cooldownSeconds / 60)) / \(Int(model.graceSeconds / 60)) min")
            }
            NavigationLink {
                HardLockView(onAttest: { model.attestHardLock() },
                             onReset: { model.resetHardLock() },
                             alreadyAttested: model.hardLockAttested,
                             attestedDate: model.hardLockDate)
            } label: {
                SettingsRows.value("lock.shield.fill", .brown, "Hard lock", model.hardLockAttested ? "On" : "Set up")
            }
        }
    }

    /// One short value for the index row, for example "Gambling · 3 apps · 2 sites".
    private var blockedSummaryText: String {
        var parts: [String] = []
        if model.gamblingOn { parts.append("Gambling") }
        if model.adultOn { parts.append("Adult") }
        let s = model.blockedSummary
        if s.apps > 0 { parts.append(s.apps == 1 ? "1 app" : "\(s.apps) apps") }
        let sites = s.sites + model.customDomains.count
        if sites > 0 { parts.append(sites == 1 ? "1 site" : "\(sites) sites") }
        return parts.isEmpty ? "Nothing yet" : parts.joined(separator: " · ")
    }

    private var approverSection: some View {
        Section {
            Button {
                model.setUpBlocking()
            } label: {
                SettingsRows.label("shield.lefthalf.filled", .green, "Set up blocking on this phone")
            }
        } footer: {
            Text("You're set up only to approve someone else. You can block things on your own phone too and still be their approver.")
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        Section("Help") {
            NavigationLink {
                ProtectionInfoView()
            } label: {
                SettingsRows.label("info.circle.fill", .gray, "How protection works")
            }
            NavigationLink {
                TrustedContactView()
            } label: {
                SettingsRows.value("person.fill", .pink, "Someone to call", TrustedContact.phone() == nil ? "Add" : "Set")
            }
            Link(destination: URL(string: "https://www.ncpgambling.org/help-treatment/")!) {
                SettingsRows.label("lifepreserver.fill", .teal, "Problem gambling help")
            }
            Link(destination: URL(string: "tel://988")!) {
                SettingsRows.label("phone.fill", .red, "Crisis support, call 988")
            }
        }
    }

    // MARK: - App

    private var appSection: some View {
        Section("App") {
            Toggle(isOn: $feedbackEnabled) {
                SettingsRows.label("speaker.wave.2.fill", .purple, "Sound & haptics")
            }
            Link(destination: ReviewPrompter.writeReviewURL) {
                SettingsRows.label("star.fill", .yellow, "Rate Pawl on the App Store")
            }
            Link(destination: URL(string: "https://getpawl.com/privacy")!) {
                SettingsRows.label("hand.raised.fill", .blue, "Privacy Policy")
            }
        }
    }

    // MARK: - Developer

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button(role: .destructive) {
                model.resetOnboarding()
            } label: {
                SettingsRows.label("arrow.counterclockwise", .orange, "Start over")
            }
            Button {
                model.shield.setDeletionBlock(false)
                model.shield.setClockLock(false)
            } label: {
                SettingsRows.label("trash.slash.fill", .red, "Allow deletion (escape)")
            }
            Button {
                model.pro.debugResetLegacy()
                syncPro()
            } label: {
                SettingsRows.label("star.slash.fill", .yellow, "Reset Pro (dev)")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("DEBUG only. Start over re-runs onboarding (streak kept). Allow deletion re-enables uninstall so you can reinstall a dev build.")
        }
    }
    #endif
}

#Preview {
    SettingsView(model: AppModel())
}
