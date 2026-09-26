// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  HeartbeatService.swift
//  Pawl — Phase 2 backend (slice 5: heartbeat / tamper detection)
//
//  Sends a periodic liveness beat (record_heartbeat RPC) on launch, foreground, and
//  opportunistically via BGTaskScheduler — DeviceActivity is for shielding, not networking
//  (FR-P2-HEART-002). The backend detects silence (deleted app / revoked auth) and alerts the
//  sponsor (HC-6). On launch it also reports auth-lost if Screen Time was revoked while a
//  sponsor-mode commitment is active (FR-P2-HEART-005).
//
//  Liveness is keyed by identifierForVendor, NOT the APNs token, so it works even if the user
//  denies push. The APNs token is stored opportunistically for the later real-time-push layer.
//

import Foundation
import Supabase
import BackgroundTasks
import UIKit
import FamilyControls

@MainActor
public final class HeartbeatService {
    public static let shared = HeartbeatService()
    public static let taskID = SupabaseConfig.heartbeatTaskID

    private let client = Supa.client
    private var apnsToken: String?
    /// Last auth status we beat with, so the real-time push fires only on the on→off transition.
    private var lastAuthStatus: String?

    private init() {}

    private var deviceUID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    public func setAPNsToken(_ token: String) { apnsToken = token }

    /// Send a heartbeat (no-op when signed out). Also reports auth-lost when appropriate.
    public func beat() async {
        guard client.auth.currentUser != nil else { return }
        let authStatus = Self.authStatusString()

        struct Beat: Encodable {
            let p_device_uid: String
            let p_apns_token: String?
            let p_auth_status: String
        }
        do {
            try await client.rpc("record_heartbeat",
                params: Beat(p_device_uid: deviceUID, p_apns_token: apnsToken, p_auth_status: authStatus))
                .execute()
        } catch {
            // Transient (offline / token refresh). Liveness will catch up on the next beat.
        }

        if authStatus != "approved" {
            _ = try? await client.rpc("report_auth_lost").execute()
            // Real-time alert: when Screen Time has JUST gone from on → off, ping detect-silence so
            // the sponsor is pushed immediately instead of waiting for the hourly cron. The alert's
            // `notified` flag stops the cron (or a later beat) from pushing the same one again.
            if lastAuthStatus == nil || lastAuthStatus == "approved" {
                try? await client.functions.invoke("detect-silence")
            }
        }
        lastAuthStatus = authStatus
    }

    /// Call when the app comes to the foreground. FamilyControls' `authorizationStatus` can read
    /// stale for a moment on a warm resume — so Screen Time turned off while Pawl was backgrounded
    /// looked fine until a full relaunch. Beat now, then re-check a couple times over a few seconds
    /// (each `beat()` re-reads the live status) so a just-revoked Screen Time is reported without the
    /// user force-quitting. `report_auth_lost` is idempotent, so repeat beats are harmless.
    public func beatOnForeground() async {
        await beat()
        for _ in 0..<2 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)   // ~2s
            await beat()
        }
    }

    private static func authStatusString() -> String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return "approved"
        case .denied:   return "denied"
        default:        return "notDetermined"
        }
    }

    // MARK: - BGTaskScheduler (opportunistic background beats)

    /// Must be called before the app finishes launching (from the app delegate).
    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskID, using: nil) { task in
            // The launch handler runs off the main actor and BGTask isn't Sendable, so opt
            // out of the isolation check for this single hop onto the main actor.
            nonisolated(unsafe) let task = task
            let work = Task { @MainActor in
                HeartbeatService.shared.scheduleBackgroundBeat()   // chain the next beat
                await HeartbeatService.shared.beat()
                task.setTaskCompleted(success: !Task.isCancelled)   // the only completion call
            }
            // If iOS runs out of time, cancel the beat; the task above still completes once.
            task.expirationHandler = { work.cancel() }
        }
    }

    public func scheduleBackgroundBeat() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)   // ~4h; iOS decides
        try? BGTaskScheduler.shared.submit(request)
    }
}
