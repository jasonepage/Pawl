// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  SupabaseCommitmentRepository.swift
//  Pawl — Phase 2 backend (slice 2: repository swap)
//
//  A CommitmentRepository that makes Supabase the canonical store for the commitment
//  DEFINITION (FR-P2-SYNC-001/005), while a wrapped iCloud cache stays the offline +
//  reinstall source (FR-P2-SYNC-003) and the App Group stays runtime-authoritative for the
//  live shield (FR-P2-SYNC-002). Feature code is unchanged — it still talks to the protocol.
//
//  Design = decorator over the existing CloudCommitmentRepository:
//   • save  → write the cache always, then best-effort upsert to Supabase (signed in only).
//   • load  → read cache + remote, reconcile LOCKED-WINS (FR-PERSIST-003 / FR-P2-SYNC-004),
//             persist the result back to the cache, push it to Supabase.
//   • logs  → delegate to the cache (relapse/urge stay owner-only; unlock_requests get their
//             own Supabase path in the approval slice).
//
//  The opaque selection tokens (BlockSet) never go to Supabase — they live in iCloud only
//  (HC-1). Signed out / offline, everything falls back to the cache (FR-P2-AUTH-005).
//

import Foundation
import Supabase

@MainActor
public final class SupabaseCommitmentRepository: CommitmentRepository {
    private let inner: CommitmentRepository      // iCloud KVS cache (offline + reinstall)
    private let client = Supa.client

    public init(cache: CommitmentRepository) {
        self.inner = cache
    }

    /// Present only when there's a live Supabase session; nil → cache-only behaviour.
    private var currentUserID: String? {
        client.auth.currentUser?.id.uuidString
    }

    // MARK: - Commitment (canonical in Supabase when signed in)

    public func loadActiveCommitment() async throws -> CommitmentSnapshot? {
        let local = try await inner.loadActiveCommitment()
        guard let userID = currentUserID else { return local }   // signed out → cache only

        let remoteCommitment = try? await fetchRemoteActiveCommitment(userID: userID)

        // Reconcile the commitment STATUS only (locked-wins). BlockSet + key stay local: the
        // opaque selection tokens live in iCloud, not Supabase (HC-1, FR-P2-SYNC-003).
        let remoteSnap: CommitmentSnapshot? = remoteCommitment.map { c in
            CommitmentSnapshot(
                commitment: c,
                blockSet: local?.blockSet ?? BlockSet(commitmentID: c.id, updatedAt: c.updatedAt),
                keyPairing: local?.keyPairing
            )
        }
        let merged = CommitmentReconciler.merge(local: local, remote: remoteSnap)

        if let merged {
            try? await inner.save(merged)                               // keep cache consistent
            try? await upsertRemote(merged.commitment, userID: userID)  // push the locked-wins result
        }
        return merged
    }

    public func save(_ snapshot: CommitmentSnapshot) async throws {
        try await inner.save(snapshot)                            // cache always (offline/reinstall)
        guard let userID = currentUserID else { return }         // signed out → cache only
        try? await upsertRemote(snapshot.commitment, userID: userID)  // best-effort canonical write
    }

    // MARK: - Logs (delegate to the cache for now)

    public func append(relapse: RelapseEvent) async throws { try await inner.append(relapse: relapse) }
    public func append(urge: UrgeEvent) async throws { try await inner.append(urge: urge) }
    public func append(unlock: UnlockRequest) async throws { try await inner.append(unlock: unlock) }
    public func update(unlock: UnlockRequest) async throws { try await inner.update(unlock: unlock) }
    public func relapses(for id: UUID) async throws -> [RelapseEvent] { try await inner.relapses(for: id) }
    public func urges(for id: UUID) async throws -> [UrgeEvent] { try await inner.urges(for: id) }
    public func unlocks(for id: UUID) async throws -> [UnlockRequest] { try await inner.unlocks(for: id) }

    // MARK: - Supabase row mapping
    // Dates use Date directly — supabase-swift's PostgREST coders handle Postgres timestamptz
    // (incl. microsecond precision), which is more robust than hand-rolled ISO8601 parsing.

    private struct CommitmentUpsert: Encodable {
        let id: String
        let user_id: String
        let status: String
        let started_at: Date
        let cooling_off_seconds: Int
        let grace_seconds: Int
        let updated_at: Date
        // sponsor_mode intentionally OMITTED: upsert preserves a server-set `true`
        // (redeem_invite flips it) rather than clobbering it to false.
    }

    private struct CommitmentRow: Decodable {
        let id: String
        let status: String
        let started_at: Date
        let cooling_off_seconds: Int
        let grace_seconds: Int
        let updated_at: Date
    }

    private func upsertRemote(_ c: Commitment, userID: String) async throws {
        let row = CommitmentUpsert(
            id: c.id.uuidString,
            user_id: userID,
            status: c.status.rawValue,
            started_at: c.startedAt,
            cooling_off_seconds: Int(c.coolingOffSeconds),
            grace_seconds: Int(c.graceSeconds),
            updated_at: c.updatedAt
        )
        try await client.from("commitments").upsert(row).execute()
    }

    private func fetchRemoteActiveCommitment(userID: String) async throws -> Commitment? {
        let rows: [CommitmentRow] = try await client
            .from("commitments")
            .select("id,status,started_at,cooling_off_seconds,grace_seconds,updated_at")
            .eq("user_id", value: userID)
            .eq("status", value: "active")
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let r = rows.first else { return nil }
        return Commitment(
            id: UUID(uuidString: r.id) ?? UUID(),
            status: CommitmentStatus(rawValue: r.status) ?? .active,
            startedAt: r.started_at,
            coolingOffSeconds: TimeInterval(r.cooling_off_seconds),
            graceSeconds: TimeInterval(r.grace_seconds),
            updatedAt: r.updated_at
        )
    }
}
