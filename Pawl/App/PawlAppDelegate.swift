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
import CloudKit

extension Notification.Name {
    /// 2.5: a CloudKit push arrived (the ally answered, or the owner asked). Listeners fetch
    /// what changed; the push itself carries nothing.
    static let pawlAllyCloudChanged = Notification.Name("pawl.ally.cloudChanged")
}

final class PawlAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in ReviewPrompter.noteLaunch() }   // install clock for rating asks
        UNUserNotificationCenter.current().delegate = self
        // 2.5: ally approvals ride on CloudKit pushes. Registering asks the user nothing (only
        // visible notifications need permission, and the ally side asks for that when joining).
        // Only phones that are part of a pairing register; everyone else never touches push.
        Task { @MainActor in
            if AllyStore.shared.pairing() != nil || AllyStore.shared.role() != nil {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    /// 2.5: a CloudKit push. Tell whoever is listening, then let iOS know we are done. Nothing
    /// here touches the shield: a push can only make the app go and read iCloud.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        NotificationCenter.default.post(name: .pawlAllyCloudChanged, object: nil)
        // Give the listener a moment to fetch before iOS suspends us again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { completionHandler(.newData) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Nothing to do: the owner polls while the Unlock screen is open, and the ally can
        // always open Pawl and see the request. Pushes are a convenience, never the mechanism.
    }

    /// Show an unlock reminder as a banner even when Pawl is on screen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
