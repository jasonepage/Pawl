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
    /// 2.2: the last seven days as plain counts (WeekCard). nil until the first refresh.
    public private(set) var week: WeeklyReport?
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
        let unlocks = (try? await repo.unlocks(for: c.id)) ?? []
        week = WeeklyReport.make(
            commitmentStart: c.startedAt,
            relapses: relapses.map(\.occurredAt),
            urges: urges.map(\.occurredAt),
            attempts: SharedState.blockAttemptStamps(),
            completedUnlocks: unlocks.filter { $0.outcome == .completed || $0.outcome == .expired }
                                     .compactMap { $0.coolingOffEndsAt ?? $0.completedAt },
            triggers: urges.compactMap { u in u.trigger.map { (date: u.occurredAt, text: $0) } },
            now: Date()
        )
        cleanDays = Streak.cleanDays(
            commitmentStart: c.startedAt,
            lastRelapse: relapses.first?.occurredAt,   // sorted newest-first
            now: Date()
        )
    }

    /// FR-STREAK-002/003: logging a relapse resets the streak. Never weakens the
    /// shield (FR-STREAK-006) — there is no shield interaction here at all.
    public func logRelapse(note: String?, amount: Decimal?, occurredAt: Date = Date()) async {
        guard let c = commitment else { return }
        // Never in the future, never before the commitment started.
        let when = min(max(occurredAt, c.startedAt), Date())
        try? await repo.append(relapse: RelapseEvent(
            commitmentID: c.id, occurredAt: when,
            note: note?.isEmpty == true ? nil : note, amount: amount
        ))
        await refresh()
    }

    /// 2.2: the log is an honor system. Removing an entry recounts the streak from whatever
    /// relapse is newest after it, or from the start if none remain.
    public func removeRelapse(_ event: RelapseEvent) async {
        try? await repo.remove(relapseID: event.id)
        await refresh()
    }

    public func removeUrge(_ event: UrgeEvent) async {
        try? await repo.remove(urgeID: event.id)
        await refresh()
    }

    /// One entry in the merged History: a relapse, or an urge that was ridden out.
    public enum HistoryEntry: Identifiable {
        case relapse(RelapseEvent)
        case urge(UrgeEvent)
        public var id: UUID {
            switch self {
            case .relapse(let e): return e.id
            case .urge(let e):    return e.id
            }
        }
        public var occurredAt: Date {
            switch self {
            case .relapse(let e): return e.occurredAt
            case .urge(let e):    return e.occurredAt
            }
        }
        public var note: String? {
            switch self {
            case .relapse(let e): return e.note
            case .urge(let e):    return e.note
            }
        }
    }

    /// Relapses and urges together, newest first.
    public var history: [HistoryEntry] {
        (relapses.map(HistoryEntry.relapse) + urges.map(HistoryEntry.urge))
            .sorted { $0.occurredAt > $1.occurredAt }
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
