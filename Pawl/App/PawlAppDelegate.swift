// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlAppDelegate.swift
//  Pawl
//
//  Hosts the launch work SwiftUI's App lifecycle can't. 2.3: the heartbeat background task,
//  push registration and the Approve/Deny notification actions were removed with the ally
//  feature and the backend. Pawl asks for no notification permission and sends nothing.
//

import UIKit

final class PawlAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in ReviewPrompter.noteLaunch() }   // install clock for rating asks
        return true
    }
}
