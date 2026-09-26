// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  UserDefaultsCommitmentRepository.swift
//  Pawl — persistence
//
//  A concrete CommitmentRepository backed by UserDefaults + Codable. This is the
//  Phase-1 stepping stone: it persists across launches today, and proves the
//  repository seam (SRS NFR-MAINT-001). It will be replaced/augmented by a CloudKit
//  implementation (FR-PERSIST-001..006) — feature code won't change because both
//  conform to `CommitmentRepository`.
//
//  Switch `suiteName` to the App Group later so extensions share the same store.
//

import Foundation

// Implemented as a @MainActor class (not an `actor`) so its Codable decoding of the
// app's main-actor-isolated model types stays on the main actor — avoids Swift 6
// "main-actor-isolated conformance used in actor-isolated context" warnings. The
// Phase-1 data is tiny (UserDefaults); CloudKit work later is async regardless.
@MainActor
public final class UserDefaultsCommitmentRepository: CommitmentRepository {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let snapshot = "pawl.commitment.snapshot"
        static let relapses = "pawl.log.relapses"
        static let urges = "pawl.log.urges"
        static let unlocks = "pawl.log.unlocks"
    }

    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: Codable helpers

    private func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) { defaults.set(data, forKey: key) }
    }

    private func readArray<T: Decodable>(_ key: String, as type: T.Type) -> [T] {
        read(key, as: [T].self) ?? []
    }

    // MARK: CommitmentRepository

    public func loadActiveCommitment() async throws -> CommitmentSnapshot? {
        guard let snap = read(Key.snapshot, as: CommitmentSnapshot.self),
              snap.commitment.status == .active else { return nil }
        return snap
    }

    public func save(_ snapshot: CommitmentSnapshot) async throws {
        write(snapshot, key: Key.snapshot)
    }

    public func append(relapse: RelapseEvent) async throws {
        var all = readArray(Key.relapses, as: RelapseEvent.self)
        all.append(relapse)
        write(all, key: Key.relapses)
    }

    public func append(urge: UrgeEvent) async throws {
        var all = readArray(Key.urges, as: UrgeEvent.self)
        all.append(urge)
        write(all, key: Key.urges)
    }

    public func append(unlock: UnlockRequest) async throws {
        var all = readArray(Key.unlocks, as: UnlockRequest.self)
        all.append(unlock)
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
