// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  PawlAppDelegate.swift
//  Pawl — Phase 2 (slice 5)
//
//  Hosts the bits SwiftUI's App lifecycle can't: BGTaskScheduler registration (must happen
//  before launch finishes) and APNs registration + device-token capture. The token is handed
//  to HeartbeatService so the next beat stores it for the later push layer.
//

import UIKit
import UserNotifications

final class PawlAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register the heartbeat BG task identifier (matches Info.plist + SupabaseConfig).
        HeartbeatService.shared.registerBackgroundTask()
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        requestPush(application)
        return true
    }

    /// Approve/Deny actions on the unlock-request push, so a sponsor can decide from the banner
    /// without opening the app (FR-P2-NOTIF-004). The push payload sets `aps.category` to
    /// "UNLOCK_REQUEST" and includes `request_id`. Approve requires the device be unlocked.
    private func registerNotificationCategories() {
        let approve = UNNotificationAction(identifier: "APPROVE", title: "Approve",
                                           options: [.authenticationRequired])
        let deny = UNNotificationAction(identifier: "DENY", title: "Deny",
                                        options: [.destructive])
        let unlock = UNNotificationCategory(identifier: "UNLOCK_REQUEST",
                                            actions: [approve, deny],
                                            intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([unlock])
    }

    private func requestPush(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }   // liveness still works without push; token just won't store
            // Don't capture the non-Sendable `application`; reach it on the main actor.
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            HeartbeatService.shared.setAPNsToken(token)
            await HeartbeatService.shared.beat()
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // e.g. Simulator / push denied — heartbeat still works (keyed by device id).
    }
}

extension PawlAppDelegate: UNUserNotificationCenterDelegate {
    // Show Pawl pushes (unlock request / decision / tamper) even while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle the Approve/Deny actions tapped on an unlock-request push (FR-P2-NOTIF-004). Runs
    // even when the app is backgrounded; the decide_unlock RPC enforces sponsor authorization.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        guard let requestID = userInfo["request_id"] as? String,
              action == "APPROVE" || action == "DENY" else {
            completionHandler(); return
        }
        let approved = (action == "APPROVE")
        Task { @MainActor in
            await UnlockApprovalService().decide(requestID: requestID, approved: approved)
            completionHandler()
        }
    }
}
