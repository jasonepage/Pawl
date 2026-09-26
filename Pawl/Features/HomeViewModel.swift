// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  HomeViewModel.swift
//  Pawl — Home
//
//  Streak + relapse + urge logic over the repository (SRS §3.5, §3.6). Runs with
//  ZERO Screen Time / NFC capabilities — fully testable on device or Simulator now.
//

import Foundation

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var cleanDays = 0
    public private(set) var relapses: [RelapseEvent] = []
    public private(set) var urges: [UrgeEvent] = []
    public private(set) var commitment: Commitment?

    private let repo: CommitmentRepository

    // Default arg is `nil` (not a @MainActor value); the real repository is built
    // inside the init body, which IS main-actor-isolated, so this compiles cleanly.
    // Defaults to the iCloud-backed repo so the streak survives reinstall (FR-PERSIST).
    public init(repo: CommitmentRepository? = nil) {
        self.repo = repo ?? CloudCommitmentRepository()
    }

    /// Load or create the single Phase-1 commitment, then refresh derived data.
    public func load() async {
        if let snap = try? await repo.loadActiveCommitment() {
            commitment = snap.commitment
        } else {
            let c = Commitment(startedAt: Date(), updatedAt: Date())
            let snap = CommitmentSnapshot(
                commitment: c,
                blockSet: BlockSet(commitmentID: c.id, updatedAt: Date()),
                keyPairing: nil
            )
            try? await repo.save(snap)
            commitment = c
        }
        await refresh()
    }

    public func refresh() async {
        guard let c = commitment else { return }
        relapses = (try? await repo.relapses(for: c.id)) ?? []
        urges = (try? await repo.urges(for: c.id)) ?? []
        cleanDays = Streak.cleanDays(
            commitmentStart: c.startedAt,
            lastRelapse: relapses.first?.occurredAt,   // sorted newest-first
            now: Date()
        )
    }

    /// FR-STREAK-002/003: logging a relapse resets the streak. Never weakens the
    /// shield (FR-STREAK-006) — there is no shield interaction here at all.
    public func logRelapse(note: String?, amount: Decimal?) async {
        guard let c = commitment else { return }
        try? await repo.append(relapse: RelapseEvent(
            commitmentID: c.id, occurredAt: Date(),
            note: note?.isEmpty == true ? nil : note, amount: amount
        ))
        await refresh()
    }

    /// FR-URGE-002/004: log an urge. Never offers an unblock (FR-URGE-003).
    public func logUrge(intensity: Int?, trigger: String?, note: String?) async {
        guard let c = commitment else { return }
        try? await repo.append(urge: UrgeEvent(
            commitmentID: c.id, occurredAt: Date(),
            intensity: intensity,
            trigger: trigger?.isEmpty == true ? nil : trigger,
            note: note?.isEmpty == true ? nil : note
        ))
        await refresh()
    }
}
