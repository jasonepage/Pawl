// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SettingsView.swift
//  Pawl, settings
//
//  2.3 redesign: three plain groups, in the order people need them.
//    1. What's blocked: Apps, Websites, Scheduled sets (each its own page)
//    2. Unlocking: the key, how long unlocking takes, the hard lock
//    3. Pawl: Pro, how it works, privacy, the version
//  The person to call and the help lines live on the "I'm tempted" screen, where they're used,
//  not here.
//  Every row says what it is and how it is set right now in one short line, so nothing needs
//  a footer to explain it. The brand header stays on top, a little more compact than 2.2.
//  Behavior is unchanged: every gated action still routes through AppModel (FR-SHIELD-010),
//  adding protection is instant, and removing it needs the key + the wait.
//

import SwiftUI

struct SettingsView: View {
    let model: AppModel
    /// Flipped by Home to land straight on What's blocked.
    var openBlockedItems: Binding<Bool> = .constant(false)
    /// Switches to the Unlock tab, where the key is paired and used.
    var onOpenUnlock: () -> Void = {}

    @State private var showPaywall = false
    #if DEBUG
    @State private var confirmErase = false
    #endif
    // Mirror of Pro entitlement in local @State so rows re-render reliably on lifecycle events
    // (purchase, sheet close, appear) without relying on cross-object Observation timing.
    @State private var hasPro = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    brandHeader
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                if !model.auth.isApproved {
                    screenTimeOffSection
                }
                blockedSection
                unlockingSection
                pawlSection

                #if DEBUG
                developerSection
                #endif
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: openBlockedItems) {
                BlockedItemsView(model: model)
            }
            .sheet(isPresented: $showPaywall,
                   onDismiss: { Task { await model.pro.refreshEntitlements(); syncPro() } }) {
                PaywallView(pro: model.pro)
            }
            .task {
                await model.pro.refreshEntitlements()
                syncPro()
            }
            .onAppear {
                model.auth.refresh()
                syncPro()
            }
            .onChange(of: model.pro.isPro) { _, _ in syncPro() }
        }
    }

    // MARK: - Brand header

    private var brandHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.30, green: 0.50, blue: 0.11),
                                     Color(red: 0.17, green: 0.33, blue: 0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: PawlColor.brand.opacity(0.45), radius: 12, y: 4)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Pawl")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("An app and website blocker you unlock with a physical key.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pawl. An app and website blocker you unlock with a physical key.")
    }

    // MARK: - Screen Time off (only shown when it is a problem)

    private var screenTimeOffSection: some View {
        Section {
            Button {
                Task { await model.reenableScreenTime() }
            } label: {
                SettingsRows.detail("exclamationmark.triangle.fill", .red, "Screen Time access is off",
                                    "Pawl can't block anything until it's back on. Tap to fix.")
            }
        }
    }

    // MARK: - 1. What's blocked

    private var blockedSection: some View {
        Section {
            NavigationLink {
                BlockedAppsView(model: model)
            } label: {
                SettingsRows.detail("apps.iphone", .blue, "Apps", appsLine)
            }
            NavigationLink {
                BlockedWebsitesView(model: model)
            } label: {
                SettingsRows.detail("globe", .green, "Websites", websitesLine)
            }
            NavigationLink {
                ScheduledSetsView(model: model)
            } label: {
                SettingsRows.detail("calendar", .orange, "Scheduled sets", setsLine,
                                    value: (!hasPro && model.scheduledSets.isEmpty) ? "Pro" : nil)
            }
        } header: {
            Text("What's blocked")
        } footer: {
            Text("Adding a block works right away. Removing one needs your key and the wait.")
        }
    }

    private var appsLine: String {
        let n = model.blockedSummary.apps
        switch n {
        case 0:  return "None yet. Pick apps to block all day."
        case 1:  return "1 app or category, blocked all day"
        default: return "\(n) apps and categories, blocked all day"
        }
    }

    private var websitesLine: String {
        var parts: [String] = []
        if model.gamblingOn { parts.append("Gambling") }
        if model.adultOn { parts.append("Adult") }
        let own = model.customDomains.count
        if own > 0 { parts.append(own == 1 ? "1 site you added" : "\(own) sites you added") }
        return parts.isEmpty ? "None yet" : parts.joined(separator: ", ")
    }

    private var setsLine: String {
        let n = model.scheduledSets.count
        guard n > 0 else { return "Block apps only at certain hours" }
        let count = n == 1 ? "1 set" : "\(n) sets"
        if let active = model.activeScheduledSetName { return "\(count). \(active) is on now." }
        return count
    }

    // MARK: - 2. Unlocking

    private var unlockingSection: some View {
        Section {
            Button(action: onOpenUnlock) {
                SettingsRows.detail("key.fill", .gray, "Security key",
                                    model.isKeyPaired
                                        ? "Paired. Use or re-pair it on the Unlock tab."
                                        : "Not paired yet. Pair it on the Unlock tab.")
            }
            NavigationLink {
                FrictionView(model: model)
            } label: {
                SettingsRows.detail("hourglass", .teal, "Unlock timing",
                                    "\(Int(model.cooldownSeconds / 60)) min wait, then open for \(Int(model.graceSeconds / 60)) min")
            }
            NavigationLink {
                HardLockView(onAttest: { model.attestHardLock() },
                             onReset: { model.resetHardLock() },
                             alreadyAttested: model.hardLockAttested,
                             attestedDate: model.hardLockDate)
            } label: {
                SettingsRows.detail("lock.shield.fill", .brown, "Hard lock",
                                    model.hardLockAttested
                                        ? "On. Someone you trust keeps a Screen Time passcode."
                                        : "Off. Someone you trust can set a Screen Time passcode.")
            }
        } header: {
            Text("Unlocking")
        }
    }

    // MARK: - 3. Pawl

    private var pawlSection: some View {
        Section {
            Button {
                showPaywall = true
            } label: {
                SettingsRows.detail("star.fill", .yellow, "Pawl Pro",
                                    hasPro ? "Active" : "Scheduled sets and the weekly report")
            }
            NavigationLink {
                ProtectionInfoView(showGamblingHelp: model.showGamblingHelp)
            } label: {
                SettingsRows.label("info.circle.fill", .gray, "How Pawl works")
            }
            Link(destination: URL(string: "https://getpawl.com/privacy")!) {
                SettingsRows.external("hand.raised.fill", .blue, "Privacy Policy")
            }
        } header: {
            Text("Pawl")
        } footer: {
            Text(versionLine)
        }
    }

    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Pawl \(version) (\(build))"
    }

    /// Pull the current entitlement into @State so rows re-render. Pro status can change while
    /// Settings is on screen (right after a purchase), and @State mutation guarantees the update.
    private func syncPro() { hasPro = model.pro.isPro }

    // MARK: - Developer

    #if DEBUG
    private var developerSection: some View {
        Section {
            Button(role: .destructive) {
                confirmErase = true
            } label: {
                SettingsRows.label("trash.fill", .red, "Erase everything")
            }
            .confirmationDialog("Erase everything?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Erase and close Pawl", role: .destructive) { model.devEraseEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes your key, streak, logs, blocks, sets and settings from this phone and from iCloud (other devices on this Apple Account too), lifts every block, and closes Pawl. Open it again for a fresh start. Test purchases are separate: Xcode, Debug, StoreKit, Manage Transactions.")
            }
            Button {
                model.resetOnboarding()
            } label: {
                SettingsRows.label("arrow.counterclockwise", .orange, "Run setup again (keeps everything)")
            }
            Button {
                model.shield.setDeletionBlock(false)
                model.shield.setClockLock(false)
            } label: {
                SettingsRows.label("trash.slash.fill", .red, "Allow deletion (escape)")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Xcode builds only, never in the App Store build. Erase everything is a true fresh start. Run setup again only re-runs setup. Allow deletion re-enables uninstall so you can reinstall a dev build.")
        }
    }
    #endif
}

#Preview {
    SettingsView(model: AppModel())
}
