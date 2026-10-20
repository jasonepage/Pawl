// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlAppDelegate.swift
//  Pawl
//
//  Hosts the launch work SwiftUI's App lifecycle can't. 2.3: the heartbeat background task,
//  push registration and the Approve/Deny notification actions were removed with the ally
//  feature and the backend. The only notifications left are the local unlock reminders
//  (UnlockReminders), and this delegate lets them show while Pawl is open too.
//

import UIKit
import UserNotifications

final class PawlAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in ReviewPrompter.noteLaunch() }   // install clock for rating asks
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show an unlock reminder as a banner even when Pawl is on screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
