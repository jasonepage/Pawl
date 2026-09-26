// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  KeyStore.swift
//  Pawl — iOS integration layer
//
//  Persists the paired NFC key UID (SRS FR-NFC-002). Like SelectionStore, move the
//  suite to the App Group once that capability exists so extensions can read it.
//

import Foundation

@MainActor
public final class KeyStore {
    private let defaults: UserDefaults
    private let key = "pawl.key.uid"
    // A re-pair in progress: the NEW credential plus when its cooling-off ends. The ACTIVE
    // key (above) is left untouched until the wait elapses, so re-pairing can't grant an
    // instantly-usable key (FR-NFC-004). Persisted so force-quitting can't skip the wait.
    private let pendingKey = "pawl.key.pending.uid"
    private let pendingEndsKey = "pawl.key.pending.endsAt"

    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func save(_ uid: String) { defaults.set(uid, forKey: key) }
    public func load() -> String? { defaults.string(forKey: key) }
    public func clear() { defaults.removeObject(forKey: key) }

    // MARK: - Pending re-pair (gated key change)

    public func savePending(_ uid: String, endsAt: Date) {
        defaults.set(uid, forKey: pendingKey)
        defaults.set(endsAt.timeIntervalSince1970, forKey: pendingEndsKey)
    }

    public func loadPending() -> (uid: String, endsAt: Date)? {
        guard let uid = defaults.string(forKey: pendingKey) else { return nil }
        let ts = defaults.double(forKey: pendingEndsKey)
        guard ts > 0 else { return nil }
        return (uid, Date(timeIntervalSince1970: ts))
    }

    public func clearPending() {
        defaults.removeObject(forKey: pendingKey)
        defaults.removeObject(forKey: pendingEndsKey)
    }
}
