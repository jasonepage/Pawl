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
    /// 2.4: a CloudKit push arrived (the ally answered, or the owner asked). Listeners fetch
    /// what changed; the push itself carries nothing.
    static let pawlAllyCloudChanged = Notification.Name("pawl.ally.cloudChanged")
}

final class PawlAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in ReviewPrompter.noteLaunch() }   // install clock for rating asks
        UNUserNotificationCenter.current().delegate = self
        // 2.4: ally approvals ride on CloudKit pushes. Registering asks the user nothing (only
        // visible notifications need permission, and the ally side asks for that when joining).
        // Only phones that are part of a pairing register; everyone else never touches push.
        Task { @MainActor in
            if AllyStore.shared.pairing() != nil || AllyStore.shared.role() != nil {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    /// 2.4: a CloudKit push. Tell whoever is listening, then let iOS know we are done. Nothing
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

    /// 2.4: an iCloud share link (the ally invite) is handed to the window scene delegate, so
    /// the app names one. SwiftUI keeps running the window; this class only listens.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = PawlSceneDelegate.self
        return config
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

extension Notification.Name {
    /// 2.4: the person opened an ally invite link. The object is the CKShare.Metadata.
    static let pawlAllyInvite = Notification.Name("pawl.ally.invite")
}

final class PawlSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Cold launch from an invite link: the metadata rides in the connection options. Post it a
    /// moment later so the SwiftUI view that listens exists by then.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NotificationCenter.default.post(name: .pawlAllyInvite, object: metadata)
        }
    }

    /// Warm launch from an invite link.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        NotificationCenter.default.post(name: .pawlAllyInvite, object: cloudKitShareMetadata)
    }
}
