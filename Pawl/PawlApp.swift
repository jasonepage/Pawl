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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
