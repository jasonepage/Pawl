// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SponsorService.swift
//  Pawl — Phase 2 backend (slice 3: sponsor linking)
//
//  A user invites a sponsor with a single-use, expiring invite code; the sponsor redeems it
//  server-side via the `redeem_invite` RPC (least privilege — the sponsor never gets write
//  grants on the user's rows, FR-P2-LINK-002). Redemption flips the user's active commitment
//  into sponsor mode (FR-P2-LINK-005). Either side reads only what RLS allows.
//
//  Slice 3 establishes the LINK + sponsor_mode flag. Gating unlocks on approval is slice 4.
//

import Foundation
import Security
import Supabase

@MainActor
@Observable
public final class SponsorService {
    public struct Link: Identifiable, Decodable, Sendable {
        public let id: String
        public let user_id: String
        public let sponsor_id: String?
        public let invite_code: String
        public let status: String
        public let expires_at: Date?
        /// Server-side creation time — limits grandfathering to pre-Pro links (AppModel).
        public let created_at: Date?
    }

    /// Links where I'm the protected person (I invited a sponsor).
    public private(set) var asProtected: [Link] = []
    /// Links where I'm the sponsor.
    public private(set) var asSponsor: [Link] = []
    /// Display name per linked user_id (lowercased), so the UI can name who you sponsor.
    public private(set) var names: [String: String] = [:]
    public private(set) var message: String?
    public private(set) var isBusy = false
    /// True once a refresh has authoritatively loaded links (gates the one-time grandfather check).
    public private(set) var didLoad = false

    private let client = Supa.client
    private var myID: String? { client.auth.currentUser?.id.uuidString }

    public init() {}

    /// 2.1: a device-local record that this phone's user has an active sponsor. Set whenever
    /// the server confirms an active link, and cleared only when the server confirms, for the
    /// SAME account, that none is left. Signing out, going offline, or signing into another
    /// account doesn't clear it, so none of those skips sponsor approval.
    public var rememberedSponsor: Bool { SponsorLatch.userID() != nil }

    /// RLS returns both my-as-user and my-as-sponsor rows; split them client-side.
    public func refresh() async {
        guard let myID else { asProtected = []; asSponsor = []; didLoad = true; return }
        do {
            let all: [Link] = try await client
                .from("sponsor_links")
                .select()
                .neq("status", value: "revoked")
                .execute()
                .value
            // Postgres returns UUIDs lowercase; Swift's UUID.uuidString is uppercase — compare
            // case-insensitively or every row gets filtered out.
            asProtected = all.filter { Self.sameID($0.user_id, myID) }
            asSponsor = all.filter { Self.sameID($0.sponsor_id, myID) }
            if asProtected.contains(where: { $0.status == "active" }) {
                SponsorLatch.set(userID: myID)
            } else if let latched = SponsorLatch.userID() {
                if Self.sameID(latched, myID) {
                    SponsorLatch.clear()     // the server says this account has no sponsor now
                } else if let still = try? await Self.hasActiveSponsor(latched), !still {
                    // The latched account (another sign-in, or deleted elsewhere) has no
                    // sponsor anymore, so stop waiting for one.
                    SponsorLatch.clear()
                }
            }
            await loadNames()
            didLoad = true
        } catch {
            message = error.localizedDescription
        }
    }

    /// Server check (migration 12): does this account still have an active sponsor?
    /// False for an account that no longer exists.
    private static func hasActiveSponsor(_ userID: String) async throws -> Bool {
        try await Supa.client.rpc("has_active_sponsor", params: ["target": userID]).execute().value
    }

    /// Best-effort display names for the people I sponsor (and my sponsor), so the UI can name them.
    private func loadNames() async {
        let ids = Array(Set(asSponsor.map { $0.user_id } + asProtected.compactMap { $0.sponsor_id }))
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else { return }
        struct Prof: Decodable { let id: String; let display_name: String? }
        do {
            let profs: [Prof] = try await client.from("profiles")
                .select("id,display_name").in("id", values: ids).execute().value
            for p in profs where (p.display_name?.isEmpty == false) {
                names[p.id.lowercased()] = p.display_name
            }
        } catch { /* names are best-effort */ }
    }

    /// Name of the person a sponsor link points at (the sponsee), or a neutral fallback.
    public func sponseeName(for link: Link) -> String {
        names[link.user_id.lowercased()] ?? "Someone you sponsor"
    }

    /// Create a single-use invite code for a sponsor to redeem (FR-P2-LINK-001).
    @discardableResult
    public func createInvite() async -> String? {
        guard let myID else { message = "Sign in first."; return nil }
        isBusy = true; defer { isBusy = false }
        let code = Self.generateCode()
        struct NewLink: Encodable { let user_id: String; let invite_code: String }
        do {
            try await revokeAllPending()        // never pile up more than one live invite
            try await client.from("sponsor_links")
                .insert(NewLink(user_id: myID, invite_code: code))
                .execute()
            await refresh()
            return code
        } catch {
            message = error.localizedDescription
            return nil
        }
    }

    /// Cancel the outstanding invite(s) — clears ALL pending links so the UI fully resets
    /// (a leftover from before could otherwise keep surfacing stale codes).
    public func cancelInvites() async {
        isBusy = true; defer { isBusy = false }
        do {
            try await revokeAllPending()
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    private func revokeAllPending() async throws {
        guard let myID else { return }
        struct StatusUpdate: Encodable { let status: String }
        try await client.from("sponsor_links")
            .update(StatusUpdate(status: "revoked"))
            .eq("user_id", value: myID)
            .eq("status", value: "pending")
            .execute()
    }

    /// Redeem someone's invite code to become their sponsor (FR-P2-LINK-002).
    public func redeem(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await client.rpc("redeem_invite", params: ["code": trimmed]).execute()
            message = "Linked ✓ You're now their sponsor."
            await refresh()
        } catch {
            message = Self.friendlyRedeemError(error)
        }
    }

    /// Revoke a link from the SPONSOR side (FR-P2-LINK-004). The `revoke_sponsorship` RPC is
    /// least-privilege: it verifies the caller is this link's active sponsor and downgrades the
    /// user's commitment to solo only if no other active sponsor remains.
    public func revokeAsSponsor(_ link: Link) async {
        isBusy = true; defer { isBusy = false }
        do {
            try await client.rpc("revoke_sponsorship", params: ["link_id": link.id]).execute()
            message = "You've stopped sponsoring."
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    /// Revoke a link from the protected-person side, downgrading to solo mode (FR-P2-LINK-004).
    public func revoke(_ link: Link) async {
        // 2.1: removing an active sponsor from this side is turned off, in the app and on the
        // server (migration 12), so it can't be done alone in a hard moment and without the
        // sponsor knowing. The sponsor can step down from their own app at any time.
        message = "To remove your sponsor, ask them to tap \"Stop sponsoring\" in their Pawl app. If you can't reach them or don't feel safe asking, email support@getpawl.com."
        return
    }

    /// The 2.0 protected-side removal, kept only for reference. Migration 12 blocks it.
    private func legacyRevoke(_ link: Link) async {
        guard let myID, Self.sameID(link.user_id, myID) else {
            message = "Only the person being sponsored can remove the link here for now."
            return
        }
        isBusy = true; defer { isBusy = false }
        struct StatusUpdate: Encodable { let status: String }
        struct SponsorModeUpdate: Encodable { let sponsor_mode: Bool }
        do {
            try await client.from("sponsor_links")
                .update(StatusUpdate(status: "revoked"))
                .eq("id", value: link.id)
                .execute()
            // Downgrade the active commitment back to solo (cooling-off only).
            try await client.from("commitments")
                .update(SponsorModeUpdate(sponsor_mode: false))
                .eq("user_id", value: myID)
                .eq("status", value: "active")
                .execute()
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    // MARK: - Helpers

    /// Case-insensitive UUID compare (Swift uppercase vs Postgres lowercase).
    private static func sameID(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b else { return false }
        return a.caseInsensitiveCompare(b) == .orderedSame
    }

    private static func friendlyRedeemError(_ error: Error) -> String {
        let s = "\(error)"
        if s.contains("invalid_or_expired_invite") { return "That code is invalid or expired." }
        return error.localizedDescription
    }

    /// Human-friendly code, no ambiguous characters (no O/0/I/1).
    static func generateCode(length: Int = 8) -> String {
        let charset = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count)] })
    }
}

/// Device-local Keychain record of "this account has an active sponsor" (2.1).
/// ThisDeviceOnly, and it survives deleting and reinstalling the app.
enum SponsorLatch {
    private static let service = "io.github.jasonepage.Pawl.sponsorLatch"
    private static let account = "pawl.sponsor.latchedUserID"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func userID() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(userID: String) {
        let data = Data(userID.utf8)
        let attrs: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var add = query
            add.merge(attrs) { _, new in new }
            _ = SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func clear() { _ = SecItemDelete(query as CFDictionary) }
}
