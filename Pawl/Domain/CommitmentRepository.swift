// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CommitmentRepository.swift
//  Pawl — Domain core
//
//  The single persistence seam features talk to (SDS §2.1, §2.5; SRS NFR-MAINT-001).
//  Phase 1 backs this with App Group (local, authoritative at runtime) + CloudKit
//  (durable mirror). Phase 2 adds a Supabase-backed implementation behind the SAME
//  protocol — no feature code changes. No custom backend in P1 (FR-PERSIST-004).
//

import Foundation

/// A consistent view of a commitment for reinstall recovery (SDS §4.5, FR-PERSIST-002).
public struct CommitmentSnapshot: Codable, Sendable, Equatable {
    public var commitment: Commitment
    public var blockSet: BlockSet
    public var keyPairing: KeyPairing?

    public init(commitment: Commitment, blockSet: BlockSet, keyPairing: KeyPairing?) {
        self.commitment = commitment
        self.blockSet = blockSet
        self.keyPairing = keyPairing
    }
}

public protocol CommitmentRepository: Sendable {
    /// Returns the active commitment (if any) so the app can re-apply the shield
    /// on launch / after reinstall (FR-PERSIST-002).
    func loadActiveCommitment() async throws -> CommitmentSnapshot?

    /// Persist the commitment definition (App Group + CloudKit mirror).
    func save(_ snapshot: CommitmentSnapshot) async throws

    func append(relapse: RelapseEvent) async throws
    func append(urge: UrgeEvent) async throws

    func append(unlock: UnlockRequest) async throws
    func update(unlock: UnlockRequest) async throws

    func relapses(for commitmentID: UUID) async throws -> [RelapseEvent]
    func urges(for commitmentID: UUID) async throws -> [UrgeEvent]
    func unlocks(for commitmentID: UUID) async throws -> [UnlockRequest]
}

// MARK: - Reconcile policy (SDS §2.5; FR-PERSIST-003)

public enum CommitmentReconciler {
    /// Merge a local and a remote snapshot. Last-writer-wins by `updatedAt`, EXCEPT
    /// the active/locked state is sticky toward "more locked": a stale *unlocked*
    /// remote record must never override a locally *active* shield. This guarantees
    /// reinstalling produces no reduction in friction (FR-PERSIST-003).
    public static func merge(local: CommitmentSnapshot?, remote: CommitmentSnapshot?) -> CommitmentSnapshot? {
        switch (local, remote) {
        case (nil, nil): return nil
        case (let l?, nil): return l
        case (nil, let r?): return r
        case (let l?, let r?):
            // If either side is active, the result is active (locked-wins).
            let eitherActive = l.commitment.status == .active || r.commitment.status == .active
            var winner = l.commitment.updatedAt >= r.commitment.updatedAt ? l : r
            if eitherActive { winner.commitment.status = .active }
            return winner
        }
    }
}

// MARK: - In-memory implementation (tests, previews, early development)

@MainActor
public final class InMemoryCommitmentRepository: CommitmentRepository {
    private var snapshot: CommitmentSnapshot?
    private var relapseLog: [RelapseEvent] = []
    private var urgeLog: [UrgeEvent] = []
    private var unlockLog: [UnlockRequest] = []

    public init(seed: CommitmentSnapshot? = nil) { self.snapshot = seed }

    public func loadActiveCommitment() async throws -> CommitmentSnapshot? {
        guard let snapshot, snapshot.commitment.status == .active else { return nil }
        return snapshot
    }

    public func save(_ snapshot: CommitmentSnapshot) async throws {
        self.snapshot = snapshot
    }

    public func append(relapse: RelapseEvent) async throws { relapseLog.append(relapse) }
    public func append(urge: UrgeEvent) async throws { urgeLog.append(urge) }

    public func append(unlock: UnlockRequest) async throws { unlockLog.append(unlock) }
    public func update(unlock: UnlockRequest) async throws {
        if let i = unlockLog.firstIndex(where: { $0.id == unlock.id }) {
            unlockLog[i] = unlock
        } else {
            unlockLog.append(unlock)
        }
    }

    public func relapses(for commitmentID: UUID) async throws -> [RelapseEvent] {
        relapseLog.filter { $0.commitmentID == commitmentID }.sorted { $0.occurredAt > $1.occurredAt }
    }
    public func urges(for commitmentID: UUID) async throws -> [UrgeEvent] {
        urgeLog.filter { $0.commitmentID == commitmentID }.sorted { $0.occurredAt > $1.occurredAt }
    }
    public func unlocks(for commitmentID: UUID) async throws -> [UnlockRequest] {
        unlockLog.filter { $0.commitmentID == commitmentID }.sorted { $0.requestedAt > $1.requestedAt }
    }
}
