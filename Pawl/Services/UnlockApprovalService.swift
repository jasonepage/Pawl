// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UnlockApprovalService.swift
//  Pawl — Phase 2 backend (slice 4: sponsor-gated unlock, polling)
//
//  User side: create an unlock_request on a valid key tap (FR-P2-SPON-002), then poll for
//  the sponsor's decision; cancel resolves it (FR-P2-SPON-006). Sponsor side: list pending
//  requests for linked users and approve/deny via the decide_unlock RPC (FR-P2-SPON-003/004).
//
//  Polling, not push — works with no Edge Functions/APNs. APNs makes it real-time later.
//

import Foundation
import Supabase

@MainActor
@Observable
public final class UnlockApprovalService {
    public enum Decision: Sendable { case approved, denied, expired, failed }

    public struct PendingRequest: Identifiable, Decodable, Sendable {
        public let id: String
        public let user_id: String
        public let requested_at: Date
        public let status: String
        public var kind: String = "unlock"   // "unlock" | "remove_app" | "disable_category"
    }

    public struct TamperAlert: Identifiable, Decodable, Sendable {
        public let id: String
        public let user_id: String
        public let kind: String          // "silence" | "auth_lost"
        public let detected_at: Date
        public let recovered_at: Date?   // system saw it fixed — still shown, flagged "back to normal"
        public let resolved_at: Date?
        public var hard_locked: Bool = false   // fired while the commitment was hard-locked → breach
    }

    /// Hard-lock status of a person this user sponsors, for the Approvals overview (FR-P3-HARD-006).
    public struct ProtectionStatus: Identifiable, Sendable {
        public let id: String          // user_id
        public let hardLockActive: Bool
        public let attestedAt: Date?
        public var name: String = "Someone you sponsor"
    }

    /// Pending requests this user can act on as a SPONSOR.
    public private(set) var sponsorPending: [PendingRequest] = []
    /// Display name per requesting user_id (lowercased key), for the Approvals UI.
    public private(set) var requesterNames: [String: String] = [:]
    /// Open tamper alerts for people this user sponsors (FR-P2-HEART-004).
    public private(set) var sponsorTamper: [TamperAlert] = []
    /// Hard-lock status per sponsored person, for the Approvals overview (FR-P3-HARD-006).
    public private(set) var sponsoredProtection: [ProtectionStatus] = []
    public private(set) var message: String?

    private let client = Supa.client
    private var myID: String? { client.auth.currentUser?.id.uuidString }

    public init() {}

    // MARK: - User side (the person unlocking)

    /// Create a pending unlock_request and return its id (FR-P2-SPON-002). `kind` tells the
    /// sponsor what's being asked: "unlock" (shield), "remove_app", or "disable_category".
    public func createRequest(commitmentID: UUID, kind: String = "unlock") async throws -> UUID {
        guard let myID else { throw Err.notSignedIn }
        let id = UUID()
        struct NewRequest: Encodable {
            let id: String
            let commitment_id: String
            let user_id: String
            let kind: String
        }
        try await client.from("unlock_requests")
            .insert(NewRequest(id: id.uuidString, commitment_id: commitmentID.uuidString, user_id: myID, kind: kind))
            .execute()

        // Best-effort real-time push to the sponsor (no-op if Edge Functions aren't deployed;
        // the polling path still works regardless).
        struct NotifySponsor: Encodable { let request_id: String }
        try? await client.functions.invoke("notify-sponsor",
            options: FunctionInvokeOptions(body: NotifySponsor(request_id: id.uuidString)))
        return id
    }

    /// Poll until the sponsor decides or the request expires (FR-P2-SPON-003/004/005).
    /// `intervalSeconds` between checks; gives up after `maxSeconds` (defaults near the
    /// server's 60-min expiry).
    public func pollDecision(requestID: UUID,
                             intervalSeconds: UInt64 = 3,
                             maxSeconds: Int = 3600) async -> Decision {
        struct StatusRow: Decodable { let status: String }
        let deadline = Date().addingTimeInterval(TimeInterval(maxSeconds))
        while Date() < deadline {
            if Task.isCancelled { return .failed }
            do {
                let rows: [StatusRow] = try await client.from("unlock_requests")
                    .select("status")
                    .eq("id", value: requestID.uuidString)
                    .limit(1)
                    .execute()
                    .value
                switch rows.first?.status {
                case "approved":  return .approved
                case "denied":    return .denied
                case "expired", "cancelled": return .expired
                default: break   // still pending
                }
            } catch {
                // Transient network error — keep polling.
            }
            try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
        }
        return .expired
    }

    /// User backs out before a decision (FR-P2-SPON-006).
    public func cancel(requestID: UUID) async throws {
        struct StatusUpdate: Encodable { let status: String }
        try await client.from("unlock_requests")
            .update(StatusUpdate(status: "cancelled"))
            .eq("id", value: requestID.uuidString)
            .eq("status", value: "pending")
            .execute()
    }

    // MARK: - Sponsor side (the person approving)

    /// Load pending requests for people I sponsor (RLS returns only linked users' rows).
    public func refreshSponsorPending() async {
        guard let myID else { sponsorPending = []; return }
        do {
            let rows: [PendingRequest] = try await client.from("unlock_requests")
                .select("id,user_id,requested_at,status,kind")
                .eq("status", value: "pending")
                .order("requested_at", ascending: true)
                .execute()
                .value
            // Drop any of my own requests (I might also be a protected user).
            sponsorPending = rows.filter { $0.user_id.caseInsensitiveCompare(myID) != .orderedSame }
            await loadNames(for: sponsorPending.map { $0.user_id })
        } catch is CancellationError {
            // benign — a polling/refresh task was cancelled (e.g. switching tabs)
        } catch {
            message = error.localizedDescription
        }
    }

    /// Merge display names for these user_ids into `requesterNames` (RLS lets a sponsor read linked
    /// users' profiles). Shared by requests, tamper alerts, and the sponsor list so every row is
    /// attributed to the right person — essential once you sponsor more than one (FR-P2-SPON-008).
    private func loadNames(for userIDs: [String]) async {
        let ids = Array(Set(userIDs))
        guard !ids.isEmpty else { return }
        struct Prof: Decodable { let id: String; let display_name: String? }
        do {
            let profs: [Prof] = try await client.from("profiles")
                .select("id,display_name")
                .in("id", values: ids)
                .execute()
                .value
            for p in profs where (p.display_name?.isEmpty == false) {
                requesterNames[p.id.lowercased()] = p.display_name
            }
        } catch {
            // names are best-effort; rows fall back to a neutral label
        }
    }

    /// Display name for a sponsored user, or a neutral fallback.
    public func name(forUser id: String) -> String {
        requesterNames[id.lowercased()] ?? "Someone you sponsor"
    }

    /// Load open tamper alerts for people I sponsor (RLS returns linked users' rows).
    public func refreshSponsorTamper() async {
        guard let myID else { sponsorTamper = []; return }
        do {
            let rows: [TamperAlert] = try await client.from("tamper_alerts")
                .select("id,user_id,kind,detected_at,recovered_at,resolved_at,hard_locked")
                .order("detected_at", ascending: false)
                .execute()
                .value
            sponsorTamper = rows.filter {
                $0.resolved_at == nil && $0.user_id.caseInsensitiveCompare(myID) != .orderedSame
            }
            await loadNames(for: sponsorTamper.map { $0.user_id })
        } catch is CancellationError {
            // benign — a polling/refresh task was cancelled (e.g. switching tabs)
        } catch {
            message = error.localizedDescription
        }
    }

    /// Load hard-lock status for the people I sponsor (RLS returns only linked users' commitments).
    public func refreshSponsoredProtection() async {
        guard let myID else { sponsoredProtection = []; return }
        struct Row: Decodable { let user_id: String; let hard_lock_active: Bool; let hard_lock_attested_at: Date? }
        do {
            let rows: [Row] = try await client.from("commitments")
                .select("user_id,hard_lock_active,hard_lock_attested_at")
                .eq("status", value: "active")
                .execute()
                .value
            let theirs = rows.filter { $0.user_id.caseInsensitiveCompare(myID) != .orderedSame }
            await loadNames(for: theirs.map { $0.user_id })
            sponsoredProtection = theirs.map {
                ProtectionStatus(id: $0.user_id,
                                 hardLockActive: $0.hard_lock_active,
                                 attestedAt: $0.hard_lock_attested_at,
                                 name: name(forUser: $0.user_id))
            }
        } catch is CancellationError {
            // benign — polling cancelled (e.g. tab switch)
        } catch {
            message = error.localizedDescription
        }
    }

    /// Mark a tamper alert handled (user or active sponsor). Hides it from the Approvals list.
    public func resolveTamper(id: String) async {
        struct Params: Encodable { let alert_id: String }
        do {
            try await client.rpc("resolve_tamper_alert", params: Params(alert_id: id)).execute()
            await refreshSponsorTamper()
        } catch is CancellationError {
            // benign — a polling/refresh task was cancelled (e.g. switching tabs)
        } catch {
            message = error.localizedDescription
        }
    }

    /// Approve or deny via the SECURITY DEFINER RPC (FR-P2-SPON-003/004), then refresh the list.
    public func decide(_ request: PendingRequest, approved: Bool) async {
        await decide(requestID: request.id, approved: approved)
        await refreshSponsorPending()
    }

    /// Decide directly by request id — used by the notification-action handler, which only has
    /// the id from the push payload (FR-P2-NOTIF-004). Same RPC + best-effort requester push.
    /// Safe to call from a background launch (the RPC enforces sponsor authorization server-side).
    public func decide(requestID: String, approved: Bool) async {
        struct Params: Encodable { let request_id: String; let approved: Bool }
        do {
            try await client.rpc("decide_unlock",
                                  params: Params(request_id: requestID, approved: approved))
                .execute()
            struct NotifyUser: Encodable { let request_id: String; let approved: Bool }
            try? await client.functions.invoke("notify-user",
                options: FunctionInvokeOptions(body: NotifyUser(request_id: requestID, approved: approved)))
        } catch is CancellationError {
            // benign — a polling/refresh task was cancelled (e.g. switching tabs)
        } catch {
            message = error.localizedDescription
        }
    }

    enum Err: LocalizedError {
        case notSignedIn
        var errorDescription: String? { "Sign in to use sponsor mode." }
    }
}
