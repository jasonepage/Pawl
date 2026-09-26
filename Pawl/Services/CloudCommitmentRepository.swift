// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CloudCommitmentRepository.swift
//  Pawl — persistence
//
//  A CommitmentRepository backed by iCloud Key-Value storage, so the commitment,
//  streak, relapse and urge history survive deleting + reinstalling the app
//  (SRS FR-PERSIST-001/002/003). Same interface as the local repository, so feature
//  code doesn't change. Phase 2 can swap in CloudKit/Supabase behind the same protocol.
//

import Foundation

@MainActor
public final class CloudCommitmentRepository: CommitmentRepository {
    private let store = CloudStore.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let snapshot = "pawl.cloud.commitment.snapshot"
        static let relapses = "pawl.cloud.log.relapses"
        static let urges = "pawl.cloud.log.urges"
        static let unlocks = "pawl.cloud.log.unlocks"
    }

    public init() {}

    private func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    private func write<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) { store.set(data, forKey: key) }
    }
    private func readArray<T: Decodable>(_ key: String, as type: T.Type) -> [T] {
        read(key, as: [T].self) ?? []
    }

    public func loadActiveCommitment() async throws -> CommitmentSnapshot? {
        guard let snap = read(Key.snapshot, as: CommitmentSnapshot.self),
              snap.commitment.status == .active else { return nil }
        return snap
    }

    public func save(_ snapshot: CommitmentSnapshot) async throws {
        write(snapshot, key: Key.snapshot)
    }

    public func append(relapse: RelapseEvent) async throws {
        var all = readArray(Key.relapses, as: RelapseEvent.self); all.append(relapse)
        write(all, key: Key.relapses)
    }
    public func append(urge: UrgeEvent) async throws {
        var all = readArray(Key.urges, as: UrgeEvent.self); all.append(urge)
        write(all, key: Key.urges)
    }
    public func append(unlock: UnlockRequest) async throws {
        var all = readArray(Key.unlocks, as: UnlockRequest.self); all.append(unlock)
        write(all, key: Key.unlocks)
    }
    public func update(unlock: UnlockRequest) async throws {
        var all = readArray(Key.unlocks, as: UnlockRequest.self)
        if let i = all.firstIndex(where: { $0.id == unlock.id }) { all[i] = unlock } else { all.append(unlock) }
        write(all, key: Key.unlocks)
    }

    public func relapses(for commitmentID: UUID) async throws -> [RelapseEvent] {
        readArray(Key.relapses, as: RelapseEvent.self)
            .filter { $0.commitmentID == commitmentID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }
    public func urges(for commitmentID: UUID) async throws -> [UrgeEvent] {
        readArray(Key.urges, as: UrgeEvent.self)
            .filter { $0.commitmentID == commitmentID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }
    public func unlocks(for commitmentID: UUID) async throws -> [UnlockRequest] {
        readArray(Key.unlocks, as: UnlockRequest.self)
            .filter { $0.commitmentID == commitmentID }
            .sorted { $0.requestedAt > $1.requestedAt }
    }
}
