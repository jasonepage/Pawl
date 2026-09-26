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
enum AppTab: Hashable { case home, unlock, approvals, settings }

struct ContentView: View {
    @State private var model = AppModel()
    @State private var tab: AppTab = .home
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
            await model.syncCommitment()                     // FR-P2-SYNC-* (push/reconcile if signed in)
            model.restorePendingDurations()                  // resume/commit a gated loosening
            model.restorePendingSelectionChange()            // resume/commit a gated block removal
            model.restorePendingCategoryChange()             // resume/commit a gated category turn-off
            await model.sponsor.refresh()                    // so sponsor mode engages app-wide (FR-P2-LINK-005)
            model.applyGrandfatherIfNeeded()                 // 2.0 P1: legacy sponsor users → Pro-free for life
            await model.refreshBlocklist()                   // Tier-1: grow the gambling web list from Supabase
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
    /// bail before reading it during onboarding or in the approver role, so it is not
    /// silently thrown away.
    private func checkPendingUrge() {
        guard model.didOnboard, model.role == .blocker, !pendingUrge else { return }
        if SharedState.consumePendingUrge() {
            tab = .home
            pendingUrge = true
        }
    }

    private var mainTabs: some View {
        TabView(selection: $tab) {
            // Blocking tabs only for people who set up a shield (FR-P2-LINK-005 spirit:
            // an approver has nothing to block).
            if model.role == .blocker {
                HomeView(
                    needsKey: !model.isKeyPaired,
                    screenTimeOff: !model.auth.isApproved,
                    onPairKey: { tab = .unlock },
                    onEnableScreenTime: { Task { await model.reenableScreenTime() } },
                    showUrge: $pendingUrge
                )
                    .tabItem { Label("Home", systemImage: "shield.lefthalf.filled") }
                    .tag(AppTab.home)

                UnlockView(
                    shield: model.shield,
                    selection: model.selectionStore.load(),
                    commitmentProvider: { model.activeCommitment },
                    sponsorModeProvider: { model.isSponsorModeActive },
                    approval: model.approval
                )
                .tabItem { Label("Unlock", systemImage: "key.fill") }
                .tag(AppTab.unlock)
            }

            // Approvals appears for an approver, or a blocker who also sponsors someone.
            if model.role == .approver || model.isSponsoringSomeone {
                ApprovalsView(approval: model.approval)
                    .tabItem { Label("Approvals", systemImage: "checkmark.shield") }
                    .tag(AppTab.approvals)
            }

            SettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    ContentView()
}
