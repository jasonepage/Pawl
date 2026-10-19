// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ContentView.swift
//  Pawl
//
//  Root. First run → onboarding. After that → the real app: Home, Unlock, Settings.
//  (The old developer "Setup" tab is retired; its flows now live in onboarding/Settings.)
//

import SwiftUI

/// The main tabs, tagged so one tab can programmatically switch to another
/// (e.g. the Home "pair your key" nudge jumps to Unlock).
enum AppTab: Hashable { case home, unlock, settings }

struct ContentView: View {
    @State private var model = AppModel()
    @State private var tab: AppTab = .home
    /// Set by Home's "What's blocked" card; Settings pushes that page and clears it.
    @State private var openBlockedItems = false
    @Environment(\.scenePhase) private var scenePhase
    /// Set when someone pressed "I need a minute" on the block screen (FR-SHACT-004).
    /// Owned here rather than in HomeView: sibling tabs stay alive in a TabView, so a
    /// HomeView that is not on screen could consume the flag where nobody could see it,
    /// which is why the handoff only worked sometimes.
    @State private var pendingUrge = false

    var body: some View {
        Group {
            if model.didOnboard {
                mainTabs
            } else {
                OnboardingView(model: model)
            }
        }
        .tint(PawlColor.brand)
        .task {
            await RecoveryService.restoreOnLaunch()          // FR-PERSIST-002/003 (local, offline-safe)
            await model.loadCommitment()                     // phone + iCloud (FR-PERSIST-*)
            await model.restorePendingDurations()            // resume/commit a gated loosening
            await model.restorePendingSelectionChange()      // resume/commit a gated block removal
            await model.restorePendingCategoryChange()       // resume/commit a gated category turn-off
            await model.restorePendingDomainRemoval()        // 2.2: iCloud mirror + gated typed-site removal
            await model.restorePendingSetsChange()           // 2.2: scheduled sets, their activities, gated edits
            checkPendingUrge()                               // FR-SHACT-004 pickup on cold launch
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-read Screen Time auth on resume so the Home/Settings banner reflects reality
            // (a background toggle isn't pushed to a running app).
            if phase == .active {
                model.auth.refresh()
                checkPendingUrge()
            }
        }
    }

    /// Consume the block screen handoff, select Home, and let HomeView push the urge flow.
    ///
    /// A shield action extension cannot open its containing app, so this is the pickup end
    /// of a deferred handoff. The flag is only consumed when there is somewhere to show it:
    /// bail before reading it during onboarding, so it is not silently thrown away.
    private func checkPendingUrge() {
        guard model.didOnboard, !pendingUrge else { return }
        if SharedState.consumePendingUrge() {
            tab = .home
            pendingUrge = true
        }
    }

    private var mainTabs: some View {
        TabView(selection: $tab) {
            HomeView(
                needsKey: !model.isKeyPaired,
                screenTimeOff: !model.auth.isApproved,
                blockedItems: model.blockedSummaryParts,
                activeSetName: model.activeScheduledSetName,
                hoursPerDay: model.hoursPerDay,
                showGamblingHelp: model.showGamblingHelp,
                asksSlipCost: model.asksSlipCost,
                onPairKey: { tab = .unlock },
                onEnableScreenTime: { Task { await model.reenableScreenTime() } },
                onShowBlocked: { tab = .settings; openBlockedItems = true },
                showUrge: $pendingUrge,
                pro: model.pro
            )
                .tabItem { Label("Home", systemImage: "shield.lefthalf.filled") }
                .tag(AppTab.home)

            UnlockView(
                shield: model.shield,
                selection: model.selectionStore.load(),
                screenTimeOff: !model.auth.isApproved,
                commitmentProvider: { model.activeCommitment }
            )
            .tabItem { Label("Unlock", systemImage: "key.fill") }
            .tag(AppTab.unlock)

            SettingsView(model: model, openBlockedItems: $openBlockedItems,
                         onOpenUnlock: { tab = .unlock })
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    ContentView()
}
