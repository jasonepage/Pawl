// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlApp.swift
//  Pawl
//
//  Created by Jason Page on 6/22/26.
//

import SwiftUI

@main
struct PawlApp: App {
    @UIApplicationDelegateAdaptor(PawlAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Beat on every foreground/launch and queue the next background beat
                    // (FR-P2-HEART-002). beatOnForeground re-checks auth a couple times because
                    // FamilyControls' status can read stale right after a warm resume.
                    Task { await HeartbeatService.shared.beatOnForeground() }
                    HeartbeatService.shared.scheduleBackgroundBeat()
                }
        }
    }
}
